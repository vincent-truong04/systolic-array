"""Power-characterization workloads for gate-level simulation (tb/gls, WAVES=1).

One simulation, four measured workloads, each with a time window written to
$POWER_WINDOWS (JSON, ns of rising clock edges) for `read_vcd -begin_time/-end_time`:

  idle   : out of reset, clock running, in_valid=0, inputs held at 0 (cycles 50..300)
  dense  : back-to-back jobs, K=64, A/B uniform INT8 [-128,127]; window = 4 full job
           periods (first slice of job 2 -> first slice of job 6), so compute + drain
  sparse : same, but each element of A and of B is 0 with p=0.5 (75% of products 0)
  drain  : the drain windows of dense jobs 2..5: edge after in_last .. next job's first
           slice (3N+P cycles each), i.e. array finishing + results shifting out

Jobs are pushed with pushy=True (next slice held at the inputs while in_ready=0), so the
next job starts at the earliest edge (E0+3N+P). Every job is checked against the golden
model, so the power run is also a functional test of the netlist.
"""
import json
import os

import cocotb
import numpy as np
from cocotb.triggers import FallingEdge, ReadOnly, RisingEdge
from cocotb.utils import get_sim_time

from test_top import N, P, SAMPLE_FALL, TopTB, rand_mats, unpack_signed
from golden import ACC_W

K = int(os.environ.get("POWER_K", "64"))
JOBS = int(os.environ.get("POWER_JOBS", "6"))


class PowerTB(TopTB):
    """TopTB that also records the sim time (ns) of every rising edge."""

    def __init__(self, dut):
        super().__init__(dut)
        self.edge_ns = {}

    async def _monitor(self):
        d = self.dut
        while True:
            await RisingEdge(d.clk)
            self.cycle += 1
            self.edge_ns[self.cycle] = get_sim_time("ns")
            if SAMPLE_FALL:
                await FallingEdge(d.clk)
            await ReadOnly()
            rdy = d.in_ready.value
            self.ready_log[self.cycle] = int(rdy) if rdy.is_resolvable else None
            if int(d.rst.value) == 0 and int(d.out_valid.value):
                self.rows.append((self.cycle, int(d.out_row.value),
                                  unpack_signed(d.out_data.value, ACC_W, N)))


def sparse_mats(rng, K, p_zero=0.5):
    A, B = rand_mats(rng, K)
    A[rng.random(A.shape) < p_zero] = 0
    B[rng.random(B.shape) < p_zero] = 0
    return A, B


async def run_phase(tb, rng, make):
    """JOBS back-to-back jobs; returns [(A, B, e0, first_edge)]."""
    jobs = []
    for _ in range(JOBS):
        A, B = make(rng, K)
        n_first = sum(1 for _, f, _ in tb.accepts if f)
        e0 = await tb.send_job(A, B, pushy=True)
        first = [e for e, f, _ in tb.accepts if f][n_first]
        jobs.append((A, B, e0, first))
    return jobs


@cocotb.test()
async def test_power_workloads(dut):
    tb = PowerTB(dut)
    rng = np.random.default_rng(2026)
    await tb.start()
    # idle: inputs already 0 and in_valid 0 from start()
    await tb.wait_edges(300)
    win = {"idle": [tb.edge_ns[50], tb.edge_ns[300]]}

    dense = await run_phase(tb, rng, rand_mats)
    await tb.wait_edges(3 * N + 1 + P)
    sparse = await run_phase(tb, rng, sparse_mats)
    await tb.wait_edges(3 * N + 1 + P)

    for i, (A, B, e0, _) in enumerate(dense + sparse):
        tb.check_job(A, B, e0, f"job{i}")
    assert len(tb.rows) == 2 * JOBS * N, f"{len(tb.rows)} rows, expected {2 * JOBS * N}"

    period = K - 1 + 3 * N + P  # back to back: job j+1's first slice at E0_j + 3N + P
    for name, jobs in (("dense", dense), ("sparse", sparse)):
        firsts = [j[3] for j in jobs]
        assert all(b - a == period for a, b in zip(firsts[1:], firsts[2:])), \
            f"{name}: jobs not back to back: {firsts}"
        win[name] = [tb.edge_ns[firsts[1]], tb.edge_ns[firsts[5]]]
    win["drain"] = [[tb.edge_ns[dense[i][2]], tb.edge_ns[dense[i + 1][3]]] for i in range(1, 5)]
    win["meta"] = {"N": N, "K": K, "PIPE_MAC": P, "period_cycles": period,
                   "macs_per_job": N * N * K, "dense_jobs_in_window": 4}
    out = os.environ.get("POWER_WINDOWS", "power_windows.json")
    with open(out, "w") as f:
        json.dump(win, f, indent=1)
    dut._log.info("windows (ns): %s -> %s", win, out)

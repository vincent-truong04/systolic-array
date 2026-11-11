"""cocotb tests for rtl/systolic_top.sv against model/golden.py:matmul_int8.

Every job is checked for:
  * values: C = matmul_int8(A, B) (exact int64 math + INT32 wrap)
  * order : rows N-1 .. 0 on consecutive cycles (D-014)
  * timing: with E0 = edge accepting in_last and P = PIPE_MAC (D-016),
            out_valid after edges E0+2N+P .. E0+3N-1+P,
            in_ready low after edges E0 .. E0+3N-2+P and high again after E0+3N-1+P
  * no extra output rows ever appear

Driver protocol (AXI-stream style): a slice, once offered (in_valid=1), is held
until accepted. With pushy=True the driver also offers slices while in_ready=0,
which the DUT must not accept.
"""
import os

import cocotb
import numpy as np
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, ReadOnly, RisingEdge

from golden import ACC_W, DATA_W, matmul_int8

N = int(os.environ.get("N", "4"))
P = int(os.environ.get("PIPE_MAC", "1"))   # extra job latency of the 2-stage MAC
DMASK = (1 << DATA_W) - 1


def pack(vals, w):
    return sum((int(v) & ((1 << w) - 1)) << (i * w) for i, v in enumerate(vals))


def unpack_signed(logic_array, w, count):
    x = int(logic_array)
    out = []
    for j in range(count):
        v = (x >> (j * w)) & ((1 << w) - 1)
        out.append(v - (1 << w) if v >> (w - 1) else v)
    return out


class TopTB:
    def __init__(self, dut):
        self.dut = dut
        self.cycle = 0               # number of rising edges seen
        self.rows = []               # (edge, out_row, [values])
        self.ready_log = {}          # edge -> in_ready sampled just after that edge
        self.accepts = []            # (edge, first, last)

    async def start(self):
        d = self.dut
        cocotb.start_soon(Clock(d.clk, 10, unit="ns").start())
        d.rst.value = 1
        d.in_valid.value = 0
        d.in_first.value = 0
        d.in_last.value = 0
        d.a_col.value = 0
        d.b_row.value = 0
        cocotb.start_soon(self._monitor())
        for _ in range(3):
            await FallingEdge(d.clk)
        d.rst.value = 0

    async def _monitor(self):
        d = self.dut
        while True:
            await RisingEdge(d.clk)
            self.cycle += 1
            await ReadOnly()
            self.ready_log[self.cycle] = int(d.in_ready.value)
            if int(d.rst.value) == 0 and int(d.out_valid.value):
                self.rows.append((self.cycle, int(d.out_row.value),
                                  unpack_signed(d.out_data.value, ACC_W, N)))

    async def send_job(self, A, B, rng=None, bubble_p=0.0, pushy=False):
        """Stream one job (A: NxK, B: KxN). Returns the edge that accepted in_last."""
        d = self.dut
        K = A.shape[1]
        k = 0
        last_edge = None
        while k < K:
            await FallingEdge(d.clk)
            ready = int(d.in_ready.value)    # registered: valid for the coming edge
            if rng is not None and rng.random() < bubble_p:
                d.in_valid.value = 0         # idle cycle, random garbage on data
                d.a_col.value = pack(rng.integers(-128, 128, N), DATA_W)
                d.b_row.value = pack(rng.integers(-128, 128, N), DATA_W)
                d.in_first.value = int(rng.integers(0, 2))
                d.in_last.value = int(rng.integers(0, 2))
                continue
            if not ready and not pushy:
                d.in_valid.value = 0
                continue
            d.in_valid.value = 1
            d.in_first.value = int(k == 0)
            d.in_last.value = int(k == K - 1)
            d.a_col.value = pack(A[:, k], DATA_W)
            d.b_row.value = pack(B[k, :], DATA_W)
            if ready:
                edge = self.cycle + 1        # accepted at the coming rising edge
                self.accepts.append((edge, k == 0, k == K - 1))
                if k == K - 1:
                    last_edge = edge
                k += 1
        await FallingEdge(d.clk)
        d.in_valid.value = 0
        return last_edge

    async def wait_edges(self, n):
        target = self.cycle + n
        while self.cycle < target:
            await RisingEdge(self.dut.clk)

    def check_job(self, A, B, e0, tag=""):
        """Check values, row order and exact timing of the job whose last slice hit edge e0."""
        exp = matmul_int8(A, B)
        got = [r for r in self.rows if e0 < r[0] <= e0 + 3 * N + P]
        edges = [r[0] for r in got]
        want = list(range(e0 + 2 * N + P, e0 + 3 * N + P))
        assert edges == want, f"{tag} out_valid edges {edges}, expected {want} (E0={e0})"
        for (edge, row, vals), exp_row in zip(got, range(N - 1, -1, -1)):
            assert row == exp_row, f"{tag} edge {edge}: out_row={row}, expected {exp_row}"
            assert vals == [int(v) for v in exp[row]], \
                f"{tag} row {row}: got {vals}, expected {list(exp[row])}"
        for e in range(e0, e0 + 3 * N - 1 + P):
            assert self.ready_log.get(e) == 0, f"{tag} in_ready should be 0 after edge {e} (E0={e0})"
        assert self.ready_log.get(e0 + 3 * N - 1 + P) == 1, \
            f"{tag} in_ready should return to 1 after edge {e0 + 3 * N - 1 + P}"


def rand_mats(rng, K):
    return rng.integers(-128, 128, (N, K)), rng.integers(-128, 128, (K, N))


async def run_and_check(tb, A, B, tag, **kw):
    e0 = await tb.send_job(A, B, **kw)
    await tb.wait_edges(3 * N + 1 + P)
    tb.check_job(A, B, e0, tag)
    return e0


@cocotb.test()
async def test_identity(dut):
    """A = I (K = N): C must equal B."""
    tb = TopTB(dut)
    rng = np.random.default_rng(1)
    await tb.start()
    B = rng.integers(-128, 128, (N, N))
    await run_and_check(tb, np.eye(N, dtype=np.int64), B, "identity")
    assert (matmul_int8(np.eye(N, dtype=np.int64), B) == B).all()


@cocotb.test()
async def test_k1_outer_product_extremes(dut):
    """K = 1 (first and last on the same slice) with signed extremes."""
    tb = TopTB(dut)
    await tb.start()
    vals = [-128, 127, -1, 0, 1, -127, 126, -128]
    A = np.array([[vals[i % len(vals)]] for i in range(N)])
    B = np.array([[vals[(j + 3) % len(vals)] for j in range(N)]])
    await run_and_check(tb, A, B, "K=1")
    await run_and_check(tb, np.full((N, 1), -128), np.full((1, N), -128), "K=1 -128*-128")


@cocotb.test()
async def test_large_magnitudes(dut):
    """K = 64 all (-128)*(-128) = 64*16384 = 1048576, and mixed (-128)*127."""
    tb = TopTB(dut)
    await tb.start()
    await run_and_check(tb, np.full((N, 64), -128), np.full((64, N), -128), "all -128")
    await run_and_check(tb, np.full((N, 64), -128), np.full((64, N), 127), "-128*127")


@cocotb.test()
async def test_random_jobs(dut):
    """40 random jobs, K in 1..64, random bubbles, pushy valid while not ready."""
    tb = TopTB(dut)
    seed = getattr(cocotb, "RANDOM_SEED", 7)
    rng = np.random.default_rng(seed)
    await tb.start()
    jobs = []
    for n in range(40):
        K = int(rng.integers(1, 65))
        A, B = rand_mats(rng, K)
        e0 = await tb.send_job(A, B, rng=rng, bubble_p=0.2, pushy=bool(n % 2))
        jobs.append((A, B, e0, f"job{n} K={K}"))
    await tb.wait_edges(3 * N + 1 + P)
    for A, B, e0, tag in jobs:
        tb.check_job(A, B, e0, tag)
    assert len(tb.rows) == 40 * N, f"{len(tb.rows)} output rows, expected {40 * N} (extra rows?)"
    dut._log.info("N=%d: 40 random jobs, %d accepted slices, %d edges", N, len(tb.accepts), tb.cycle)


@cocotb.test()
async def test_back_to_back_min_gap(dut):
    """Next job offered immediately: first slice must be accepted exactly at E0+3N+P."""
    tb = TopTB(dut)
    rng = np.random.default_rng(3)
    await tb.start()
    A1, B1 = rand_mats(rng, 5)
    A2, B2 = rand_mats(rng, 3)
    e0 = await tb.send_job(A1, B1, pushy=True)
    e1 = await tb.send_job(A2, B2, pushy=True)
    first_edges = [e for e, first, _ in tb.accepts if first]
    assert first_edges[1] == e0 + 3 * N + P, \
        f"job 2 accepted at {first_edges[1]}, expected {e0 + 3 * N + P}"
    await tb.wait_edges(3 * N + 1 + P)
    tb.check_job(A1, B1, e0, "job1")
    tb.check_job(A2, B2, e1, "job2")


@cocotb.test()
async def test_reset_mid_job(dut):
    """Reset during a job and during a drain: no outputs from aborted jobs; next job correct."""
    tb = TopTB(dut)
    rng = np.random.default_rng(4)
    await tb.start()
    d = dut
    for abort_after in (3, None):      # mid-stream, then mid-drain
        A, B = rand_mats(rng, 10)
        if abort_after is None:
            await tb.send_job(A, B)
            await tb.wait_edges(2 * N + 1 + P)   # now draining
        else:
            for k in range(abort_after):
                await FallingEdge(d.clk)
                d.in_valid.value, d.in_first.value, d.in_last.value = 1, int(k == 0), 0
                d.a_col.value, d.b_row.value = pack(A[:, k], DATA_W), pack(B[k, :], DATA_W)
        await FallingEdge(d.clk)
        d.in_valid.value = 0
        d.rst.value = 1
        await FallingEdge(d.clk)
        d.rst.value = 0
        n_rows_before = len(tb.rows)
        # White-box invariant: reset must flush in-flight valid flags in the skew,
        # so no valid reaches the array until a new slice is accepted. (Not visible
        # at the outputs because D-005's `first` would overwrite the garbage.)
        for _ in range(2 * N):
            await RisingEdge(d.clk)
            await ReadOnly()
            assert int(d.valid_left.value) == 0, \
                f"stale valid reached the array after reset: valid_left={d.valid_left.value}"
        await tb.wait_edges(2 * N)
        assert len(tb.rows) == n_rows_before, "rows appeared after reset from an aborted job"
        assert int(d.in_ready.value) == 1
        A2, B2 = rand_mats(rng, 7)
        await run_and_check(tb, A2, B2, f"after reset ({'stream' if abort_after else 'drain'})")

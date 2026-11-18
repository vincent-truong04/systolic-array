"""cocotb tests for rtl/systolic_sram_top.sv (D-018 weight buffer) against model/golden.py.

B comes from the SRAM. The test keeps a write log and computes, for every accepted slice,
the B row the hardware must have read: row (b_base + k) mod 64 as of the last write accepted
at an edge strictly before the slice's accept edge (D-018 visibility rule).

Checked per job:
  * values: C = matmul_int8(A, B_eff)
  * order : rows N-1 .. 0 on consecutive cycles
  * timing: E0 = edge accepting in_last, D = 2 (SRAM read), P = PIPE_MAC:
            out_valid after edges E0+2N+P+D .. E0+3N-1+P+D;
            in_ready low after edges E0 .. E0+3N-2+P, high after E0+3N-1+P (same as systolic_top)
White-box, every edge:
  * the core never holds a valid slice while its in_ready is 0 (no lost slices)
  * the macro read port is enabled exactly once per accepted slice
"""
import os

import cocotb
import numpy as np
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, ReadOnly, RisingEdge

from golden import ACC_W, DATA_W, matmul_int8

N = int(os.environ.get("N", "8"))
P = int(os.environ.get("PIPE_MAC", "1"))
D = 2          # extra latency of the SRAM read stage
DEPTH = 64


def pack(vals, w):
    return sum((int(v) & ((1 << w) - 1)) << (i * w) for i, v in enumerate(vals))


def unpack_signed(logic_array, w, count):
    x = int(logic_array)
    out = []
    for j in range(count):
        v = (x >> (j * w)) & ((1 << w) - 1)
        out.append(v - (1 << w) if v >> (w - 1) else v)
    return out


class SramTB:
    def __init__(self, dut):
        self.dut = dut
        self.cycle = 0
        self.rows = []         # (edge, out_row, values)
        self.ready_log = {}
        self.accepts = []      # (edge, first, last)
        self.writes = []       # (edge, addr, values)
        self.reads = 0         # edges with csb1 = 0
        self.lost = []         # edges where the core held a slice it could not accept

    async def start(self):
        d = self.dut
        cocotb.start_soon(Clock(d.clk, 10, unit="ns").start())
        d.rst.value = 1
        for s in ("in_valid", "in_first", "in_last", "a_col", "b_base", "wr_en", "wr_addr", "wr_data"):
            getattr(d, s).value = 0
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
            if int(d.rst.value):
                continue
            if int(d.out_valid.value):
                self.rows.append((self.cycle, int(d.out_row.value), unpack_signed(d.out_data.value, ACC_W, N)))
            if int(d.u_core.in_valid.value) and not int(d.u_core.in_ready.value):
                self.lost.append(self.cycle)
            if int(d.u_bbuf.csb1.value) == 0:
                self.reads += 1

    # ---- write port -------------------------------------------------------------------
    async def write_rows(self, rows, rng=None, bubble_p=0.0):
        """rows: list of (addr, values). One write per cycle, optional random idle cycles."""
        d = self.dut
        i = 0
        while i < len(rows):
            await FallingEdge(d.clk)
            if rng is not None and rng.random() < bubble_p:
                d.wr_en.value = 0
                d.wr_addr.value = int(rng.integers(0, DEPTH))
                d.wr_data.value = pack(rng.integers(-128, 128, N), DATA_W)
                continue
            addr, vals = rows[i]
            d.wr_en.value = 1
            d.wr_addr.value = addr
            d.wr_data.value = pack(vals, DATA_W)
            self.writes.append((self.cycle + 1, addr, [int(v) for v in vals]))
            i += 1
        await FallingEdge(d.clk)
        d.wr_en.value = 0

    def row_at(self, addr, edge):
        """B row the hardware reads for a slice accepted at `edge` (last write before it)."""
        hits = [w for w in self.writes if w[1] == addr and w[0] < edge]
        assert hits, f"row {addr} read at edge {edge} before any write"
        assert not [w for w in self.writes if w[1] == addr and w[0] == edge], \
            f"test bug: row {addr} written at the read edge {edge}"
        return max(hits, key=lambda w: w[0])[2]

    # ---- compute stream ---------------------------------------------------------------
    async def send_job(self, A, base, rng=None, bubble_p=0.0, pushy=False):
        """Stream A (NxK) with b_base=base. Returns (E0, B_eff)."""
        d = self.dut
        K = A.shape[1]
        k = 0
        last_edge = None
        b_eff = []
        while k < K:
            await FallingEdge(d.clk)
            ready = int(d.in_ready.value)
            if rng is not None and rng.random() < bubble_p:
                d.in_valid.value = 0
                d.a_col.value = pack(rng.integers(-128, 128, N), DATA_W)
                d.b_base.value = int(rng.integers(0, DEPTH))
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
            # b_base only matters with in_first; drive garbage otherwise
            d.b_base.value = base if k == 0 else (int(rng.integers(0, DEPTH)) if rng is not None else (base + 17) % DEPTH)
            if ready:
                edge = self.cycle + 1
                self.accepts.append((edge, k == 0, k == K - 1))
                b_eff.append((edge, (base + k) % DEPTH))
                if k == K - 1:
                    last_edge = edge
                k += 1
        await FallingEdge(d.clk)
        d.in_valid.value = 0
        return last_edge, b_eff

    async def wait_edges(self, n):
        target = self.cycle + n
        while self.cycle < target:
            await RisingEdge(self.dut.clk)

    def check_job(self, A, b_eff, e0, tag=""):
        B = np.array([self.row_at(addr, edge) for edge, addr in b_eff])
        exp = matmul_int8(A, B)
        lat = 2 * N + P + D
        # Window: the previous job's last row can be as late as E0+D-1 (outputs lag the
        # wrapper's in_ready by D, and the next job may be accepted at E0_prev+3N+P), so
        # start at E0+D, not E0 (the systolic_top window).
        got = [r for r in self.rows if e0 + D <= r[0] <= e0 + 3 * N + P + D]
        edges = [r[0] for r in got]
        want = list(range(e0 + lat, e0 + lat + N))
        assert edges == want, f"{tag} out_valid edges {edges}, expected {want} (E0={e0})"
        for (edge, row, vals), exp_row in zip(got, range(N - 1, -1, -1)):
            assert row == exp_row, f"{tag} edge {edge}: out_row={row}, expected {exp_row}"
            assert vals == [int(v) for v in exp[row]], f"{tag} row {row}: got {vals}, expected {list(exp[row])}"
        for e in range(e0, e0 + 3 * N - 1 + P):
            assert self.ready_log.get(e) == 0, f"{tag} in_ready should be 0 after edge {e} (E0={e0})"
        assert self.ready_log.get(e0 + 3 * N - 1 + P) == 1, f"{tag} in_ready should be 1 after edge {e0 + 3 * N - 1 + P}"

    def check_global(self):
        assert not self.lost, f"core held a slice while not ready at edges {self.lost[:10]}"
        assert self.reads == len(self.accepts), f"{self.reads} SRAM reads for {len(self.accepts)} accepted slices"


def rand_rows(rng, K):
    return rng.integers(-128, 128, (K, N))


async def load(tb, base, B, **kw):
    await tb.write_rows([((base + k) % DEPTH, B[k]) for k in range(B.shape[0])], **kw)


async def run_job(tb, A, base, tag, **kw):
    e0, b_eff = await tb.send_job(A, base, **kw)
    await tb.wait_edges(3 * N + 1 + P + D)
    tb.check_job(A, b_eff, e0, tag)


@cocotb.test()
async def test_identity(dut):
    """A = I, B written at base 0: C must equal B."""
    tb = SramTB(dut)
    rng = np.random.default_rng(1)
    await tb.start()
    B = rand_rows(rng, N)
    await load(tb, 0, B)
    await run_job(tb, np.eye(N, dtype=np.int64), 0, "identity")
    tb.check_global()


@cocotb.test()
async def test_k1_extremes_top_row(dut):
    """K = 1 with signed extremes, at the last address (63) and at 0."""
    tb = SramTB(dut)
    await tb.start()
    vals = [-128, 127, -1, 0, 1, -127, 126, -128]
    A = np.array([[vals[i % len(vals)]] for i in range(N)])
    B = np.array([[vals[(j + 3) % len(vals)] for j in range(N)]])
    await load(tb, 63, B)
    await run_job(tb, A, 63, "K=1 @63")
    await load(tb, 0, np.full((1, N), -128))
    await run_job(tb, np.full((N, 1), -128), 0, "K=1 -128*-128 @0")
    tb.check_global()


@cocotb.test()
async def test_full_buffer_k64(dut):
    """K = 64 uses every row: all (-128)*(-128), then (-128)*127 after rewriting all rows."""
    tb = SramTB(dut)
    await tb.start()
    await load(tb, 0, np.full((64, N), -128))
    await run_job(tb, np.full((N, 64), -128), 0, "K=64 all -128")
    await load(tb, 0, np.full((64, N), 127))
    await run_job(tb, np.full((N, 64), -128), 0, "K=64 -128*127")
    tb.check_global()


@cocotb.test()
async def test_base_wraps(dut):
    """b_base = 58, K = 12: rows 58..63 then 0..5 (address wraps mod 64)."""
    tb = SramTB(dut)
    rng = np.random.default_rng(5)
    await tb.start()
    await load(tb, 0, rand_rows(rng, 64))
    A = rng.integers(-128, 128, (N, 12))
    await run_job(tb, A, 58, "wrap 58+12")
    tb.check_global()


@cocotb.test()
async def test_write_visible_next_edge(dut):
    """A write accepted at edge W is read by a slice accepted at edge W+1 (tightest legal case)."""
    tb = SramTB(dut)
    rng = np.random.default_rng(6)
    await tb.start()
    d = dut
    await load(tb, 10, np.full((1, N), 5))            # old value
    await tb.wait_edges(2)
    newrow = rng.integers(-128, 128, N)
    A = rng.integers(-128, 128, (N, 1))
    # falling edge before W: offer the write; falling edge before W+1: offer the slice
    await FallingEdge(d.clk)
    d.wr_en.value, d.wr_addr.value, d.wr_data.value = 1, 10, pack(newrow, DATA_W)
    tb.writes.append((tb.cycle + 1, 10, [int(v) for v in newrow]))
    await FallingEdge(d.clk)
    d.wr_en.value = 0
    assert int(d.in_ready.value) == 1
    d.in_valid.value, d.in_first.value, d.in_last.value = 1, 1, 1
    d.a_col.value, d.b_base.value = pack(A[:, 0], DATA_W), 10
    e0 = tb.cycle + 1
    tb.accepts.append((e0, True, True))
    assert tb.writes[-1][0] == e0 - 1
    await FallingEdge(d.clk)
    d.in_valid.value = 0
    await tb.wait_edges(3 * N + 1 + P + D)
    tb.check_job(A, [(e0, 10)], e0, "write->read next edge")
    tb.check_global()


@cocotb.test()
async def test_pingpong_random(dut):
    """30 jobs, K 1..32, alternating halves; the next job's B is written into the other half
    while the current job streams (random bubbles on both ports, pushy valid)."""
    tb = SramTB(dut)
    seed = getattr(cocotb, "RANDOM_SEED", 7)
    rng = np.random.default_rng(seed)
    await tb.start()
    jobs = []
    Ks = [int(rng.integers(1, 33)) for _ in range(30)]
    Bs = [rand_rows(rng, K) for K in Ks]
    await load(tb, 0, Bs[0])
    for n, K in enumerate(Ks):
        base = 0 if n % 2 == 0 else 32
        writer = None
        if n + 1 < len(Ks):
            writer = cocotb.start_soon(load(tb, 32 if base == 0 else 0, Bs[n + 1], rng=rng, bubble_p=0.3))
        A = rng.integers(-128, 128, (N, K))
        e0, b_eff = await tb.send_job(A, base, rng=rng, bubble_p=0.2, pushy=bool(n % 2))
        jobs.append((A, b_eff, e0, f"job{n} K={K} base={base}"))
        if writer is not None:
            await writer
    await tb.wait_edges(3 * N + 1 + P + D)
    for A, b_eff, e0, tag in jobs:
        tb.check_job(A, b_eff, e0, tag)
    assert len(tb.rows) == 30 * N, f"{len(tb.rows)} output rows, expected {30 * N}"
    tb.check_global()
    dut._log.info("N=%d: 30 ping-pong jobs, %d slices, %d writes, %d edges",
                  N, len(tb.accepts), len(tb.writes), tb.cycle)


@cocotb.test()
async def test_back_to_back_min_gap(dut):
    """Next job offered immediately: first slice accepted exactly at E0+3N+P (no extra gap)."""
    tb = SramTB(dut)
    rng = np.random.default_rng(3)
    await tb.start()
    await load(tb, 0, rand_rows(rng, 5))
    await load(tb, 40, rand_rows(rng, 3))
    A1, A2 = rng.integers(-128, 128, (N, 5)), rng.integers(-128, 128, (N, 3))
    e0, b1 = await tb.send_job(A1, 0, pushy=True)
    e1, b2 = await tb.send_job(A2, 40, pushy=True)
    first_edges = [e for e, first, _ in tb.accepts if first]
    assert first_edges[1] == e0 + 3 * N + P, f"job 2 accepted at {first_edges[1]}, expected {e0 + 3 * N + P}"
    await tb.wait_edges(3 * N + 1 + P + D)
    tb.check_job(A1, b1, e0, "job1")
    tb.check_job(A2, b2, e1, "job2")
    tb.check_global()


@cocotb.test()
async def test_reset_mid_job(dut):
    """Reset mid-stream and mid-drain: no rows from aborted jobs, buffer contents kept, next job correct."""
    tb = SramTB(dut)
    rng = np.random.default_rng(4)
    await tb.start()
    d = dut
    await load(tb, 0, rand_rows(rng, 20))
    for abort_after in (3, None):
        A = rng.integers(-128, 128, (N, 10))
        if abort_after is None:
            await tb.send_job(A, 0)
            await tb.wait_edges(2 * N + 1 + P + D)
        else:
            for k in range(abort_after):
                await FallingEdge(d.clk)
                d.in_valid.value, d.in_first.value, d.in_last.value = 1, int(k == 0), 0
                d.a_col.value, d.b_base.value = pack(A[:, k], DATA_W), 0
                tb.accepts.append((tb.cycle + 1, k == 0, False))
        await FallingEdge(d.clk)
        d.in_valid.value = 0
        d.rst.value = 1
        await FallingEdge(d.clk)
        d.rst.value = 0
        n_rows = len(tb.rows)
        await tb.wait_edges(3 * N + D)
        assert len(tb.rows) == n_rows, "rows appeared after reset from an aborted job"
        assert int(d.in_ready.value) == 1
        # the SRAM keeps its contents through reset: reuse rows 0..19 without rewriting
        A2 = rng.integers(-128, 128, (N, 7))
        await run_job(tb, A2, 5, f"after reset ({'stream' if abort_after else 'drain'})")
    assert not tb.lost, f"core held a slice while not ready at edges {tb.lost[:10]}"

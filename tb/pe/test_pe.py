"""cocotb unit tests for rtl/pe.sv against the golden model (model/golden.py).

Checking strategy:
  * Every test cycle, all DUT outputs are compared to PEModel (cycle-accurate).
  * At the end of each job, acc_out is also compared to dot_int8(), which is
    independent of PEModel (exact math + wrap), so a bug shared by the RTL and
    PEModel would still be caught.

Timing convention: inputs are driven on the falling edge, sampled by the DUT
on the next rising edge, and outputs are checked in the ReadOnly phase right
after that rising edge.
"""
import itertools

import cocotb
import numpy as np
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, ReadOnly, RisingEdge

from golden import ACC_W, INT8_MAX, INT8_MIN, PEModel, dot_int8, wrap

EDGE_VALUES = [INT8_MIN, INT8_MIN + 1, -1, 0, 1, INT8_MAX - 1, INT8_MAX]


def make_rng():
    seed = getattr(cocotb, "RANDOM_SEED", 12345)
    cocotb.log.info("numpy RNG seed = %d (rerun with RANDOM_SEED=%d to reproduce)", seed, seed)
    return np.random.default_rng(seed)


class PEHarness:
    def __init__(self, dut):
        self.dut = dut
        self.model = PEModel()
        self.cycle = 0

    async def start(self):
        cocotb.start_soon(Clock(self.dut.clk, 10, unit="ns").start())
        await self.tick(rst=1)
        await self.tick(rst=1)

    async def tick(self, a=0, b=0, valid=0, first=0, rst=0, drain=0, acc_in=0, check=True):
        """Apply inputs for one clock cycle, step the model, check outputs."""
        await FallingEdge(self.dut.clk)
        d = self.dut
        d.a_in.value, d.b_in.value = int(a), int(b)
        d.valid_in.value, d.first_in.value, d.rst.value = int(valid), int(first), int(rst)
        d.drain.value, d.acc_in.value = int(drain), int(acc_in)
        self.model.step(a=int(a), b=int(b), valid=int(valid), first=int(first), rst=int(rst),
                        drain=int(drain), acc_in=int(acc_in))
        await RisingEdge(d.clk)
        await ReadOnly()
        self.cycle += 1
        if check:
            self.check()

    def check(self):
        d, m, c = self.dut, self.model, self.cycle
        got = d.acc_out.value.to_signed()
        assert got == m.acc, f"cycle {c}: acc_out={got}, expected {m.acc}"
        assert int(d.valid_out.value) == m.valid_out, f"cycle {c}: valid_out mismatch"
        assert int(d.first_out.value) == m.first_out, f"cycle {c}: first_out mismatch"
        if m.a_out is not None:  # a_out/b_out have no reset: unknown until first edge
            assert d.a_out.value.to_signed() == m.a_out, f"cycle {c}: a_out mismatch"
            assert d.b_out.value.to_signed() == m.b_out, f"cycle {c}: b_out mismatch"

    async def run_job(self, a_vec, b_vec, rng=None, bubble_p=0.0):
        """Feed one dot-product job, optionally with random idle (valid=0) cycles."""
        for k, (a, b) in enumerate(zip(a_vec, b_vec, strict=True)):
            while rng is not None and rng.random() < bubble_p:
                # idle cycle: garbage operands and a random first flag must be ignored
                await self.tick(a=rng.integers(-128, 128), b=rng.integers(-128, 128),
                                valid=0, first=rng.integers(0, 2))
            await self.tick(a=a, b=b, valid=1, first=int(k == 0))
        expected = dot_int8(a_vec, b_vec)
        got = self.dut.acc_out.value.to_signed()
        assert got == expected, f"job result {got}, expected {expected} (independent check)"


@cocotb.test()
async def test_reset(dut):
    """Reset clears acc/valid_out/first_out, including mid-job and when rst & valid & first."""
    h = PEHarness(dut)
    await h.start()
    assert dut.acc_out.value.to_signed() == 0
    await h.tick(a=100, b=100, valid=1, first=1)
    await h.tick(a=100, b=100, valid=1, first=0)
    assert dut.acc_out.value.to_signed() == 20000
    await h.tick(a=55, b=-7, valid=1, first=1, rst=1)   # reset has priority
    assert dut.acc_out.value.to_signed() == 0
    assert int(dut.valid_out.value) == 0 and int(dut.first_out.value) == 0


@cocotb.test()
async def test_signed_edge_products(dut):
    """Every pair of edge values as a 1-term job, including -128 * -128 = +16384."""
    h = PEHarness(dut)
    await h.start()
    for a, b in itertools.product(EDGE_VALUES, repeat=2):
        await h.run_job([a], [b])
    await h.run_job([INT8_MIN], [INT8_MIN])
    assert dut.acc_out.value.to_signed() == 16384


@cocotb.test()
async def test_idle_holds(dut):
    """valid=0 holds acc regardless of operands and first; forwarding continues."""
    h = PEHarness(dut)
    await h.start()
    await h.run_job([3, -4], [7, 9])  # 21 - 36 = -15
    for i in range(10):
        await h.tick(a=127, b=-128, valid=0, first=i % 2)
        assert dut.acc_out.value.to_signed() == -15
    await h.tick(a=2, b=2, valid=1, first=0)  # resume the same job after idling
    assert dut.acc_out.value.to_signed() == -11


@cocotb.test()
async def test_back_to_back_random(dut):
    """200 random jobs, back to back (D-005), with random idle bubbles."""
    h = PEHarness(dut)
    rng = make_rng()
    await h.start()
    for _ in range(200):
        k = int(rng.integers(1, 33))
        a = rng.integers(-128, 128, k)
        b = rng.integers(-128, 128, k)
        await h.run_job(a, b, rng=rng, bubble_p=0.25)
    dut._log.info("200 random jobs passed over %d checked cycles", h.cycle)


@cocotb.test()
async def test_drain(dut):
    """D-013: drain loads acc_in (full 32-bit range), has priority over valid,
    keeps forwarding operands/flags, and a new job starts cleanly afterwards."""
    h = PEHarness(dut)
    rng = make_rng()
    await h.start()
    await h.run_job([10, -20], [3, 4])                       # 30 - 80 = -50
    for v in [-(2**31), 2**31 - 1, 0, -1, int(rng.integers(-(2**31), 2**31))]:
        await h.tick(drain=1, acc_in=v)                      # plain shift
        assert dut.acc_out.value.to_signed() == v
    # drain together with valid & first: drain must win (controller should never do this)
    await h.tick(a=5, b=5, valid=1, first=1, drain=1, acc_in=1234)
    assert dut.acc_out.value.to_signed() == 1234
    await h.tick(a=5, b=5, valid=1, first=0, drain=1, acc_in=-77)
    assert dut.acc_out.value.to_signed() == -77
    await h.run_job([7, 8, -9], [1, 1, 1])                   # first discards drained value
    assert dut.acc_out.value.to_signed() == 6
    # reset beats drain
    await h.tick(drain=1, acc_in=999, rst=1)
    assert dut.acc_out.value.to_signed() == 0


async def overflow_run(dut, a, b, k_total):
    """Accumulate the same product k_total times (fast: no per-cycle Python checks)."""
    h = PEHarness(dut)
    await h.start()
    await FallingEdge(dut.clk)
    dut.rst.value = 0                  # start() leaves rst asserted; tick() would clear it
    dut.drain.value, dut.acc_in.value = 0, 0   # drive every input (BUG-001 lesson)
    dut.a_in.value, dut.b_in.value = a, b
    dut.valid_in.value, dut.first_in.value = 1, 1
    await RisingEdge(dut.clk)          # term 1 (first)
    await FallingEdge(dut.clk)
    dut.first_in.value = 0
    await ClockCycles(dut.clk, k_total - 2, rising=True)  # terms 2 .. k_total-1
    await ReadOnly()
    before = dut.acc_out.value.to_signed()
    await RisingEdge(dut.clk)          # term k_total
    await ReadOnly()
    after = dut.acc_out.value.to_signed()
    return before, after


@cocotb.test()
async def test_overflow_wrap_positive(dut):
    """2^17 terms of (-128)(-128) = 2^31 wraps to -2^31 (D-006)."""
    k = 1 << 17
    before, after = await overflow_run(dut, -128, -128, k)
    assert before == (1 << 31) - 16384, f"before wrap: {before}"
    assert after == -(1 << 31), f"after wrap: {after}"
    assert after == wrap(k * 16384, ACC_W)


@cocotb.test()
async def test_overflow_wrap_negative(dut):
    """(-128)(127) = -16256 repeated until the sum drops below -2^31 and wraps positive."""
    k = (1 << 31) // 16256 + 1          # 132105: first k with k*16256 > 2^31
    before, after = await overflow_run(dut, -128, 127, k)
    assert before == -(k - 1) * 16256, f"before wrap: {before}"
    assert after == wrap(-k * 16256, ACC_W) and after > 0, f"after wrap: {after}"

"""Milestone 0 smoke test: proves cocotb + simulator + NumPy work together."""
import cocotb
import numpy as np
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly, Timer


@cocotb.test()
async def smoke_add(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    dut.rst.value = 1
    dut.a.value = 0
    dut.b.value = 0
    await RisingEdge(dut.clk)
    await ReadOnly()
    assert dut.q.value.to_signed() == 0, "q not cleared by reset"
    await RisingEdge(dut.clk)  # leave ReadOnly phase before driving
    dut.rst.value = 0

    rng = np.random.default_rng(0)
    vectors = [(-128, -128), (127, 127), (-128, 127), (0, -1)]
    vectors += [tuple(int(x) for x in rng.integers(-128, 128, 2)) for _ in range(50)]

    for a, b in vectors:
        dut.a.value = a
        dut.b.value = b
        await RisingEdge(dut.clk)   # q captures a+b on this edge
        await ReadOnly()
        expected = int(np.int16(a) + np.int16(b))
        got = dut.q.value.to_signed()
        assert got == expected, f"{a} + {b}: got {got}, expected {expected}"
        await Timer(1, unit="ns")   # leave ReadOnly phase before driving new inputs

    dut._log.info("smoke test passed: %d vectors", len(vectors))

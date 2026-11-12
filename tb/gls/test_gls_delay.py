"""GLS-only check that SDF delays are really annotated: measure how long after a
rising clock edge the registered output out_valid rises. With zero-delay models
this is 0 ns; with SDF it must be the clock-tree + clk->Q (+ output buffer) delay.
Env: EXPECT_DELAY=1 for SDF runs (require > 0.3 ns), 0 for zero-delay runs."""
import os

import cocotb
import numpy as np
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge
from cocotb.utils import get_sim_time

N = int(os.environ.get("N", "8"))


def pack(vals, w=8):
    return sum((int(v) & ((1 << w) - 1)) << (i * w) for i, v in enumerate(vals))


@cocotb.test()
async def test_clk_to_out_valid(dut):
    """Directly time out_valid's rising edge relative to the preceding clock edge."""
    d = dut
    cocotb.start_soon(Clock(d.clk, 10, unit="ns").start())
    d.rst.value, d.in_valid.value, d.in_first.value, d.in_last.value = 1, 0, 0, 0
    d.a_col.value, d.b_row.value = 0, 0
    for _ in range(3):
        await FallingEdge(d.clk)
    d.rst.value = 0
    await FallingEdge(d.clk)
    d.in_valid.value, d.in_first.value, d.in_last.value = 1, 1, 1
    d.a_col.value, d.b_row.value = pack(np.arange(N)), pack(np.arange(N))
    await FallingEdge(d.clk)
    d.in_valid.value = 0
    edge_t = {"t": None}

    async def track_edges():
        while True:
            await RisingEdge(d.clk)
            edge_t["t"] = get_sim_time("ps")

    cocotb.start_soon(track_edges())
    await RisingEdge(d.out_valid)
    delay_ns = (get_sim_time("ps") - edge_t["t"]) / 1000.0
    dut._log.info("clk edge -> out_valid rise: %.3f ns", delay_ns)
    if os.environ.get("EXPECT_DELAY", "0") == "1":
        assert delay_ns > 0.3, f"out_valid rose {delay_ns:.3f} ns after the edge: SDF not applied?"
    else:
        assert delay_ns < 0.001, f"zero-delay run but out_valid rose {delay_ns:.3f} ns after the edge"

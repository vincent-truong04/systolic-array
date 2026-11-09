"""cocotb tests for rtl/skew.sv. Parameters come from env (set by the Makefile).

What "lane i is delayed by i cycles" means here: the value a downstream
register would capture from dout lane i at clock edge t equals the value driven
on din lane i before edge t-i. We sample dout just before each rising edge.
"""
import os

import cocotb
import numpy as np
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer

LANES = int(os.environ["LANES"])
W = int(os.environ["W"])
HAS_RESET = int(os.environ["HAS_RESET"])
MASK = (1 << W) - 1


def pack(lanes):
    return sum((v & MASK) << (i * W) for i, v in enumerate(lanes))


def unpack(logic_array):
    """Per-lane ints; None for a lane containing X/Z (4-state sims like Icarus)."""
    bits = str(logic_array)            # MSB first
    n = len(bits)
    lanes = []
    for i in range(LANES):
        s = bits[n - (i + 1) * W : n - i * W]
        lanes.append(int(s, 2) if set(s) <= {"0", "1"} else None)
    return lanes


@cocotb.test()
async def test_skew_delays(dut):
    seed = getattr(cocotb, "RANDOM_SEED", 1)
    rng = np.random.default_rng(seed)
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    # Sample at cycle t happens just before edge t.  Lane i then shows the value
    # captured at edge t-i -- unless HAS_RESET and rst was high at any edge in
    # [t-i, t-1], which flushes the whole delay line (in-flight values too).
    xs, rsts = [], []
    n_cycles = 60
    checked = 0
    for t in range(n_cycles):
        rst = 1 if (t < 3 or t == 30) else 0   # initial reset + one mid-stream reset
        x = [int(v) for v in rng.integers(0, 1 << W, LANES)]
        await FallingEdge(dut.clk)
        dut.rst.value = rst
        dut.din.value = pack(x)
        await Timer(1, unit="ns")       # let lane 0 (a wire) settle
        out = unpack(dut.dout.value)

        assert out[0] == x[0], f"t={t} lane 0 should be a wire: {out[0]} != {x[0]}"
        for i in range(1, LANES):
            src = t - i
            if HAS_RESET and any(rsts[max(src, 0):t]):
                exp = 0                 # flushed by reset
            elif src < 0:
                continue                # before the first edge, no reset: unknown (X in Icarus)
            else:
                exp = xs[src][i]
            assert out[i] == exp, f"t={t} lane {i}: got {out[i]}, expected {exp}"
            checked += 1
        xs.append(x)
        rsts.append(rst)
        await RisingEdge(dut.clk)
    assert checked > 0 or LANES == 1   # guard against a test that silently checks nothing

    dut._log.info("skew LANES=%d W=%d HAS_RESET=%d: %d cycles, %d delayed-lane checks",
                  LANES, W, HAS_RESET, n_cycles, checked)

"""Golden reference model for the systolic-array accelerator.

Kept independent of the RTL: it computes results with exact integer math
(int64 / Python ints) and then applies the agreed number format:
  - operands: signed INT8   [-128, 127]
  - results : signed INT32, two's-complement wrap on overflow (D-006)
"""
from __future__ import annotations

import numpy as np

DATA_W = 8
ACC_W = 32
INT8_MIN, INT8_MAX = -(1 << (DATA_W - 1)), (1 << (DATA_W - 1)) - 1


def wrap(x, bits: int = ACC_W):
    """Wrap an integer (or int64 array) to a signed `bits`-bit two's-complement value."""
    mask = (1 << bits) - 1
    sign = 1 << (bits - 1)
    if isinstance(x, np.ndarray):
        x = x.astype(np.int64)
        return ((x & mask) ^ sign) - sign
    return ((int(x) & mask) ^ sign) - sign


def check_int8(x) -> None:
    arr = np.asarray(x)
    if arr.size and (arr.min() < INT8_MIN or arr.max() > INT8_MAX):
        raise ValueError(f"operand out of INT8 range: [{arr.min()}, {arr.max()}]")


def dot_int8(a, b) -> int:
    """INT8 dot product with INT32 wrap. Exact: summed as Python ints, wrapped once.

    Wrapping once at the end equals wrapping after every add, because addition
    mod 2^32 is associative. (That's why wrap needs no ordering, unlike saturation.)
    """
    check_int8(a)
    check_int8(b)
    return wrap(sum(int(x) * int(y) for x, y in zip(a, b, strict=True)))


def matmul_int8(A, B) -> np.ndarray:
    """C = A @ B for INT8 matrices, INT32 wrapped result. A: MxK, B: KxN."""
    A = np.asarray(A)
    B = np.asarray(B)
    check_int8(A)
    check_int8(B)
    # int64 is exact here: |sum| <= K * 2^14, which fits easily for any practical K.
    return wrap(A.astype(np.int64) @ B.astype(np.int64))


class PEModel:
    """Cycle-level model of one PE, used to check the RTL every clock cycle.

    Mirrors the agreed spec (D-005..D-009), not the RTL source. `None` means
    "unknown" for registers without reset (a_out/b_out before the first edge).
    """

    def __init__(self) -> None:
        self.acc = 0
        self.valid_out = 0
        self.first_out = 0
        self.a_out: int | None = None
        self.b_out: int | None = None

    def step(self, *, a: int, b: int, valid: int, first: int, rst: int = 0,
             drain: int = 0, acc_in: int = 0) -> None:
        """Advance one rising clock edge with these inputs applied."""
        check_int8([a, b])
        if rst:
            self.acc, self.valid_out, self.first_out = 0, 0, 0
        else:
            if drain:                       # D-013: drain has priority over valid
                self.acc = wrap(acc_in)
            elif valid:
                base = 0 if first else self.acc
                self.acc = wrap(base + a * b)
            self.valid_out, self.first_out = int(valid), int(first)
        self.a_out, self.b_out = a, b  # data regs have no reset

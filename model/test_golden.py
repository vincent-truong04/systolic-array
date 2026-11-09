"""Self-checks for the golden model (run: pytest model/)."""
import numpy as np

from golden import PEModel, dot_int8, matmul_int8, wrap


def test_wrap_boundaries():
    assert wrap(2**31 - 1) == 2**31 - 1
    assert wrap(2**31) == -(2**31)
    assert wrap(-(2**31) - 1) == 2**31 - 1
    assert (wrap(np.array([2**31, -(2**31) - 1])) == [-(2**31), 2**31 - 1]).all()


def test_dot_edge_cases():
    assert dot_int8([-128], [-128]) == 16384          # largest product, only positive extreme
    assert dot_int8([-128], [127]) == -16256          # most negative product
    assert dot_int8([-128] * 131072, [-128] * 131072) == -(2**31)  # 2^17 * 2^14 wraps


def test_matmul_matches_exact_math():
    rng = np.random.default_rng(1)
    A = rng.integers(-128, 128, (4, 7))
    B = rng.integers(-128, 128, (7, 5))
    exact = [[sum(int(A[i, k]) * int(B[k, j]) for k in range(7)) for j in range(5)] for i in range(4)]
    assert (matmul_int8(A, B) == np.array(exact)).all()


def test_pe_model_first_valid():
    m = PEModel()
    m.step(a=3, b=4, valid=1, first=1)
    m.step(a=5, b=6, valid=1, first=0)
    m.step(a=99, b=99, valid=0, first=1)   # not valid: hold, first ignored
    assert m.acc == 42
    m.step(a=-128, b=-128, valid=1, first=1)
    assert m.acc == 16384

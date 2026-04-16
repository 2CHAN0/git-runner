import pytest
from app.calculator import add, subtract, multiply, divide, power, modulo


class TestAdd:
    def test_positive_numbers(self):
        assert add(2, 3) == 5

    def test_negative_numbers(self):
        assert add(-1, -1) == -2

    def test_mixed(self):
        assert add(-1, 1) == 0


class TestSubtract:
    def test_basic(self):
        assert subtract(5, 3) == 2

    def test_negative_result(self):
        assert subtract(3, 5) == -2


class TestMultiply:
    def test_basic(self):
        assert multiply(3, 4) == 12

    def test_by_zero(self):
        assert multiply(5, 0) == 0


class TestDivide:
    def test_basic(self):
        assert divide(10, 2) == 5.0

    def test_float_result(self):
        assert divide(7, 2) == 3.5

    def test_divide_by_zero(self):
        with pytest.raises(ValueError, match="Cannot divide by zero"):
            divide(1, 0)


class TestPower:
    def test_basic(self):
        assert power(2, 3) == 8

    def test_zero_exponent(self):
        assert power(5, 0) == 1

    def test_negative_exponent(self):
        assert power(2, -1) == 0.5


class TestModulo:
    def test_basic(self):
        assert modulo(10, 3) == 1

    def test_even_division(self):
        assert modulo(10, 5) == 0

    def test_modulo_by_zero(self):
        with pytest.raises(ValueError, match="Cannot modulo by zero"):
            modulo(10, 0)

"""Factorization. Fermat's, Pollard's methods"""

import mopsa

def factorize(n):
    factors = {}
    d = 2
    while n > 1:
        power = 0
        while n % d == 0:
            power += 1
            n //= d
        if power > 0:
            factors[d] = power
        d += 1
        if d * d > n:
            d = n
    return factors


def get_all_divisors(n):
    divisors = []
    d = 1
    while d * d <= n:
        if n % d == 0:
            divisors.append(d)
            if d * d != n:
                divisors.append(n // d)
        d += 1
    return sorted(divisors)


def test_types():
    a = get_all_divisors(2)

    mopsa.ignore_exception(ZeroDivisionError)
    mopsa.assert_safe()
    mopsa.assert_list_of(a, int)


# a := List[int]
# factorize := Callable[[int], Dict[int, int]]
# get_all_divisors := Callable[[int], List[int]]

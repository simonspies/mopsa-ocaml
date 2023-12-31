import mopsa

def test_types():
    T = 4

    for x in [1, 2, 3, 4]:

        n = 9
        N = [0.186, 0.389, 0.907, 0.832, 0.959, 0.557, 0.300, 0.992, 0.899]
        K = [0.916, 0.728, 0.271, 0.520, 0.700, 0.521, 0.215, 0.341, 0.458]

        y = 0  # deceitful war
        z = 0  # war

        i = 0
        j = 0
        while i < n:
            if N[i] > K[j]:
                y = y + 1
                j = j + 1
            i = i + 1

        i = 0
        j = 0
        while j < n:
            if K[j] > N[i]:
                z = z + 1
                i = i + 1
            j = j + 1

    mopsa.massert(isinstance(T, int))
    mopsa.massert(isinstance(x, int))
    mopsa.massert(isinstance(n, int))
    mopsa.massert(isinstance(y, int))
    mopsa.massert(isinstance(z, int))
    mopsa.massert(isinstance(i, int))
    mopsa.massert(isinstance(j, int))
    mopsa.massert(isinstance(K, list))
    mopsa.massert(isinstance(N, list))
    mopsa.massert(isinstance(K[0], float))
    mopsa.massert(isinstance(N[0], float))
    mopsa.ignore_exception(IndexError)
    mopsa.ignore_exception(UnboundLocalError)

# T := int
# x := int
# n := int
# K := List[float]
# N := List[float]
# y := int
# z := int
# i := int
# j := int

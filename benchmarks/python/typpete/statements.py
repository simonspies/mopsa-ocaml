import mopsa

def test_types():
    i = 0
    j = 0
    for x in [1, 2, 3]:
        L1 = [5, 6, 7, 8]
        L2 = [9, 10, 7, 12]
        for i in [0, 1, 2, 3]:
            for j in [0, 1, 2, 3]:
                if L1[i] == L2[j]:
                    n = L1[i]


    mopsa.ignore_exception(IndexError)
    mopsa.assert_safe()
    mopsa.massert(isinstance(i, int))
    mopsa.massert(isinstance(j, int))

    mopsa.massert(isinstance(L1, list))
    mopsa.massert(isinstance(L2, list))

    mopsa.massert(isinstance(L1[0], int))
    mopsa.massert(isinstance(L2[0], int))
    mopsa.ignore_exception(IndexError)
    mopsa.ignore_exception(UnboundLocalError)

# L1 := List[int]
# L2 := List[int]
# i := int
# j := int

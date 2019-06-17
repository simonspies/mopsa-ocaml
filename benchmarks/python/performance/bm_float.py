"""
Artificial, floating point-heavy benchmark originally used by Factor.
"""
# from six.moves import xrange
# import perf

from math import sin, cos, sqrt


POINTS = 100000


class Point(object):
    __slots__ = ('x', 'y', 'z')

    def __init__(self, i):
        self.x = x = sin(i)
        self.y = cos(i) * 3
        self.z = (x * x) / 2

    def __repr__(self):
        return "<Point: x=%s, y=%s, z=%s>" % (self.x, self.y, self.z)

    def normalize(self):
        x = self.x
        y = self.y
        z = self.z
        norm = sqrt(x * x + y * y + z * z)
        self.x /= norm
        self.y /= norm
        self.z /= norm

    def maximize(self, other):
        self.x = self.x if self.x > other.x else other.x
        self.y = self.y if self.y > other.y else other.y
        self.z = self.z if self.z > other.z else other.z
        return self


def maximize(points):
    next = points[0]
    for p in points[1:]:
        next = next.maximize(p)
    return next


def benchmark(n):
    # points = None
    points = [Point(0)] * n
    for i in range(n):
       points[i] = Point(i)
    # points = [Point(i) for i in range(n)]
    for p in points:
        p.normalize()
    return maximize(points)

def test_main():
    import mopsa

    points = POINTS
    benchmark(points)
    mopsa.ignore_exception(IndexError)
    mopsa.assert_safe()

# if __name__ == "__main__":
#     # runner = perf.Runner()
#     # runner.metadata['description'] = "Float benchmark"

#     points = POINTS
#     # runner.bench_func('float', benchmark, points)
#     benchmark(points)

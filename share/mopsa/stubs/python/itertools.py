class repeat:
    def __init__(self, val, count=None):
        self.val = val
        self.count = count
        self.pos = 0

    def __iter__(self):
        return self

    def __next__(self):
        if self.count == None or self.pos < self.count:
            self.pos += 1
            return self.val
        raise StopIteration
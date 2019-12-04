from typing import overload, AnyStr, Union, Generic, Pattern, Text

_PathType = Union[bytes, Text, _PathLike]

class _PathLike(Generic[AnyStr]):
    def __fspath__(self) -> AnyStr: ...

# FIXME
# @overload
# def expanduser(path: _PathLike[AnyStr]) -> AnyStr: ...
# @overload
def expanduser(path: AnyStr) -> AnyStr: ...

def isfile(path: _PathType) -> bool: ...

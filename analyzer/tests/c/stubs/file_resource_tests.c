#include <fcntl.h>

extern int _mopsa_fd_to_int(void *fd);
extern void *_mopsa_int_to_fd(int fd);


/*$
 * local: void* fd = new FileDescriptor;
 * local: int n = _mopsa_fd_to_int(fd);
 * ensures: return == n;
 */
int open_ (const char *file, int oflag, ...);

/*$
 * local: void* fd = _mopsa_int_to_fd(f);
 * requires: fd in FileDescriptor;
 * free : fd;
 */
void close_(int f);


/* Test that open returns a positive number */
void test_open_retuns_positive() {
  int fd = open_("/tmp/a.txt", O_RDONLY);
  _mopsa_assert(fd >= 0);
  _mopsa_assert_safe();
}

/* Test that open returns increasing numbers */
/* void test_open_retuns_increasing_ids() { */
/*   int fd1 = open_("/tmp/a.txt", O_RDONLY); */
/*   int fd2 = open_("/tmp/b.txt", O_RDONLY); */
/*   _mopsa_assert(fd2 > fd1); */
/* } */


/* Test closing a file after opening it */
void test_close_after_open() {
  int fd = open_("/tmp/a.txt", O_RDONLY);
  close_(fd);
  _mopsa_assert_safe();
  int fdd = open_("/tmp/a.txt", O_RDONLY);
  _mopsa_assert(fd == fdd);
}

/* Test closing a file not already opened */
void test_close_without_open() {
  int fd = 20;
  close_(fd);
  _mopsa_assert_unsafe();
}

/* Test closing a file already closes */
void test_close_after_close() {
  int fd = open_("/tmp/a.txt", O_RDONLY);
  close_(fd);
  _mopsa_assert_safe();
  close_(fd);
  _mopsa_assert_unsafe();
}

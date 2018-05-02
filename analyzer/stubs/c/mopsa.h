#ifndef _MOPSA_H
#define _MOPSA_H

// Abstract values
extern long int _mopsa_rand_int(long int, long int);

extern char _mopsa_range_char();
extern unsigned char _mopsa_range_unsigned_char();
extern int _mopsa_range_int();
extern unsigned int _mopsa_range_unsigned_int();
extern short _mopsa_range_short();
extern unsigned short _mopsa_range_unsigned_short();
extern long _mopsa_range_long();
extern unsigned long _mopsa_range_unsigned_long();


// Raise Framework.Manager.Panic exception with a given message
extern void _mopsa_panic(const char*);

// Errors
#define OUT_OF_BOUND 1
#define NULL_DEREF 2
#define INVALID_DEREF 3
#define INTEGER_OVERFLOW 4
#define DIVISION_BY_ZERO 5

// Assertions
extern void _mopsa_assert_true(int cond);
extern void _mopsa_assert_exists(int cond);
extern void _mopsa_assert_false(int cond);
extern void _mopsa_assert_unreachable();
extern void _mopsa_assert_safe();
extern void _mopsa_assert_unsafe();
extern void _mopsa_assert_error(int error);
extern void _mopsa_assert_error_at_line(int error, int line);



#endif //_MOPSA_H

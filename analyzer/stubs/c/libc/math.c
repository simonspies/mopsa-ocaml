/****************************************************************************/
/*                   Copyright (C) 2018 The MOPSA Project                   */
/*                                                                          */
/*   This program is free software: you can redistribute it and/or modify   */
/*   it under the terms of the CeCILL license V2.1.                         */
/*                                                                          */
/****************************************************************************/


/*
  libc stub
  based on header from glibc-2.27-r6
*/
#include <math.h>
#include <limits.h>
#include "mopsa_libc_utils.h"


/* overapproximation of π, used in ensures */
static const double _pi = 4.;

/* overapproximation of π/2, used in ensures */
static const double _pi_2 = 2.;


/*$
 * requires: float_valid(__x) and __x >= -1. and __x <= 1.;
 * ensures:  float_valid(return) and return >= 0. and return <= _pi;
 */
double acos(double __x);

/*$
 * requires: float_valid(__x) and __x >= -1. and __x <= 1.;
 * ensures:  float_valid(return) and return >= 0. and return <= _pi;
 */
float acosf(float __x);

/*$
 * requires: float_valid(__x) and __x >= -1. and __x <= 1.;
 * ensures:  float_valid(return) and return >= 0. and return <= _pi;
 */
long double acosl(long double __x);


/*$
 * requires: float_valid(__x) and __x >= -1. and __x <= 1.;
 * ensures:  float_valid(return) and return >= -_pi_2 and return <= _pi_2;
 */
double asin(double __x);

/*$
 * requires: float_valid(__x) and __x >= -1. and __x <= 1.;
 * ensures:  float_valid(return) and return >= -_pi_2 and return <= _pi_2;
 */
float asinf(float __x);

/*$
 * requires: float_valid(__x) and __x >= -1. and __x <= 1.;
 * ensures:  float_valid(return) and return >= -_pi_2 and return <= _pi_2;
 */
long double asinl(long double __x);


/*$
 * requires: __x == __x; // means that __x is not a NaN
 * ensures:  float_valid(return) and return >= -_pi_2 and return <= _pi_2;
 */
double atan(double __x);

/*$
 * requires: __x == __x; // means that __x is not a NaN
 * ensures:  float_valid(return) and return >= -_pi_2 and return <= _pi_2;
 */
float atanf(float __x);

/*$
 * requires: __x == __x; // means that __x is not a NaN
 * ensures:  float_valid(return) and return >= -_pi_2 and return <= _pi_2;
 */
long double atanl(long double __x);


/*$
 * requires: float_valid(__x) and float_valid(__y);
 * ensures:  float_valid(return) and return >= -_pi and return <= _pi;
 */
double atan2(double __y, double __x);

/*$
 * requires: float_valid(__x) and float_valid(__y);
 * ensures:  float_valid(return) and return >= -_pi and return <= _pi;
 */
float atan2f(float __y, float __x);

/*$
 * requires: float_valid(__x) and float_valid(__y);
 * ensures:  float_valid(return) and return >= -_pi and return <= _pi;
 */
long double atan2l(long double __y, long double __x);


/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) and return >= -1. and return <= 1.;
 */
double cos(double __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) and return >= -1. and return <= 1.;
 */
float cosf(float __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) and return >= -1. and return <= 1.;
 */
long double cosl(long double __x);


/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) and return >= -1. and return <= 1.;
 */
double sin(double __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) and return >= -1. and return <= 1.;
 */
float sinf(float __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) and return >= -1. and return <= 1.;
 */
long double sinl(long double __x);


/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) or float_inf(return);
 */
double tan(double __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) or float_inf(return);
 */
float tanf(float __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) or float_inf(return);
 */
long double tanl(long double __x);


/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) and return >= 1.;
 */
double cosh(double __x);

/*$
 * requires: float_valid(__x);
 * ensures:  (float_valid(return) or float_inf(return)) and return >= 1.;
 */
float coshf(float __x);

/*$
 * requires: float_valid(__x);
 * ensures:  (float_valid(return) or float_inf(return)) and return >= 1.;
 */
long double coshl(long double __x);


/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) or float_inf(return);
 */
double sinh(double __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) or float_inf(return);
 */
float sinhf(float __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) or float_inf(return);
 */
long double sinhl(long double __x);


/*$
 * requires: __x == __x; // means that __x is not a NaN
 * ensures:  float_valid(return) and return >= -1. and return <= 1.;
 */
double tanh(double __x);

/*$
 * requires: __x == __x; // means that __x is not a NaN
 * ensures:  float_valid(return) and return >= -1. and return <= 1.;
 */
float tanhf(float __x);

/*$
 * requires: __x == __x; // means that __x is not a NaN
 * ensures:  float_valid(return) and return >= -1. and return <= 1.;
 */
long double tanhl(long double __x);


#ifdef __USE_GNU

/*$
 * requires: float_valid(__x);
 * assigns:  *__sinx;
 * assigns:  *__cosx;
 * ensures:  *__sinx >= -1. and *__sinx <= 1.;
 * ensures:  *__cosx >= -1. and *__cosx <= 1.;
 */
void sincos(double __x, double* __sinx, double* __cosx);

/*$
 * requires: float_valid(__x);
 * assigns:  *__sinx;
 * assigns:  *__cosx;
 * ensures:  *__sinx >= -1. and *__sinx <= 1.;
 * ensures:  *__cosx >= -1. and *__cosx <= 1.;
 */
void sincosf(float __x, float* __sinx, float* __cosx);

/*$
 * requires: float_valid(__x);
 * assigns:  *__sinx;
 * assigns:  *__cosx;
 * ensures:  *__sinx >= -1. and *__sinx <= 1.;
 * ensures:  *__cosx >= -1. and *__cosx <= 1.;
 */
void sincosl(long double __x, long double* __sinx, long double* __cosx);

#endif


#if defined __USE_XOPEN_EXTENDED || defined __USE_ISOC99

/*$
 * requires: float_valid(__x) and __x >= 1.;
 * ensures:  (float_valid(return) or float_inf(return)) and return >= 0.;
 */
double acosh(double __x);

/*$
 * requires: float_valid(__x) and __x >= 1.;
 * ensures:  (float_valid(return) or float_inf(return)) and return >= 0.;
 */
float acoshf(float __x);

/*$
 * requires: float_valid(__x) and __x >= 1.;
 * ensures:  (float_valid(return) or float_inf(return)) and return >= 0.;
 */
long double acoshl(long double __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) or float_inf(return);
 */
double asinh(double __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) or float_inf(return);
 */
float asinhf(float __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) or float_inf(return);
 */
long double asinhl(long double __x);


/*$
 * requires: float_valid(__x) and __x > -1. and __x < 1.;
 * ensures:  float_valid(return) or float_inf(return);
 */
double atanh(double __x);

/*$
 * requires: float_valid(__x) and __x > -1. and __x < 1.;
 * ensures:  float_valid(return) or float_inf(return);
 */
float atanhf(float __x);

/*$
 * requires: float_valid(__x) and __x > -1. and __x < 1.;
 * ensures:  float_valid(return) or float_inf(return);
 */
long double atanhl(long double __x);


#endif


/*$
 * requires: float_valid(__x);
 * ensures:  (float_valid(return) or float_inf(return)) and return >= 0.;
 */
double exp(double __x);

/*$
 * requires: float_valid(__x);
 * ensures:  (float_valid(return) or float_inf(return)) and return >= 0.;
 */
float expf(float __x);

/*$
 * requires: float_valid(__x);
 * ensures:  (float_valid(return) or float_inf(return)) and return >= 0.;
 */
long double expl(long double __x);


/*$
 * requires: float_valid(__x);
 * assigns:  *__exponent;
 * ensures:  (__x == 0 implies return == 0.) and
 *           (__x > 0 implies return >= 0.5 and return <= 1.) and
 *           (__x < 0 implies return >= -1. and return <= -0.5);
 * ensures:  *__exponent >= -1073 && *__exponent <= 1024;
 */
double frexp(double __x, int* __exponent);

/*$
 * requires: float_valid(__x);
 * assigns:  *__exponent;
 * ensures:  (__x == 0 implies return == 0.) and
 *           (__x > 0 implies return >= 0.5 and return <= 1.) and
 *           (__x < 0 implies return >= -1. and return <= -0.5);
 * ensures:  *__exponent >= -148 && *__exponent <= 128;
 */
float frexpf(float __x, int* __exponent);

/*$
 * // exponent range based on 128-bit IEEE quadruple precision
 * // also sound wrt. 80-bit and 96-bit precision
 *
 * requires: float_valid(__x);
 * assigns:  *__exponent;
 * ensures:  (__x == 0 implies return == 0.) and
 *           (__x > 0 implies return >= 0.5 and return <= 1.) and
 *           (__x < 0 implies return >= -1. and return <= -0.5);
 * ensures:  *__exponent >= -16492 && *__exponent <= 16384;
 */
long double frexpl(long double __x, int* __exponent);


/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) or float_inf(return);
 */
double ldexp(double __x, int __exponent);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) or float_inf(return);
 */
float ldexpf(float __x, int __exponent);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) or float_inf(return);
 */
long double ldexpl(long double __x, int __exponent);


/*$
 * requires: float_valid(__x) and __x > 0.;
 * ensures:  float_valid(return) or float_inf(return);
 */
double log(double __x);

/*$
 * requires: float_valid(__x) and __x > 0.;
 * ensures:  float_valid(return) or float_inf(return);
 */
float logf(float __x);

/*$
 * requires: float_valid(__x) and __x > 0.;
 * ensures:  float_valid(return) or float_inf(return);
 */
long double logl(long double __x);


/*$
 * requires: float_valid(__x) and __x > 0.;
 * ensures:  float_valid(return) or float_inf(return);
 */
double log10(double __x);

/*$
 * requires: float_valid(__x) and __x > 0.;
 * ensures:  float_valid(return) or float_inf(return);
 */
float log10f(float __x);

/*$
 * requires: float_valid(__x) and __x > 0.;
 * ensures:  float_valid(return) or float_inf(return);
 */
long double log10l(long double __x);


/*$
 * requires: float_valid(__x);
 * assigns:  *__iptr;
 * ensures:  float_valid(return) and float_valid(*__iptr);
 * ensures:  (__x >= 0 implies 
 *              return >= 0. and return < 1. and
 *              0 <= *__iptr and *__iptr <= __x and __x < *__iptr + 1.);
 * ensures:  (__x <= 0 implies 
 *              return <= 0. and return > -1. and
 *              *__iptr - 1. < __x and __x <= *__iptr and *__iptr <= 0.);
 * // due to rounding errors, do not assume that __x == return + *__iptr
 */
double modf(double __x, double* __iptr);

/*$
 * requires: float_valid(__x);
 * assigns:  *__iptr;
 * ensures:  float_valid(return) and float_valid(*__iptr);
 * ensures:  (__x >= 0 implies 
 *              return >= 0. and return < 1. and
 *              0 <= *__iptr and *__iptr <= __x and __x < *__iptr + 1.);
 * ensures:  (__x <= 0 implies 
 *              return <= 0. and return > -1. and
 *              *__iptr - 1. < __x and __x <= *__iptr and *__iptr <= 0.);
 * // due to rounding errors, do not assume that __x == return + *__iptr
 */
float modff(float __x, float* __iptr);

/*$
 * requires: float_valid(__x);
 * assigns:  *__iptr;
 * ensures:  float_valid(return) and float_valid(*__iptr);
 * ensures:  (__x >= 0 implies 
 *              return >= 0. and return < 1. and
 *              0 <= *__iptr and *__iptr <= __x and __x < *__iptr + 1.);
 * ensures:  (__x <= 0 implies 
 *              return <= 0. and return > -1. and
 *              *__iptr - 1. < __x and __x <= *__iptr and *__iptr <= 0.);
 * // due to rounding errors, do not assume that __x == return + *__iptr
 */
long double modfl(long double __x, long double* __iptr);


#if __GLIBC_USE (IEC_60559_FUNCS_EXT)

/*$
 * requires: float_valid(__x);
 * ensures:  (float_valid(return) or float_inf(return)) and return >= 0.;
 */
double exp10(double __x);

/*$
 * requires: float_valid(__x);
 * ensures:  (float_valid(return) or float_inf(return)) and return >= 0.;
 */
float exp10f(float __x);

/*$
 * requires: float_valid(__x);
 * ensures:  (float_valid(return) or float_inf(return)) and return >= 0.;
 */
long double exp10l(long double __x);

#endif


#if defined __USE_XOPEN_EXTENDED || defined __USE_ISOC99

/*$
 * requires: float_valid(__x);
 * ensures:  (float_valid(return) or float_inf(return)) and return >= -1.;
 */
double expm1(double __x);

/*$
 * requires: float_valid(__x);
 * ensures:  (float_valid(return) or float_inf(return)) and return >= -1.;
 */
float expm1f(float __x);

/*$
 * requires: float_valid(__x);
 * ensures:  (float_valid(return) or float_inf(return)) and return >= -1.;
 */
long double expm1l(long double __x);


/*$
 * requires: float_valid(__x) and __x > -1.;
 * ensures:  (float_valid(return) or float_inf(return));
 */
double log1p(double __x);

/*$
 * requires: float_valid(__x) and __x > -1.;
 * ensures:  (float_valid(return) or float_inf(return));
 */
float log1pf(float __x);

/*$
 * requires: float_valid(__x) and __x > -1.;
 * ensures:  (float_valid(return) or float_inf(return));
 */
long double log1pl(long double __x);


/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return);
 * ensures:  return >= -1074. and return <= 1023.;
 */
double logb(double __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return);
 * ensures:  return >= -149. and return <= 127.;
 */
float logbf(float __x);

/*$
 * // exponent range based on 128-bit IEEE quadruple precision
 * requires: float_valid(__x);
 * ensures:  float_valid(return);
 * ensures:  return >= -16493. and return <= 16383.;
 */
long double logbl(long double __x);

#endif



#ifdef __USE_ISOC99

/*$
 * requires: float_valid(__x);
 * ensures:  (float_valid(return) or float_inf(return)) and return >= 0.;
 */
double exp2(double __x);

/*$
 * requires: float_valid(__x);
 * ensures:  (float_valid(return) or float_inf(return)) and return >= 0.;
 */
float exp2f(float __x);

/*$
 * requires: float_valid(__x);
 * ensures:  (float_valid(return) or float_inf(return)) and return >= 0.;
 */
long double exp2l(long double __x);


/*$
 * requires: float_valid(__x) and __x > 0.;
 * ensures:  (float_valid(return) or float_inf(return));
 */
double log2(double __x);

/*$
 * requires: float_valid(__x) and __x > 0.;
 * ensures:  (float_valid(return) or float_inf(return));
 */
float log2f(float __x);

/*$
 * requires: float_valid(__x) and __x > 0.;
 * ensures:  (float_valid(return) or float_inf(return));
 */
long double log2l(long double __x);


#endif


/*$
 * requires: float_valid(__x) and float_valid(__y);
 * // may return NaN or infinites
 */
double pow(double __x, double __y);

/*$
 * requires: float_valid(__x) and float_valid(__y);
 * // may return NaN or infinites
 */
float powf(float __x, float __y);

/*$
 * requires: float_valid(__x) and float_valid(__y);
 * // may return NaN or infinites
 */
long double powl(long double __x, long double __y);


/*$
 * requires: float_valid(__x) and __x >= 0.;
 * ensures:  float_valid(return) and return >= 0.;
 */
double sqrt(double __x);

/*$
 * requires: float_valid(__x) and __x >= 0.;
 * ensures:  float_valid(return) and return >= 0.;
 */
float sqrtf(float __x);

/*$
 * requires: float_valid(__x) and __x >= 0.;
 * ensures:  float_valid(return) and return >= 0.;
 */
long double sqrtl(long double __x);


#if defined __USE_XOPEN || defined __USE_ISOC99

/*$
 * requires: float_valid(__x) and float_valid(__y);
 * ensures:  (float_valid(return) or float_inf(return)) and return >= 0.;
 */
double hypot(double __x, double __y);

/*$
 * requires: float_valid(__x) and float_valid(__y);
 * ensures:  (float_valid(return) or float_inf(return)) and return >= 0.;
 */
float hypotf(float __x, float __y);

/*$
 * requires: float_valid(__x) and float_valid(__y);
 * ensures:  (float_valid(return) or float_inf(return)) and return >= 0.;
 */
long double hypotl(long double __x, long double __y);

#endif


#if defined __USE_XOPEN_EXTENDED || defined __USE_ISOC99

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return);
 */
double cbrt(double __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return);
 */
float cbrtf(float __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return);
 */
long double cbrtl(long double __x);

#endif

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return);
 * ensures:  __x <= return and return < __x + 1.;
 */
double ceil(double __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return);
 * ensures:  __x <= return and return < __x + 1.;
 */
float ceilf(float __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return);
 * ensures:  __x <= return and return < __x + 1.;
 */
long double ceill(long double __x);


/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) and return >= 0.;
 * ensures:  (__x >= 0. implies return == __x) and
 *           (__x <= 0. implies return == -__x);
 */
double fabs(double __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) and return >= 0.;
 * ensures:  (__x >= 0. implies return == __x) and
 *           (__x <= 0. implies return == -__x);
 */
float fabsf(float __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) and return >= 0.;
 * ensures:  (__x >= 0. implies return == __x) and
 *           (__x <= 0. implies return == -__x);
 */
long double fabsl(long double __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return);
 * ensures:  __x - 1. < return and return <= __x;
 */
double floor(double __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return);
 * ensures:  __x - 1. < return and return <= __x;
 */
float floorf(float __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return);
 * ensures:  __x - 1. < return and return <= __x;
 */
long double floorl(long double __x);


/*$
 * requires: float_valid(__x) and float_valid(__y);
 * requires: __y != 0;
 * ensures:  float_valid(return);
 * ensures:  (__x >= 0. and __y >= 0. implies return >= 0. and return <   __y) and
 *           (__x >= 0. and __y <= 0. implies return >= 0. and return <  -__y) and
 *           (__x <= 0. and __y >= 0. implies return <= 0. and return >= -__y) and
 *           (__x <= 0. and __y <= 0. implies return <= 0. and return >=  __y);
 */
double fmod(double __x, double __y);

/*$
 * requires: float_valid(__x) and float_valid(__y);
 * requires: __y != 0;
 * ensures:  float_valid(return);
 * ensures:  (__x >= 0. and __y >= 0. implies return >= 0. and return <   __y) and
 *           (__x >= 0. and __y <= 0. implies return >= 0. and return <  -__y) and
 *           (__x <= 0. and __y >= 0. implies return <= 0. and return >= -__y) and
 *           (__x <= 0. and __y <= 0. implies return <= 0. and return >=  __y);
 */
float fmodf(float __x, float __y);

/*$
 * requires: float_valid(__x) and float_valid(__y);
 * requires: __y != 0;
 * ensures:  float_valid(return);
 * ensures:  (__x >= 0. and __y >= 0. implies return >= 0. and return <   __y) and
 *           (__x >= 0. and __y <= 0. implies return >= 0. and return <  -__y) and
 *           (__x <= 0. and __y >= 0. implies return <= 0. and return >= -__y) and
 *           (__x <= 0. and __y <= 0. implies return <= 0. and return >=  __y);
 */
long double fmodl(long double __x, long double __y);


/*$
 * ensures: ((float_inf(__value) and __value >= 0.) implies return == 1) and
 *          ((float_inf(__value) and __value <= 0.) implies return == -1) and
 *          (not float_inf(__value) implies return == 0);
 */
int __isinf(double __value);

/*$
 * ensures: ((float_inf(__value) and __value >= 0.) implies return == 1) and
 *          ((float_inf(__value) and __value <= 0.) implies return == -1) and
 *          (not float_inf(__value) implies return == 0);
 */
int __isinff(float __value);

/*$
 * ensures: ((float_inf(__value) and __value >= 0.) implies return == 1) and
 *          ((float_inf(__value) and __value <= 0.) implies return == -1) and
 *          (not float_inf(__value) implies return == 0);
 */
int __isinfl(long double __value);


/*$
 * ensures: (float_valid(__value) implies return != 0) and
 *          (not float_valid(__value) implies return == 0);
 */
int __finite(double __value);

/*$
 * ensures: (float_valid(__value) implies return != 0) and
 *          (not float_valid(__value) implies return == 0);
 */
int __finitef(float __value);

/*$
 * ensures: (float_valid(__value) implies return != 0) and
 *          (not float_valid(__value) implies return == 0);
 */
int __finitel(long double __value);


/*$
 * ensures: (float_valid(__value) implies return != 0) and
 *          (not float_valid(__value) implies return == 0);
 */
int finite(double __value);

/*$
 * ensures: (float_valid(__value) implies return != 0) and
 *          (not float_valid(__value) implies return == 0);
 */
int finitef(float __value);

/*$
 * ensures: (float_valid(__value) implies return != 0) and
 *          (not float_valid(__value) implies return == 0);
 */
int finitel(long double __value);


/*$
 * ensures: (float_nan(__value) implies return != 0) and
 *          (not float_nan(__value) implies return == 0);
 */
int __isnan(double __value);

/*$
 * ensures: (float_nan(__value) implies return != 0) and
 *          (not float_nan(__value) implies return == 0);
 */
int __isnanf(float __value);

/*$
 * ensures: (float_nan(__value) implies return != 0) and
 *          (not float_nan(__value) implies return == 0);
 */
int __isnanl(long double __value);


/*$
 * ensures: (not float_valid(__value) implies return == 0);
 * // TODO: distinguish normal from denormal
 */
int __isnormal(double __value);

/*$
 * ensures: (not float_valid(__value) implies return == 0);
 * // TODO: distinguish normal from denormal
 */
int __isnormalf(float __value);

/*$
 * ensures: (not float_valid(__value) implies return == 0);
 * // TODO: distinguish normal from denormal
 */
int __isnormall(long double __value);


/*$
 * ensures:  return >= 0 and return <= 4;
 * ensures: (float_nan(__value) implies return == 0) and
 *          (float_inf(__value) implies return == 1) and
 *          (__value == 0. implies return == 3) and
 *          (float_valid(__value) and __value != 0. implies return >= 3 and return <= 4);
 */
int __fpclassify(double __value);

/*$
 * ensures:  return >= 0 and return <= 4;
 * ensures: (float_nan(__value) implies return == 0) and
 *          (float_inf(__value) implies return == 1) and
 *          (__value == 0. implies return == 3) and
 *          (float_valid(__value) and __value != 0. implies return >= 3 and return <= 4);
 */
int __fpclassifyf(float __value);

/*$
 * ensures:  return >= 0 and return <= 4;
 * ensures: (float_nan(__value) implies return == 0) and
 *          (float_inf(__value) implies return == 1) and
 *          (__value == 0. implies return == 3) and
 *          (float_valid(__value) and __value != 0. implies return >= 3 and return <= 4);
 */
int __fpclassifyl(long double __value);


/*$
 * ensures: (__value < 0. implies return != 0) and
 *          (__value > 0. implies return == 0);
 * // 0, infinities and NaN can be positive or negative
 */
int __signbit(double __value);

/*$
 * ensures: (__value < 0. implies return != 0) and
 *          (__value > 0. implies return == 0);
 * // 0, infinities and NaN can be positive or negative
 */
int __signbitf(float __value);

/*$
 * ensures: (__value < 0. implies return != 0) and
 *          (__value > 0. implies return == 0);
 * // 0, infinities and NaN can be positive or negative
 */
int __signbitl(long double __value);

/*
  not documented:
  TODO: int __iseqsig(double __x, double __y);
  TODO: int __issignaling(double __value);
*/

// TODO: not documented:__iseqsig, __issignaling


#ifdef __USE_MISC

/*$
 * requires: float_valid(__x) and float_valid(__y);
 * requires: __y != 0.;
 * ensures:  float_valid(return);
 * ensures:  (__y >= 0. implies return >= -__y and return <  __y) and
 *           (__y <= 0. implies return >=  __y and return < -__y);
 */
double drem(double __x, double __y);

/*$
 * requires: float_valid(__x) and float_valid(__y);
 * requires: __y != 0.;
 * ensures:  float_valid(return);
 * ensures:  (__y >= 0. implies return >= -__y and return <  __y) and
 *           (__y <= 0. implies return >=  __y and return < -__y);
 */
float dremf(float __x, float __y);

/*$
 * requires: float_valid(__x) and float_valid(__y);
 * requires: __y != 0.;
 * ensures:  float_valid(return);
 * ensures:  (__y >= 0. implies return >= -__y and return <  __y) and
 *           (__y <= 0. implies return >=  __y and return < -__y);
 */
long double dreml(long double __x, long double __y);


/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) and return >= 1. and return < 2.;
 */
double significand(double __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) and return >= 1. and return < 2.;
 */
float significandf(float __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) and return >= 1. and return < 2.;
 */
long double significandl(long double __x);

#endif



#ifdef __USE_ISOC99

/*$
 * ensures: (__x >= 0. and __y >= 0. implies return ==  __x) and
 *          (__x >= 0. and __y <= 0. implies return == -__x) and
 *          (__x <= 0. and __y >= 0. implies return == -__x) and
 *          (__x <= 0. and __y <= 0. implies return ==  __x);
 */
double copysign(double __x, double __y);

/*$
 * ensures: (__x >= 0. and __y >= 0. implies return ==  __x) and
 *          (__x >= 0. and __y <= 0. implies return == -__x) and
 *          (__x <= 0. and __y >= 0. implies return == -__x) and
 *          (__x <= 0. and __y <= 0. implies return ==  __x);
 */
float copysignf(float __x, float __y);

/*$
 * ensures: (__x >= 0. and __y >= 0. implies return ==  __x) and
 *          (__x >= 0. and __y <= 0. implies return == -__x) and
 *          (__x <= 0. and __y >= 0. implies return == -__x) and
 *          (__x <= 0. and __y <= 0. implies return ==  __x);
 */
long double copysignl(long double __x, long double __y);


/*$
 * requires: exists int i in [0, size(__tagb) - 1]: __tagb[i] == 0;
 * ensures: float_nan(return);
 */
double nan(const char* __tagb);

/*$
 * requires: exists int i in [0, size(__tagb) - 1]: __tagb[i] == 0;
 * ensures: float_nan(return);
 */
float nanf(const char* __tagb);

/*$
 * requires: exists int i in [0, size(__tagb) - 1]: __tagb[i] == 0;
 * ensures: float_nan(return);
 */
long double nanl(const char* __tagb);

#endif


#if defined __USE_MISC || defined __USE_XOPEN

/*$
 * requires: float_valid(__x);
 * assigns:  _errno;
 * ensures:  float_valid(__x) or float_inf(__x);
 */
double j0(double __x);

/*$
 * requires: float_valid(__x);
 * assigns:  _errno;
 * ensures:  float_valid(__x) or float_inf(__x);
 */
float j0f(float __x);

/*$
 * requires: float_valid(__x);
 * assigns:  _errno;
 * ensures:  float_valid(__x) or float_inf(__x);
 */
long double j0l(long double __x);

/*$
 * requires: float_valid(__x);
 * assigns:  _errno;
 * ensures:  float_valid(__x) or float_inf(__x);
 */
double j1(double __x);

/*$
 * requires: float_valid(__x);
 * assigns:  _errno;
 * ensures:  float_valid(__x) or float_inf(__x);
 */
float j1f(float __x);

/*$
 * requires: float_valid(__x);
 * assigns:  _errno;
 * ensures:  float_valid(__x) or float_inf(__x);
 */
long double j1l(long double __x);

/*$
 * requires: float_valid(__x);
 * assigns:  _errno;
 * ensures:  float_valid(__x) or float_inf(__x);
 */
double jn(int __n, double __x);

/*$
 * requires: float_valid(__x);
 * assigns:  _errno;
 * ensures:  float_valid(__x) or float_inf(__x);
 */
float jnf(int __n, float __x);

/*$
 * requires: float_valid(__x);
 * assigns:  _errno;
 * ensures:  float_valid(__x) or float_inf(__x);
 */
long double jnl(int __n, long double __x);


/*$
 * requires: float_valid(__x);
 * assigns:  _errno;
 * ensures:  float_valid(__x) or float_inf(__x);
 */
double y0(double __x);

/*$
 * requires: float_valid(__x);
 * assigns:  _errno;
 * ensures:  float_valid(__x) or float_inf(__x);
 */
float y0f(float __x);

/*$
 * requires: float_valid(__x);
 * assigns:  _errno;
 * ensures:  float_valid(__x) or float_inf(__x);
 */
long double y0l(long double __x);

/*$
 * requires: float_valid(__x);
 * assigns:  _errno;
 * ensures:  float_valid(__x) or float_inf(__x);
 */
double y1(double __x);

/*$
 * requires: float_valid(__x);
 * assigns:  _errno;
 * ensures:  float_valid(__x) or float_inf(__x);
 */
float y1f(float __x);

/*$
 * requires: float_valid(__x);
 * assigns:  _errno;
 * ensures:  float_valid(__x) or float_inf(__x);
 */
long double y1l(long double __x);

/*$
 * requires: float_valid(__x);
 * assigns:  _errno;
 * ensures:  float_valid(__x) or float_inf(__x);
 */
double yn(int __n, double __x);

/*$
 * requires: float_valid(__x);
 * assigns:  _errno;
 * ensures:  float_valid(__x) or float_inf(__x);
 */
float ynf(int __n, float __x);

/*$
 * requires: float_valid(__x);
 * assigns:  _errno;
 * ensures:  float_valid(__x) or float_inf(__x);
 */
long double ynl(int __n, long double __x);

#endif


#if defined __USE_XOPEN || defined __USE_ISOC99

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(__x);
 */
double erf(double __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(__x);
 */
float erff(float __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(__x);
 */
long double erfl(long double __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(__x);
 */
double erfc(double __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(__x);
 */
float erfcf(float __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(__x);
 */
long double erfcl(long double __x);


// exported by math.h, contains part of the result of lgamma
int signgam;

/*$
 * requires: float_valid(__x);
 * assigns:  _errno;
 * assigns:  signgam;
 * ensures:  float_valid(__x) or float_inf(__x);
 */
double lgamma(double __x);

/*$
 * requires: float_valid(__x);
 * assigns:  _errno;
 * assigns:  signgam;
 * ensures:  float_valid(__x) or float_inf(__x);
 */
float lgammaf(float __x);

/*$
 * requires: float_valid(__x);
 * assigns:  _errno;
 * assigns:  signgam;
 * ensures:  float_valid(__x) or float_inf(__x);
 */
long double lgammal(long double __x);

#endif


#ifdef __USE_ISOC99

/*$
 * requires: float_valid(__x);
 * assigns:  _errno;
 * ensures:  float_valid(__x) or float_inf(__x);
 * // TODO: not defined for negative integers
 */
double tgamma(double __x);

/*$
 * requires: float_valid(__x);
 * assigns:  _errno;
 * ensures:  float_valid(__x) or float_inf(__x);
 * // TODO: not defined for negative integers
 */
float tgammaf(float __x);

/*$
 * requires: float_valid(__x);
 * assigns:  _errno;
 * ensures:  float_valid(__x) or float_inf(__x);
 * // TODO: not defined for negative integers
 */
long double tgammal(long double __x);

// gamma functions are deprecated versions of tgamma

#endif


#ifdef __USE_MISC

/*$
 * requires: float_valid(__x);
 * assigns:  _errno;
 * assigns:  *__signgamp;
 * ensures:  float_valid(__x) or float_inf(__x);
 */
double lgamma_r(double __x, int* __signgamp);

/*$
 * requires: float_valid(__x);
 * assigns:  _errno;
 * assigns:  *__signgamp;
 * ensures:  float_valid(__x) or float_inf(__x);
 */
float lgammaf_r(float __x, int* __signgamp);

/*$
 * requires: float_valid(__x);
 * assigns:  _errno;
 * assigns:  *__signgamp;
 * ensures:  float_valid(__x) or float_inf(__x);
 */
long double lgammal_r(long double __x, int* __signgamp);

#endif


#if defined __USE_XOPEN_EXTENDED || defined __USE_ISOC99

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return); // no overflow possible
 * ensures:  __x - 0.5 <= return and return <= __x + 0.5;
 */
double rint(double __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return); // no overflow possible
 * ensures:  __x - 0.5 <= return and return <= __x + 0.5;
 */
float rintf(float __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return); // no overflow possible
 * ensures:  __x - 0.5 <= return and return <= __x + 0.5;
 */
long double rintl(long double __x);


/*$
 * requires: float_valid(__x) and float_valid(__y);
 * ensures:  float_valid(return) or float_inf(return);
 * ensures:  (__y >= __x implies return >= __x) and
 *           (__y <= __x implies return <= __x);
 * // TODO: better bounds for return
 */
double nextafter(double __x, double __y);

/*$
 * requires: float_valid(__x) and float_valid(__y);
 * ensures:  float_valid(return) or float_inf(return);
 * ensures:  (__y >= __x implies return >= __x) and
 *           (__y <= __x implies return <= __x);
 * // TODO: better bounds for return
 */
float nextafterf(float __x, float __y);

/*$
 * requires: float_valid(__x) and float_valid(__y);
 * ensures:  float_valid(return) or float_inf(return);
 * ensures:  (__y >= __x implies return >= __x) and
 *           (__y <= __x implies return <= __x);
 * // TODO: better bounds for return
 */
long double nextafterl(long double __x, long double __y);


# if defined __USE_ISOC99

/*$
 * requires: float_valid(__x) and float_valid(__y);
 * ensures:  float_valid(return) or float_inf(return);
 * ensures:  (__y >= __x implies return >= __x) and
 *           (__y <= __x implies return <= __x);
 * // TODO: better bounds for return
 */
double nexttoward(double __x, long double __y);

/*$
 * requires: float_valid(__x) and float_valid(__y);
 * ensures:  float_valid(return) or float_inf(return);
 * ensures:  (__y >= __x implies return >= __x) and
 *           (__y <= __x implies return <= __x);
 * // TODO: better bounds for return
 */
float nexttowardf(float __x, long double __y);

/*$
 * requires: float_valid(__x) and float_valid(__y);
 * ensures:  float_valid(return) or float_inf(return);
 * ensures:  (__y >= __x implies return >= __x) and
 *           (__y <= __x implies return <= __x);
 * // TODO: better bounds for return
 */
long double nexttowardl(long double __x, long double __y);

#endif

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) or float_inf(return);
 * ensures:  return <= __x;
 * // TODO: better bounds for return
 */
double nextdown(double __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) or float_inf(return);
 * ensures:  return <= __x;
 * // TODO: better bounds for return
 */
float nextdownf(float __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) or float_inf(return);
 * ensures:  return <= __x;
 * // TODO: better bounds for return
 */
long double nextdownl(long double __x);


/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) or float_inf(return);
 * ensures:  return >= __x;
 * // TODO: better bounds for return
 */
double nextup(double __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) or float_inf(return);
 * ensures:  return >= __x;
 * // TODO: better bounds for return
 */
float nextupf(float __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) or float_inf(return);
 * ensures:  return >= __x;
 * // TODO: better bounds for return
 */
long double nextupl(long double __x);


/*$
 * requires: float_valid(__x) and float_valid(__y);
 * requires: __y != 0.;
 * ensures:  float_valid(return);
 * ensures:  (__y >= 0. implies return >= -__y and return <  __y) and
 *           (__y <= 0. implies return >=  __y and return < -__y);
 */
double remainder(double __x, double __y);

/*$
 * requires: float_valid(__x) and float_valid(__y);
 * requires: __y != 0.;
 * ensures:  float_valid(return);
 * ensures:  (__y >= 0. implies return >= -__y and return <  __y) and
 *           (__y <= 0. implies return >=  __y and return < -__y);
 */
float remainderf(float __x, float __y);

/*$
 * requires: float_valid(__x) and float_valid(__y);
 * requires: __y != 0.;
 * ensures:  float_valid(return);
 * ensures:  (__y >= 0. implies return >= -__y and return <  __y) and
 *           (__y <= 0. implies return >=  __y and return < -__y);
 */
long double remainderl(long double __x, long double __y);


# ifdef __USE_ISOC99

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) or float_inf(return);
 */
double scalbn(double __x, int __n);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) or float_inf(return);
 */
float scalbnf(float __x, int __n);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) or float_inf(return);
 */
long double scalbnl(long double __x, int __n);

# endif

/*$
 * requires: float_valid(__x) and __x != 0;
 * ensures:  return >= -1074 and return <= 1023;
 */
int ilogb(double __x);

/*$
 * requires: float_valid(__x) and __x != 0;
 * ensures:  return >= -149 and return <= 127;
 */
int ilogbf(float __x);

/*$
 * // exponent range based on 128-bit IEEE quadruple precision
 * requires: float_valid(__x) and __x != 0;
 * ensures:  return >= -16493 and return <= 16383;
 */
int ilogbl(long double __x);

#endif


// TODO: not documented: llogb


#ifdef __USE_ISOC99

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) or float_inf(return);
 */
double scalbln(double __x, long int __n);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) or float_inf(return);
 */
float scalblnf(float __x, long int __n);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return) or float_inf(return);
 */
long double scalblnl(long double __x, long int __n);


/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return); // no overflow possible
 * ensures:  __x - 0.5 <= return and return <= __x + 0.5;
 */
double nearbyint(double __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return); // no overflow possible
 * ensures:  __x - 0.5 <= return and return <= __x + 0.5;
 */
float nearbyintf(float __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return); // no overflow possible
 * ensures:  __x - 0.5 <= return and return <= __x + 0.5;
 */
long double nearbyintl(long double __x);


/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return); // no overflow possible
 * ensures:  __x - 0.5 <= return and return <= __x + 0.5;
 */
double round(double __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return); // no overflow possible
 * ensures:  __x - 0.5 <= return and return <= __x + 0.5;
 */
float roundf(float __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return); // no overflow possible
 * ensures:  __x - 0.5 <= return and return <= __x + 0.5;
 */
long double roundl(long double __x);


/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return); // no overflow possible
 * ensures:  (__x >= 0. implies return <= __x and __x < return + 1.) and
 *           (__x <= 0. implies return - 1. < __x and __x <= return);
 */
double trunc(double __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return); // no overflow possible
 * ensures:  (__x >= 0. implies return <= __x and __x < return + 1.) and
 *           (__x <= 0. implies return - 1. < __x and __x <= return);
 */
float truncf(float __x);

/*$
 * requires: float_valid(__x);
 * ensures:  float_valid(return); // no overflow possible
 * ensures:  (__x >= 0. implies return <= __x and __x < return + 1.) and
 *           (__x <= 0. implies return - 1. < __x and __x <= return);
 */
long double truncl(long double __x);


/*$
 * requires: float_valid(__x) and float_valid(__y) and __y != 0.;
 * assigns:  *__quo;
 * ensures:  float_valid(return);
 * ensures:  (__y >= 0. implies return >= -__y and return <  __y) and
 *           (__y <= 0. implies return >=  __y and return < -__y);
 */
double remquo(double __x, double __y, int* __quo);

/*$
 * requires: float_valid(__x) and float_valid(__y) and __y != 0.;
 * assigns:  *__quo;
 * ensures:  float_valid(return);
 * ensures:  (__y >= 0. implies return >= -__y and return <  __y) and
 *           (__y <= 0. implies return >=  __y and return < -__y);
 */
float remquof(float __x, float __y, int* __quo);

/*$
 * requires: float_valid(__x) and float_valid(__y) and __y != 0.;
 * assigns:  *__quo;
 * ensures:  float_valid(return);
 * ensures:  (__y >= 0. implies return >= -__y and return <  __y) and
 *           (__y <= 0. implies return >=  __y and return < -__y);
 */
long double remquol(long double __x, long double __y, int* __quo);


static const long int _LONG_MIN = LONG_MIN;
static const long int _LONG_MAX = LONG_MAX;
static const long long int _LLONG_MIN = LLONG_MIN;
static const long long int _LLONG_MAX = LLONG_MAX;

/*$
 * requires: float_valid(__x) and __x >= _LONG_MIN and __x <= _LONG_MAX;
 * ensures:  __x - 1. < return && return < __x + 1.;
 */
long int lrint(double __x);

/*$
 * requires: float_valid(__x) and __x >= _LONG_MIN and __x <= _LONG_MAX;
 * ensures:  __x - 1. < return && return < __x + 1.;
 */
long int lrintf(float __x);

/*$
 * requires: float_valid(__x) and __x >= _LONG_MIN and __x <= _LONG_MAX;
 * ensures:  __x - 1. < return && return < __x + 1.;
 */
long int lrintl(long double __x);


/*$
 * requires: float_valid(__x) and __x >= _LLONG_MIN and __x <= _LLONG_MAX;
 * ensures:  __x - 1. < return && return < __x + 1.;
 */
long long int llrint(double __x);

/*$
 * requires: float_valid(__x) and __x >= _LLONG_MIN and __x <= _LLONG_MAX;
 * ensures:  __x - 1. < return && return < __x + 1.;
 */
long long int llrintf(float __x);

/*$
 * requires: float_valid(__x) and __x >= _LLONG_MIN and __x <= _LLONG_MAX;
 * ensures:  __x - 1. < return && return < __x + 1.;
 */
long long int llrintl(long double __x);


/*$
 * requires: float_valid(__x) and __x >= _LONG_MIN and __x <= _LONG_MAX;
 * ensures:  __x - 0.5 <= return && return <= __x + 0.5;
 */
long int lround(double __x);

/*$
 * requires: float_valid(__x) and __x >= _LONG_MIN and __x <= _LONG_MAX;
 * ensures:  __x - 0.5 <= return && return <= __x + 0.5;
 */
long int lroundf(float __x);

/*$
 * requires: float_valid(__x) and __x >= _LONG_MIN and __x <= _LONG_MAX;
 * ensures:  __x - 0.5 <= return && return <= __x + 0.5;
 */
long int lroundl(long double __x);


/*$
 * requires: float_valid(__x) and __x >= _LLONG_MIN and __x <= _LLONG_MAX;
 * ensures:  __x - 0.5 <= return && return <= __x + 0.5;
 */
long long int llround(double __x);

/*$
 * requires: float_valid(__x) and __x >= _LLONG_MIN and __x <= _LLONG_MAX;
 * ensures:  __x - 0.5 <= return && return <= __x + 0.5;
 */
long long int llroundf(float __x);

/*$
 * requires: float_valid(__x) and __x >= _LLONG_MIN and __x <= _LLONG_MAX;
 * ensures:  __x - 0.5 <= return && return <= __x + 0.5;
 */
long long int llroundl(long double __x);


/*$
 * requires: float_valid(__x) and float_valid(__y);
 * ensures:  (float_valid(return) or float_inf(return)) and return >= 0.;
 */
double fdim(double __x, double __y);

/*$
 * requires: float_valid(__x) and float_valid(__y);
 * ensures:  (float_valid(return) or float_inf(return)) and return >= 0.;
 */
float fdimf(float __x, float __y);

/*$
 * requires: float_valid(__x) and float_valid(__y);
 * ensures:  (float_valid(return) or float_inf(return)) and return >= 0.;
 */
long double fdiml(long double __x, long double __y);


/*$
 * requires: float_valid(__x) and float_valid(__y);
 * ensures:  float_valid(return);
 * ensures:  (__x >= __y implies return == __x) and
 *           (__x <= __y implies return == __y);
 */
double fmax(double __x, double __y);

/*$
 * requires: float_valid(__x) and float_valid(__y);
 * ensures:  float_valid(return);
 * ensures:  (__x >= __y implies return == __x) and
 *           (__x <= __y implies return == __y);
 */
float fmaxf(float __x, float __y);

/*$
 * requires: float_valid(__x) and float_valid(__y);
 * ensures:  float_valid(return);
 * ensures:  (__x >= __y implies return == __x) and
 *           (__x <= __y implies return == __y);
 */
long double fmaxl(long double __x, long double __y);


/*$
 * requires: float_valid(__x) and float_valid(__y);
 * ensures:  float_valid(return);
 * ensures:  (__x <= __y implies return == __x) and
 *           (__x >= __y implies return == __y);
 */
double fmin(double __x, double __y);

/*$
 * requires: float_valid(__x) and float_valid(__y);
 * ensures:  float_valid(return);
 * ensures:  (__x <= __y implies return == __x) and
 *           (__x >= __y implies return == __y);
 */
float fminf(float __x, float __y);

/*$
 * requires: float_valid(__x) and float_valid(__y);
 * ensures:  float_valid(return);
 * ensures:  (__x <= __y implies return == __x) and
 *           (__x >= __y implies return == __y);
 */
long double fminl(long double __x, long double __y);


/*$
 * requires: float_valid(__x) and float_valid(__y) and float_valid(__z);
 * ensures:  float_valid(return) or float_inf(return);
 * //TODO: return == x * y + z, with proper rounding
 */
double fma(double __x, double __y, double __z);

/*$
 * requires: float_valid(__x) and float_valid(__y) and float_valid(__z);
 * ensures:  float_valid(return) or float_inf(return);
 * //TODO: return == x * y + z, with proper rounding
 */
float fmaf(float __x, float __y, float __z);

/*$
 * requires: float_valid(__x) and float_valid(__y) and float_valid(__z);
 * ensures:  float_valid(return) or float_inf(return);
 * //TODO: return == x * y + z, with proper rounding
 */
long double fmal(long double __x, long double __y, long double __z);

#endif

// TODO: not documented: roundeven, fromfp, ufromfp, fromfpx, ufromfpx, fmaxmag, fminmag, totalorder, totalordermag, canonicalize, getpauload, setpayload, setpayloadsig


/*$
 * requires: float_valid(__x) and float_valid(__n);
 * ensures:  float_valid(return) or float_inf(return);
 */
double scalb(double __x, double __n);

/*$
 * requires: float_valid(__x) and float_valid(__n);
 * ensures:  float_valid(return) or float_inf(return);
 */
float scalbf(float __x, float __n);

/*$
 * requires: float_valid(__x) and float_valid(__n);
 * ensures:  float_valid(return) or float_inf(return);
 */
long double scalbl(long double __x, long double __n);


/*
  TODO: __builtin
  
*/

/*$
 * ensures: float_inf(return) and return >= 0.;
 */
double __builtin_huge_val();
  
/*$
 * ensures: float_inf(return) and return >= 0.;
 */
float __builtin_huge_valf();
  
/*$
 * ensures: float_inf(return) and return >= 0.;
 */
long double __builtin_huge_vall();

/*$
 * ensures: float_inf(return) and return >= 0.;
 */
float __builtin_inff();

/*$
 * ensures: float_nan(return);
 */
float __builtin_nanf(const char* __tagb);

/* 
   not well typed:
   __builtin_isgreater(x, y)
   __builtin_isgreaterequal(x, y)
   __builtin_isless(x y)
   __builtin_islessequal(x, y)
   __builtin_islessgreater(x, y)
   __builtin_isunordered((x. y)
*/




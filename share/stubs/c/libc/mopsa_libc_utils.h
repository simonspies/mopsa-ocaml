/****************************************************************************/
/*                                                                          */
/* This file is part of MOPSA, a Modular Open Platform for Static Analysis. */
/*                                                                          */
/* Copyright (C) 2017-2019 The MOPSA Project.                               */
/*                                                                          */
/* This program is free software: you can redistribute it and/or modify     */
/* it under the terms of the GNU Lesser General Public License as published */
/* by the Free Software Foundation, either version 3 of the License, or     */
/* (at your option) any later version.                                      */
/*                                                                          */
/* This program is distributed in the hope that it will be useful,          */
/* but WITHOUT ANY WARRANTY; without even the implied warranty of           */
/* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            */
/* GNU Lesser General Public License for more details.                      */
/*                                                                          */
/* You should have received a copy of the GNU Lesser General Public License */
/* along with this program.  If not, see <http://www.gnu.org/licenses/>.    */
/*                                                                          */
/****************************************************************************/

/*
  Useful definitions used throughout the libc stubs.
 */

#ifndef MOPSA_LIBC_UTILS_H
#define MOPSA_LIBC_UTILS_H

extern int _errno;

// Translate a numeric file descriptor into the address of its resource
extern void *_mopsa_int_to_fd(int fd);


/*
  Some useful predicates
*/

/*$$
 * predicate valid_string(s):
 *   exists int _i in [0, size(s) - 1]: s[_i] == 0
 * ;
 *
 * predicate valid_primed_string(s):
 *   exists int _i in [0, size(s) - 1]: (s[_i])' == 0
 * ;
 *
 * predicate valid_substring(s, n):
 *   exists int _i in [0, n - 1]: s[_i] == 0
 * ;
 *
 * predicate valid_primed_substring(s, n):
 *   exists int _i in [0, n - 1]: (s[_i])' == 0
 * ;
 */



#endif /* MOPSA_LIBC_UTILS_H */

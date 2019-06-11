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

// Translate a file description resource into a numeric file descriptor
extern int _mopsa_file_description_to_descriptor(void *f);


// Translate a numeric file descriptor into a resource pointer
extern void *_mopsa_file_descriptor_to_description(int fd);


#endif /* MOPSA_LIBC_UTILS_H */

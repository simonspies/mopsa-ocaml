(****************************************************************************)
(*                                                                          *)
(* This file is part of MOPSA, a Modular Open Platform for Static Analysis. *)
(*                                                                          *)
(* Copyright (C) 2017-2019 The MOPSA Project.                               *)
(*                                                                          *)
(* This program is free software: you can redistribute it and/or modify     *)
(* it under the terms of the GNU Lesser General Public License as published *)
(* by the Free Software Foundation, either version 3 of the License, or     *)
(* (at your option) any later version.                                      *)
(*                                                                          *)
(* This program is distributed in the hope that it will be useful,          *)
(* but WITHOUT ANY WARRANTY; without even the implied warranty of           *)
(* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            *)
(* GNU Lesser General Public License for more details.                      *)
(*                                                                          *)
(* You should have received a copy of the GNU Lesser General Public License *)
(* along with this program.  If not, see <http://www.gnu.org/licenses/>.    *)
(*                                                                          *)
(****************************************************************************)


(** List of builtin functions *)
let builtin_functions = Hashtbl.create 16

let _ =
  List.iter (fun a -> Hashtbl.add builtin_functions a ()) [
      "__builtin_constant_p";
      "__builtin_expect";

      "__builtin_va_start";
      "__builtin_va_end";
      "__builtin_va_copy";

      "__builtin_alloca";
      "alloca";

      "printf";
      "__printf_chk";
      "fprintf";
      "__fprintf_chk";
      "sprintf";
      "__sprintf_chk";
      "__builtin___sprintf_chk";
      "snprintf";
      "fscanf";
      "scanf";
      "sscanf";

      "fwprintf";
      "wprintf";
      "swprintf";

      "_mopsa_rand_s8";
      "_mopsa_rand_u8";
      "_mopsa_rand_s16";
      "_mopsa_rand_u16";
      "_mopsa_rand_s32";
      "_mopsa_rand_u32";
      "_mopsa_rand_s64";
      "_mopsa_rand_u64";
      "_mopsa_rand_float";
      "_mopsa_rand_double";
      "_mopsa_rand_void_pointer";

      "_mopsa_range_s8";
      "_mopsa_range_u8";
      "_mopsa_range_s16";
      "_mopsa_range_u16";
      "_mopsa_range_s32";
      "_mopsa_range_u32";
      "_mopsa_range_s64";
      "_mopsa_range_u64";
      "_mopsa_range_int";
      "_mopsa_range_float";
      "_mopsa_range_double";

      "_mopsa_invalid_pointer";

      "_mopsa_panic";
      "_mopsa_print";

      "_mopsa_assume";

      "_mopsa_assert_exists";
      "_mopsa_assert";
      "_mopsa_assert_safe";
      "_mopsa_assert_unsafe";

      "_mopsa_register_file_resource";
      "_mopsa_register_file_resource_at";
      "_mopsa_find_file_resource";

      "error";
      "error_at_line"
    ]

let is_builtin_function = Hashtbl.mem builtin_functions

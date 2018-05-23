(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(** Mapping between operators and magic functions. *)

open Framework.Ast
open Universal.Ast
open Ast


(*==========================================================================*)
(**                      {2 Binary operators}                               *)
(*==========================================================================*)


(** Binary operator of a magic function *)
let fun_to_binop = function
  | "__add__" -> O_plus T_any
  | "__sub__" -> O_minus T_any
  | "__mul__" -> O_mult T_any
  | "__matmul__" -> O_py_mat_mult
  | "__truediv__" -> O_div T_any
  | "__floordiv__" -> O_py_floor_div
  | "__mod__" -> O_mod T_any
  | "__pow__" -> O_pow
  | "__lshift__" -> O_bit_lshift
  | "__rshift__" -> O_bit_rshift
  | "__and__" -> O_bit_and
  | "__xor__" -> O_bit_xor
  | "__or__" -> O_bit_or
  | "__eq__" -> O_eq
  | "__ne__" -> O_ne
  | "__lt__" -> O_lt
  | "__le__" -> O_le
  | "__gt__" -> O_gt
  | "__ge__" -> O_ge
  | "__radd__" -> O_plus T_any
  | "__rsub__" -> O_minus T_any
  | "__rmul__" -> O_mult T_any
  | "__rmatmul__" -> O_py_mat_mult
  | "__rtruediv__" -> O_div T_any
  | "__rfloordiv__" -> O_py_floor_div
  | "__rmod__" -> O_mod T_any
  | "__rpow__" -> O_pow
  | "__rlshift__" -> O_bit_lshift
  | "__rrshift__" -> O_bit_rshift
  | "__rand__" -> O_bit_and
  | "__rxor__" -> O_bit_xor
  | "__ror__" -> O_bit_or
  | "__iadd__" -> O_plus T_any
  | "__isub__" -> O_minus T_any
  | "__imul__" -> O_mult T_any
  | "__imatmul__" -> O_py_mat_mult
  | "__itruediv__" -> O_div T_any
  | "__ifloordiv__" -> O_py_floor_div
  | "__imod__" -> O_mod T_any
  | "__ipow__" -> O_pow
  | "__ilshift__" -> O_bit_lshift
  | "__irshift__" -> O_bit_rshift
  | "__iand__" -> O_bit_and
  | "__ixor__" -> O_bit_xor
  | "__ior__" -> O_bit_or
  | _ -> assert false

(** Magic function of a binary operator *)
let binop_to_fun = function
  | O_plus T_any -> "__add__"
  | O_minus T_any -> "__sub__"
  | O_mult T_any -> "__mul__"
  | O_py_mat_mult -> "__matmul__"
  | O_div T_any -> "__truediv__"
  | O_py_floor_div -> "__floordiv__"
  | O_mod T_any -> "__mod__"
  | O_pow -> "__pow__"
  | O_bit_lshift -> "__lshift__"
  | O_bit_rshift -> "__rshift__"
  | O_bit_and -> "__and__"
  | O_bit_xor -> "__xor__"
  | O_bit_or -> "__or__"
  | O_eq -> "__eq__"
  | O_ne -> "__ne__"
  | O_lt -> "__lt__"
  | O_le -> "__le__"
  | O_gt -> "__gt__"
  | O_ge -> "__ge__"
  | _ -> assert false

(** Right magic function of a binary operator *)
let binop_to_rev_fun = function
  | O_plus T_any -> "__radd__"
  | O_minus T_any -> "__rsub__"
  | O_mult T_any -> "__rmul__"
  | O_py_mat_mult -> "__rmatmul__"
  | O_div T_any -> "__rtruediv__"
  | O_py_floor_div -> "__rfloordiv__"
  | O_mod T_any -> "__rmod__"
  | O_pow -> "__rpow__"
  | O_bit_lshift -> "__rlshift__"
  | O_bit_rshift -> "__rrshift__"
  | O_bit_and -> "__rand__"
  | O_bit_xor -> "__rxor__"
  | O_bit_or -> "__ror__"
  | _ -> assert false


(** Increment magic function of a binary operator *)
let binop_to_incr_fun = function
  | O_plus T_any -> "__iadd__"
  | O_minus T_any -> "__isub__"
  | O_mult T_any -> "__imul__"
  | O_py_mat_mult -> "__imatmul__"
  | O_div T_any -> "__itruediv__"
  | O_py_floor_div -> "__ifloordiv__"
  | O_mod T_any -> "__imod__"
  | O_pow -> "__ipow__"
  | O_bit_lshift -> "__ilshift__"
  | O_bit_rshift -> "__irshift__"
  | O_bit_and -> "__iand__"
  | O_bit_xor -> "__ixor__"
  | O_bit_or -> "__ior__"
  | _ -> assert false


(** Check that a magic function corresponds to a binary operator *)
let is_binop_function = function
  | "__add__"
  | "__sub__"
  | "__mul__"
  | "__matmul__"
  | "__truediv__"
  | "__floordiv__"
  | "__mod__"
  | "__pow__"
  | "__lshift__"
  | "__rshift__"
  | "__and__"
  | "__xor__"
  | "__or__"
  | "__eq__"
  | "__ne__"
  | "__lt__"
  | "__le__"
  | "__gt__"
  | "__ge__"
  | "__iadd__"
  | "__isub__"
  | "__imul__"
  | "__imatmul__"
  | "__itruediv__"
  | "__ifloordiv__"
  | "__imod__"
  | "__ipow__"
  | "__ilshift__"
  | "__irshift__"
  | "__iand__"
  | "__ixor__"
  | "__ior__"
  | "__radd__"
  | "__rsub__"
  | "__rmul__"
  | "__rmatmul__"
  | "__rtruediv__"
  | "__rfloordiv__"
  | "__rmod__"
  | "__rpow__"
  | "__rlshift__"
  | "__rrshift__"
  | "__rand__"
  | "__rxor__"
  | "__ror__" -> true
  | _ -> false


(*==========================================================================*)
(**                       {2 Unary operators}                               *)
(*==========================================================================*)

(** Unary operator of a magic function *)
let fun_to_unop = function
  | "__not__" -> O_log_not
  | "__neg__" -> O_minus T_any
  | "__pos__" -> O_plus T_any
  | "__invert__" -> O_bit_invert
  | _ -> assert false


(** Check that a magic function corresponds to a binary operator *)
let is_unop_function = function
  | "__not__"
  | "__neg__"
  | "__pos__"
  | "__invert__" -> true
  | _ -> false


(** Magic function of an unary operator *)
let unop_to_fun = function
  | O_log_not -> "__not__"
  | O_plus T_any -> "__pos__"
  | O_minus T_any -> "__neg__"
  | O_bit_invert -> "__invert__"
  | _ -> assert false
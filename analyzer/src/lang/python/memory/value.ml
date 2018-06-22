(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(** Non-relational abstraction of Python values. *)

open Framework.Essentials
open Universal.Ast
open Ast
open Addr

let name = "python.memory.value"
let debug fmt = Debug.debug ~channel:name fmt


(*==========================================================================*)
(**                           {2 Lattices}                                  *)
(*==========================================================================*)

(** NoneType singleton lattice *)
module N = Framework.Lattices.Finite_powerset.Make(struct
    type t = Framework.Ast.constant
    let values = [C_py_none]
    let print fmt c = pp_constant fmt c
  end
  )

(** Powerset lattice of finite strings *)
module S = Framework.Lattices.Powerset.Make(struct
    type t = string
    let compare = compare
    let print fmt s = Format.fprintf fmt "\"%s\"" s
  end)

(** NotImplementedType singleton lattice *)
module NI = Framework.Lattices.Finite_powerset.Make(struct
    type t = Framework.Ast.constant
    let values = [C_py_not_implemented]
    let print fmt c = pp_constant fmt c
  end
  )

(** Empty value singleton lattice *)
module E = Framework.Lattices.Finite_powerset.Make(struct
    type t = Framework.Ast.constant
    let values = [C_py_empty]
    let print fmt c = pp_constant fmt c
  end
  )

(** Integer intervals lattice *)
module I = Universal.Numeric.Values.Int.Value

(** Float intervals lattices *)
module F = Universal.Numeric.Values.Float.Value



(*==========================================================================*)
(**                      {2 Value abstraction}                              *)
(*==========================================================================*)


type t = {
  none: N.t;
  string: S.t;
  int : I.t;
  float : F.t;
  notimplem: NI.t;
  empty: E.t;
}

let bottom = {
  none = N.bottom;
  string = S.bottom;
  int = I.bottom;
  float = F.bottom;
  notimplem = NI.bottom;
  empty = E.bottom;
}


let top = {
  none = N.top;
  string = S.top;
  int = I.top;
  float = F.top;
  notimplem = NI.top;
  empty = E.top;
}

let is_bottom abs =
  N.is_bottom abs.none &&
  S.is_bottom abs.string &&
  I.is_bottom abs.int &&
  F.is_bottom abs.float &&
  F.is_bottom abs.float &&
  NI.is_bottom abs.notimplem &&
  E.is_bottom abs.empty

let is_top abs =
  N.is_top abs.none &&
  S.is_top abs.string &&
  I.is_top abs.int &&
  F.is_top abs.float &&
  NI.is_top abs.notimplem &&
  E.is_top abs.empty

let print fmt abs =
  let open Format in
  if is_top abs then
    fprintf fmt "⊤"
  else
  if is_bottom abs then
    pp_print_string fmt " ⊥ "
  else (
    fprintf fmt "@[<h>(|";
    let pred = ref false in

    if not (I.is_bottom abs.int) then (
      fprintf fmt " i: %a " I.print abs.int;
      pred := true;
    );

    if not (F.is_bottom abs.float) then (
      fprintf fmt "%s f: %a " (if !pred then "∨" else "") F.print abs.float;
      pred := true;
    );

    if not (S.is_bottom abs.string) then (
      fprintf fmt "%s s: %a " (if !pred then "∨" else "") S.print abs.string;
      pred := true;
    );

    if not (N.is_bottom abs.none) then (
      fprintf fmt "%s n: %a " (if !pred then "∨" else "") N.print abs.none;
      pred := true;
    );

    if not (NI.is_bottom abs.notimplem) then
      fprintf fmt "%s ni: %a " (if !pred then "∨" else "") NI.print abs.notimplem;

    fprintf fmt "|)@]"
  )


let leq abs1 abs2 =
  N.leq abs1.none abs2.none &&
  S.leq abs1.string abs2.string &&
  I.leq abs1.int abs2.int &&
  F.leq abs1.float abs2.float &&
  NI.leq abs1.notimplem abs2.notimplem &&
  E.leq abs1.empty abs2.empty

let join abs1 abs2 = {
  none = N.join abs1.none abs2.none;
  string = S.join abs1.string abs2.string;
  int = I.join abs1.int abs2.int;
  float = F.join abs1.float abs2.float;
  notimplem = NI.join abs1.notimplem abs2.notimplem;
  empty = E.join abs1.empty abs2.empty;
}

let meet abs1 abs2 = {
  none = N.meet abs1.none abs2.none;
  string = S.meet abs1.string abs2.string;
  int = I.meet abs1.int abs2.int;
  float = F.meet abs1.float abs2.float;
  notimplem = NI.meet abs1.notimplem abs2.notimplem;
  empty = E.meet abs1.empty abs2.empty;
}

let widening ctx abs1 abs2 = {
  none = N.widening ctx abs1.none abs2.none;
  string = S.widening ctx abs1.string abs2.string;
  int = I.widening ctx abs1.int abs2.int;
  float = F.widening ctx abs1.float abs2.float;
  notimplem = NI.widening ctx abs1.notimplem abs2.notimplem;
  empty = E.widening ctx abs1.empty abs2.empty;
}

(** Creation of uniquely typed values *)
let none n = {
  bottom with
  none = n;
}

let integer i = {
  bottom with
  int = i;
}

let float i = {
  bottom with
  float = i;
}

let string s = {
  bottom with
  string = s
}

let notimplem ne = {
  bottom with
  notimplem = ne
}

let empty e = {
  bottom with
  empty = e
}

let zone = Zone.Z_py_value

(** Creation of a value from a program constant *)
let of_constant c =
  match c with
  | C_py_none | C_top T_py_none -> none  (N.singleton c)

  | C_int n -> integer (I.of_constant c)
  | C_int_interval _ -> integer (I.of_constant c)
  | C_top T_int -> integer I.top

  | C_float n -> float (F.of_constant c)
  | C_float_interval _ -> float (F.of_constant c)
  | C_top T_float -> float F.top

  | C_py_not_implemented | C_top T_py_not_implemented -> notimplem  (NI.singleton c)

  | C_string s -> string (S.singleton s)
  | C_top T_string -> string S.top

  | C_py_empty | C_top T_py_empty -> empty  (E.singleton c)

  | _ -> top

(** Boolean predicates *)
let can_be_true abs =
  (I.can_be_true abs.int) ||
  (F.can_be_true abs.float)

let can_be_false abs =
  (I.can_be_false abs.int) ||
  (F.can_be_false abs.float)


(** Forward evaluation of unary operators *)
let fwd_unop op abs = {
  abs with
  int = I.fwd_unop op abs.int;
  float = F.fwd_unop op abs.float;
}

(** Filtering functions *)
let assume_true abs = {
  abs with
  int = I.assume_true abs.int;
  float = F.assume_true abs.float;
}


let assume_false abs = {
  abs with
  int = I.assume_false abs.int;
  float = F.assume_false abs.float;
}

(** Forwared evaluation of binary operators *)
let fwd_binop op abs1 abs2 = {
  bottom with
  int = I.fwd_binop op abs1.int abs2.int;
  float = F.fwd_binop op abs1.float abs2.float;
}

let of_bool = function
  | Some true -> integer (I.of_constant (C_int Z.one))
  | Some false -> integer (I.of_constant (C_int Z.zero))
  | None -> integer (I.of_constant (C_int_interval (Z.zero, Z.one)))

let fwd_filter op abs1 abs2 =
  (I.fwd_filter op abs1.int abs2.int) ||
  (F.fwd_filter op abs1.float abs2.float)


let bwd_unop op abs rabs =
  {bottom with
   int = I.bwd_unop op abs.int rabs.int;
   float = F.bwd_unop op abs.float rabs.float
  }

(** Backward evaluation of binary operators *)
let bwd_binop_default abs1 abs2 = (abs1, abs2)
let bwd_binop op abs1 abs2 rabs =
  let int1, int2 = I.bwd_binop op abs1.int abs2.int rabs.int in
  let float1, float2 = F.bwd_binop op abs1.float abs2.float rabs.float in
  {abs1 with int = int1; float = float1},
  {abs2 with int = int2; float = float2}

(** Backward filters of comparison operators *)
let bwd_filter op abs1 abs2 =
  let int1, int2 = I.bwd_filter op abs1.int abs2.int in
  let float1, float2 = F.bwd_filter op abs1.float abs2.float in
  {abs1 with int = int1; float = float1},
  {abs2 with int = int2; float = float2}

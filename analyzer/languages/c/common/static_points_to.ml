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


(** Static evaluation of a pointer expression  *)


open Mopsa
open Universal.Ast
open Ast
open Base


(** Static points-to values *)
type static_points_to =
  | AddrOf of base * expr * mode option
  | Eval of var * mode option * expr
  | Fun of c_fundec
  | Null
  | Invalid
  | Top


(** Advance the offset of a symbolic pointer *)
let advance_offset (op:operator) (ptr:static_points_to) (o:expr) typ range : static_points_to =
  (* Size of the pointed type *)
  let size = under_type typ |> void_to_char |> sizeof_type in

  let advance oo =
    let bytes =
      if Z.equal size Z.one then o
      else mk_binop o O_mult (mk_z size range) range ~etyp:T_int
    in
    match op, ekind oo with
    | O_plus, E_constant (C_int n) when Z.(n = zero) -> bytes
    | _ -> mk_binop oo op bytes range ~etyp:T_int
  in

  match ptr with
  | AddrOf (b, oo, mode) -> AddrOf (b, advance oo, mode)

  | Eval (p, mode, oo) -> Eval (p, mode, advance oo)

  | Null -> Top

  | Invalid -> Invalid

  | Fun _ ->
    panic_at range
      "pointers.add_offset: pointer arithmetics on functions not supported"

  | Top -> Top



(** Symbolic evaluation of a pointer expression *)
let rec eval_opt exp : static_points_to option =
  match ekind exp with
  | E_constant(C_int n) when Z.equal n Z.zero ->
    Null |> OptionExt.return

  | E_constant(C_c_invalid) ->
    Invalid |> OptionExt.return

  | E_constant(C_top t) when is_c_pointer_type t ->
    Top |> OptionExt.return

  | E_addr (addr, mode) ->
    AddrOf(mk_addr_base addr, mk_zero exp.erange, mode) |> OptionExt.return

  | x when is_c_int_type exp.etyp || is_numeric_type exp.etyp ->
    Top |> OptionExt.return

  | E_c_deref { ekind = E_c_address_of e } ->
    eval_opt e

  | E_c_address_of e ->
    begin match remove_casts e |> ekind with
      | E_var (v, mode) ->
        AddrOf (mk_var_base v, mk_zero exp.erange, mode) |>
        OptionExt.return

      | E_constant (C_top _) ->
        Top |>
        OptionExt.return

      | E_c_function f ->
        Fun f |>
        OptionExt.return

      | E_c_deref p ->
        eval_opt p

      | _ ->
        warn_at exp.erange "evaluation of pointer expression %a not supported" pp_expr exp;
        None
    end

  | E_c_cast (e, _) when is_c_pointer_type exp.etyp ->
    eval_opt e

  | E_c_function f ->
    Fun f |> OptionExt.return

  | E_constant (C_c_string (s, k)) ->
    let str = mk_string_base ~kind:k ~typ:(under_type (etyp exp)) s in
    AddrOf(str, mk_zero exp.erange, None) |> OptionExt.return

  | E_var (a, mode) when is_c_array_type a.vtyp ->
    AddrOf(mk_var_base a, mk_zero exp.erange, mode) |> OptionExt.return

  | E_c_deref a when is_c_array_type (under_type a.etyp) ->
    eval_opt a

  | E_binop(O_plus | O_minus as op, e1, e2) when is_c_pointer_type e1.etyp
                                              || is_c_pointer_type e2.etyp->
    let p, i =
      if is_c_pointer_type e1.etyp || is_c_array_type e1.etyp
      then e1, e2
      else e2, e1
    in
    eval_opt p |>
    OptionExt.lift @@ fun ptr ->
    advance_offset op ptr i p.etyp exp.erange

  | E_var (v, mode) when is_c_pointer_type v.vtyp ->
    Eval (v, mode, mk_zero exp.erange) |> OptionExt.return

  | _ ->
    warn_at exp.erange "evaluation of pointer expression %a not supported" pp_expr exp;
    None


(** Symbolic evaluation of a pointer expression *)
let eval exp : static_points_to =
  match eval_opt exp with
  | Some ptr -> ptr
  | None -> panic_at exp.erange "evaluation of pointer expression %a not supported" pp_expr exp

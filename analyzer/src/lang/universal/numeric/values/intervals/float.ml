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

(** Interval abstraction of float values. *)

open Mopsa
open Sig.Abstraction.Simplified_value
open Rounding
open Ast
open Bot
open Common

module I = ItvUtils.FloatItvNan
module FI = ItvUtils.FloatItv
module II = ItvUtils.IntItv


let prec_of_type = function
  | T_float p -> p
  | _ -> assert false

module SimplifiedValue =
struct

  (** Types *)

  type t = I.t

  include GenValueId(
    struct
      type nonrec t = t
      let name = "universal.numeric.values.intervals.float"
      let display = "float-itv"
    end
    )


  let () =
    import_standalone_option Rounding.name ~into:name

  let accept_type = function
    | T_float _ -> true
    | _ -> false

  (** Lattice operations *)

  let bottom = I.bot

  let top_of_prec = function
    | F_SINGLE -> I.single_special
    | F_DOUBLE -> I.double_special
    | F_LONG_DOUBLE -> I.long_double_special
    | F_REAL -> I.real

  let top = top_of_prec F_LONG_DOUBLE

  let is_bottom = I.is_bot

  let subset (a1:t) (a2:t) : bool = I.included a1 a2

  let join (a1:t) (a2:t) : t = I.join a1 a2

  let meet (a1:t) (a2:t) : t = I.meet a1 a2

  let widen ctx (a1:t) (a2:t) : t = I.widen a1 a2

  let print printer (a:t) = unformat (I.fprint I.dfl_fmt) printer a


  (** Arithmetic operators *)

  let constant c tr =
    let p = prec_of_type tr in
    match c with
    | C_float i ->
      I.of_float_prec (prec p) (round ()) i i

    | C_float_interval (lo,up) ->
      I.of_float_prec (prec p) (round ()) lo up

    | C_int_interval (lo,up) ->
      I.of_z (prec p) (round ()) lo up

    | C_int i ->
      I.of_z (prec p) (round ()) i i

    | C_bool false ->
      I.zero

    | C_bool true ->
      I.one

    | C_avalue(V_float_interval, itv) -> (itv:t)

    | C_top (T_float p) ->
      top_of_prec p

    | _ -> top_of_prec p


  let unop op t a tr =
    let p = prec_of_type tr in
    match op with
    | O_minus -> I.neg a
    | O_plus  -> a
    | O_sqrt  -> I.sqrt (prec p) (round ()) a
    | _ -> top_of_prec p


  let binop op t1 a1 t2 a2 tr =
    let p = prec_of_type tr in
    match op with
    | O_plus  -> I.add (prec p) (round ()) a1 a2
    | O_minus -> I.sub (prec p) (round ()) a1 a2
    | O_mult  -> I.mul (prec p) (round ()) a1 a2
    | O_div   -> I.div (prec p) (round ()) a1 a2
    | O_mod   -> I.fmod (prec p) (round ()) a1 a2
    | _       -> top_of_prec p

  let filter = default_filter

  let backward_unop op t a tr r =
    let p = prec_of_type tr in
    match op with
    | O_minus -> I.bwd_neg a r
    | O_plus  -> I.meet a r
    | O_sqrt  -> I.bwd_sqrt (prec p) (round ()) a r
    | _       -> a

  let backward_binop op t1 a1 t2 a2 tr r =
    let p = prec_of_type tr in
    match op with
    | O_plus  -> I.bwd_add (prec p) (round ()) a1 a2 r
    | O_minus -> I.bwd_sub (prec p) (round ()) a1 a2 r
    | O_mult  -> I.bwd_mul (prec p) (round ()) a1 a2 r
    | O_div   -> I.bwd_div (prec p) (round ()) a1 a2 r
    | O_mod   -> I.bwd_fmod (prec p) (round ()) a1 a2 r
    | _       -> default_backward_binop op t1 a1 t2 a2 tr r


  let compare op b t1 a1 t2 a2 =
    let p = prec_of_type t1 in
    match b, op with
    | true, O_eq | false, O_ne -> I.filter_eq  (prec p) a1 a2
    | true, O_ne | false, O_eq -> I.filter_neq (prec p) a1 a2
    | true, O_lt -> I.filter_lt  (prec p) a1 a2
    | true, O_le -> I.filter_leq (prec p) a1 a2
    | true, O_gt -> I.filter_gt  (prec p) a1 a2
    | true, O_ge -> I.filter_geq (prec p) a1 a2
    | false, O_le -> I.filter_leq_false (prec p) a1 a2
    | false, O_lt -> I.filter_lt_false  (prec p) a1 a2
    | false, O_ge -> I.filter_geq_false (prec p) a1 a2
    | false, O_gt -> I.filter_gt_false  (prec p) a1 a2
    | _ -> a1,a2


  let avalue : type r. r avalue_kind -> t -> r option = fun aval a ->
    match aval with
    | V_float_interval -> Some a
    | _ -> None

  
end


open Sig.Abstraction.Value
module Value =
struct

  module V = MakeValue(SimplifiedValue)

  include V

  let cast man e =
    match e.etyp with
    | T_int | T_bool ->
      let v = man.eval e in
      let int_itv = man.avalue (V_int_interval true) v in
      let float_itv = I.of_int_itv_bot (prec @@ prec_of_type e.etyp) (round ()) int_itv in
      man.set float_itv v |>
      OptionExt.return

    | _ -> None

  let eval man e =
    match ekind e with
    | E_unop(O_cast,ee) -> cast man ee
    | _ -> V.eval man e

  let backward_cast man p e ve r =
    match e.etyp with
    | T_int | T_bool ->
      let v,_ = find_vexpr e ve in
      let iitv = man.avalue (V_int_interval true) v in
      begin match iitv with
        | BOT    -> None
        | Nb itv ->
          let iitv' = ItvUtils.FloatItvNan.bwd_of_int_itv (prec p) (round ()) itv r in
          let v' = man.eval (mk_avalue_expr (V_int_interval true) iitv' e.erange) in
          refine_vexpr e (man.meet v v') ve |>
          OptionExt.return
      end
    | _ -> None

  let backward man e ve r =
    match ekind e with
    | E_unop(O_cast,ee) -> backward_cast man (prec_of_type e.etyp) ee ve (man.get r)
    | _ -> V.backward man e ve r

end


let () =
  register_value_abstraction (module Value)

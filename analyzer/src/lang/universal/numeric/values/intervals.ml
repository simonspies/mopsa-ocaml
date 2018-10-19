(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(** Interval abstraction of integer values. *)

open Framework.Essentials
open Framework.Value
open Ast
open Bot


module Value =
struct

  module I = ItvUtils.IntItv

  type v = I.t
  type t = v with_bot

  type _ Framework.Query.query +=
  | Q_interval : Framework.Ast.expr -> t Framework.Query.query

  type _ value += V_integer_interval : t value

  let id = V_integer_interval
  let name = "universal.numeric.values.intervals", "intervals"

  let identify : type a. a value -> (t, a) eq option =
    function
    | V_integer_interval -> Some Eq
    | _ -> None

  let debug fmt = Debug.debug ~channel:(fst @@ name) fmt

  let zone = Zone.Z_u_num

  let bottom = BOT

  let top = Nb (I.minf_inf)

  let is_bottom abs =
    bot_dfl1 true (fun itv -> not (I.is_valid itv)) abs

  let subset (a1:t) (a2:t) : bool = I.included_bot a1 a2

  let join annot (a1:t) (a2:t) : t = I.join_bot a1 a2

  let meet annot (a1:t) (a2:t) : t = I.meet_bot a1 a2

  let widen annot (a1:t) (a2:t) : t = I.widen_bot a1 a2

  let print fmt (a:t) = I.fprint_bot fmt a

  let of_constant = function
    | C_int i ->
      Nb (I.of_z i i)

    | C_int_interval (i1,i2) ->
      Nb (I.of_z i1 i2)

    | _ -> top

  let unop op a =
    return (
      match op with
      | O_log_not -> bot_lift1 I.log_not a
      | O_minus  -> bot_lift1 I.neg a
      | O_plus  -> a
      | O_wrap(l, u) ->
        let rep =  bot_lift1 (fun itv -> I.wrap itv l u) a in
        let () = debug "O_wrap done : %a [%a-%a] : %a" print a Z.pp_print l Z.pp_print u print rep in
        rep
      | _ -> top
    )

  let binop op a1 a2 =
    return (
      match op with
      | O_plus   -> bot_lift2 I.add a1 a2
      | O_minus  -> bot_lift2 I.sub a1 a2
      | O_mult   -> bot_lift2 I.mul a1 a2
      | O_div    -> bot_absorb2 I.div a1 a2
      | O_pow   -> bot_lift2 I.pow a1 a2
      | O_log_or   -> bot_lift2 I.log_or a1 a2
      | O_log_and  -> bot_lift2 I.log_and a1 a2
      | O_mod    -> bot_absorb2 I.rem a1 a2
      | O_bit_and -> bot_lift2 I.bit_and a1 a2
      | O_bit_or -> bot_lift2 I.bit_or a1 a2
      | O_bit_xor -> bot_lift2 I.bit_xor a1 a2
      | O_bit_rshift -> bot_absorb2 I.shift_right a1 a2
      | O_bit_lshift -> bot_absorb2 I.shift_left a1 a2
      | _     -> top
    )

  let filter a b =
    return (
      if b then bot_absorb1 I.meet_nonzero a
      else bot_absorb1 I.meet_zero a
    )

  let bwd_unop op a r =
    return (
      try
        let a, r = bot_to_exn a, bot_to_exn r in
        let aa = match op with
          | O_minus  -> bot_to_exn (I.bwd_neg a r)
          | O_wrap(l,u) -> bot_to_exn (I.bwd_wrap a (l,u) r)
          | _ ->
            let () = Debug.fail "following backward %a unary operator is not yet implemented"
                Framework.Ast.pp_operator op in
            assert false
        in
        Nb aa
      with Found_BOT ->
        bottom
    )

  let bwd_binop op a1 a2 r =
    return (
      try
        let a1, a2, r = bot_to_exn a1, bot_to_exn a2, bot_to_exn r in
        let aa1, aa2 =
          match op with
          | O_plus   -> bot_to_exn (I.bwd_add a1 a2 r)
          | O_minus  -> bot_to_exn (I.bwd_sub a1 a2 r)
          | O_mult   -> bot_to_exn (I.bwd_mul a1 a2 r)
          | O_div    -> bot_to_exn (I.bwd_div a1 a2 r)
          | O_mod    -> bot_to_exn (I.bwd_rem a1 a2 r)
          | O_pow   -> bot_to_exn (I.bwd_pow a1 a2 r)
          | O_bit_and -> bot_to_exn (I.bwd_bit_and a1 a2 r)
          | O_bit_or  -> bot_to_exn (I.bwd_bit_or a1 a2 r)
          | O_bit_xor -> bot_to_exn (I.bwd_bit_xor a1 a2 r)
          | O_bit_rshift -> bot_to_exn (I.bwd_shift_right a1 a2 r)
          | O_bit_lshift -> bot_to_exn (I.bwd_shift_left a1 a2 r)
          | _ -> Framework.Exceptions.fail "bwd_binop: unknown operator %a" Framework.Ast.pp_operator op
        in
        Nb aa1, Nb aa2
      with Found_BOT ->
        bottom, bottom
    )

  let compare op a1 a2 r =
    return (
      try
        let a1, a2 = bot_to_exn a1, bot_to_exn a2 in
        let op = if r then op else negate_comparison op in
        let aa1, aa2 =
          match op with
          | O_eq -> bot_to_exn (I.filter_eq a1 a2)
          | O_ne -> bot_to_exn (I.filter_neq a1 a2)
          | O_lt -> bot_to_exn (I.filter_lt a1 a2)
          | O_gt -> bot_to_exn (I.filter_gt a1 a2)
          | O_le -> bot_to_exn (I.filter_leq a1 a2)
          | O_ge -> bot_to_exn (I.filter_geq a1 a2)
          | _ -> Framework.Exceptions.fail "compare: unknown operator %a" pp_operator op
        in
        Nb aa1, Nb aa2
      with Found_BOT ->
        bottom, bottom
    )

  let ask : type r. r Framework.Query.query -> (expr -> t) -> r option =
    fun query eval ->
      match query with
      | Q_interval e ->
        Some (eval e)
      | _ -> None

  let z_of_z2 z z' round =
    let open Z in
    let d, r = div_rem z z' in
    if equal r zero then
      d
    else
      begin
        if round then
          d + one
        else
          d
      end

  let z_of_mpzf mp =
    Z.of_string (Mpzf.to_string mp)

  let z_of_mpqf mp round =
    let open Mpqf in
    let l, r = to_mpzf2 mp in
    let lz, rz = z_of_mpzf l, z_of_mpzf r in
    z_of_z2 lz rz round

  let z_of_apron_scalar a r =
    let open Apron.Scalar in
    match a, r with
    | Float f, true  -> Z.of_float (ceil f)
    | Float f, false -> Z.of_float (floor f)
    | Mpqf q, _ ->  z_of_mpqf q r
    | Mpfrf mpf, _ -> z_of_mpqf (Mpfr.to_mpq mpf) r

  let of_apron (itv: Apron.Interval.t) : t =
    if Apron.Interval.is_bottom itv then
      bottom
    else
      let mi = itv.Apron.Interval.inf in
      let ma = itv.Apron.Interval.sup in
      let to_b m r =
        let x = Apron.Scalar.is_infty m in
        if x = 0 then I.B.Finite (z_of_apron_scalar m r)
        else if x > 0 then I.B.PINF
        else I.B.MINF
      in
      Nb (to_b mi false, to_b ma true)

  let to_apron (itv:t) : Apron.Interval.t =
    match itv with
    | BOT -> Apron.Interval.bottom
    | Nb(a,b) ->
      let bound_to_scalar b =
        match b with
        | I.B.MINF -> Apron.Scalar.of_infty (-1)
        | I.B.PINF -> Apron.Scalar.of_infty 1
        | I.B.Finite z -> Apron.Scalar.of_float (Z.to_float z)
      in
      Apron.Interval.of_infsup (bound_to_scalar a) (bound_to_scalar b)

  let is_bounded (itv:t) : bool =
    bot_dfl1 true I.is_bounded itv

  let bounds (itv:t) : Z.t * Z.t =
    bot_dfl1 (Z.one, Z.zero) (function
        | I.B.Finite a, I.B.Finite b -> (a, b)
        | _ -> panic "bounds called on a unbounded interval %a" print itv
      ) itv

  let mem (i: Z.t) (itv:t) : bool =
    bot_dfl1 true (fun (a, b) ->
        let open I.B in
        let i = Finite i in
        geq i a && leq i b
      ) itv
end


let () =
  register_value (module Value)
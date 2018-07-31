(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(** Interval abstraction of integer values. *)

open Framework.Essentials
open Ast
open Bot

let name = "universal.numeric.values.integer_interval"
let debug fmt = Debug.debug ~channel:name fmt

module Value =
struct

  module I = Intervals.IntItv

  type v = I.t
  type t = v with_bot

  let zone = Zone.Z_universal_int

  let bottom = BOT

  let top = Nb (I.minf_inf)

  let is_bottom abs =
    bot_dfl1 true (fun itv -> not (I.is_valid itv)) abs

  let subset (a1:t) (a2:t) : bool = I.included_bot a1 a2

  let join annot (a1:t) (a2:t) : t = I.join_bot a1 a2

  let meet annot (a1:t) (a2:t) : t = I.meet_bot a1 a2

  let widen annot (a1:t) (a2:t) : t = I.widen_bot a1 a2

  let print fmt (a:t) = I.fprint_bot fmt a

  let display = "int interval"

  let of_constant = function
    | C_int i ->
      Nb (I.of_z i i)

    | C_int_interval (i1,i2) ->
      Nb (I.of_z i1 i2)

    | _ -> top

  let unop op a =
    match op with
    | O_log_not -> bot_lift1 I.log_not a
    | O_minus  -> bot_lift1 I.neg a
    | O_plus  -> a
    | O_wrap(l, u) ->
      let rep =  bot_lift1 (fun itv -> I.wrap itv l u) a in
      let () = debug "O_wrap done : %a [%a-%a] : %a" print a Z.pp_print l Z.pp_print u print rep in
      rep
    | _ -> top

  let binop op a1 a2 =
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

  let filter a b =
    if b then bot_absorb1 I.meet_nonzero a
    else bot_absorb1 I.meet_zero a

  let bwd_unop op a r =
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


  let bwd_binop op a1 a2 r =
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

  let compare op a1 a2 =
    try
      let a1, a2 = bot_to_exn a1, bot_to_exn a2 in
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

  
end


type _ Framework.Domains.Nonrel.Value.id +=
  | V_integer_interval : Value.t Framework.Domains.Nonrel.Value.id

let () =
  Framework.Domains.Nonrel.Value.(register_value {
      name;
      domain = (module Value);
      id = V_integer_interval;
      eq = (let compare : type b. b id -> (Value.t, b) eq option =
              function
              | V_integer_interval -> Some Eq
              | _ -> None
            in
            compare);
    })

(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(** Reduction operator for intervals and congruences. *)

open Framework.Essentials
open Framework.Domains.Reduced_product.Reductions
open Framework.Domains.Reduced_product.Pool
open Ast


(***************************************************************************)
(*                             First reduction                             *)
(***************************************************************************)

let name = "universal.numeric.reductions.intervals_congruences"
let debug fmt = Debug.debug ~channel:name fmt

module I = Values.Intervals.Value
module C = Values.Congruences.Value

module Reduction : Value_reduction.REDUCTION =
struct

  (* Reduce a congruence and an interval *)
  let meet_cgr_itv c i =
    match c, i with
    | Bot.BOT, _ | _, Bot.BOT -> (C.bottom, I.bottom)
    | Bot.Nb a, Bot.Nb b ->
      match CongUtils.IntCong.meet_inter a b with
      | Bot.BOT -> (C.bottom, I.bottom)
      | Bot.Nb (a', b') ->
        let c' = Bot.Nb a' and i' = Bot.Nb b' in
        debug "reduce %a and %a => result: %a and %a" I.print i C.print c I.print i' C.print c';
        (c', i')

  (* Reduction operator *)
  let reduce (man: 'a value_man) (v: 'a) : 'a with_channel =
    let c = man.get_value C.id v in
    let i = man.get_value I.id v in
    let c', i' = meet_cgr_itv c i in

    debug "reduce %a and %a => result: %a and %a" I.print i C.print c I.print i' C.print c';

    let channels = if I.subset i i' then [] else [Channels.C_interval] in

    man.set_value I.id i' v |>
    man.set_value C.id c' |>
    Value_reduction.return ~channels
end


let () =
  Value_reduction.register_reduction name (module Reduction)
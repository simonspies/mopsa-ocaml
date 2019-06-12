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

(** [Disjoint ∈ 𝒱 × 𝒱 → 𝒱] creates an exclusive disjunction of two value
    abstraction. The resulting value can be one of the argument abstractions,
    but not both of them in the same time. This is useful when variables have
    a single static type.
*)

open Ast.All
open Core
open Sig.Value.Lowlevel
open Context
open Id
open Query


module Make(V1:VALUE)(V2:VALUE) : VALUE =
struct

  (** {2 Header of the abstraction} *)
  (** ***************************** *)

  type t =
    | BOT
    | V1 of V1.t
    | V2 of V2.t
    | TOP

  include GenValueId(
    struct
      type typ = t
      let name = "framework.combiners.value.disjoint"
      let display = V1.display ^ " ⊎ " ^ V2.display
    end
    )

  let zones = V1.zones @ V2.zones

  let types = V1.types @ V2.types

  let bottom = BOT

  let top = TOP
  
  let print fmt v =
    match v with
    | BOT -> Format.pp_print_string fmt Bot.bot_string
    | TOP -> Format.pp_print_string fmt Top.top_string
    | V1 v1 -> V1.print fmt v1
    | V2 v2 -> V2.print fmt v2


  (** {2 Lattice operators} *)
  (** ********************* *)

  let is_bottom v =
    match v with
    | BOT -> true
    | TOP -> false
    | V1 v1 -> V1.is_bottom v1
    | V2 v2 -> V2.is_bottom v2

  let subset a b =
    match a,b with
    | V1 x, V1 y -> V1.subset x y
    | V2 x, V2 y -> V2.subset x y
    | BOT,_ | _,TOP -> true
    | _ -> false

  let join a b =
    match a,b with
    | V1 x, V1 y -> V1 (V1.join x y)
    | V2 x, V2 y -> V2 (V2.join x y)
    | BOT,x | x,BOT -> x
    | _ -> TOP

  let meet a b =
    match a,b with
    | V1 x, V1 y -> V1 (V1.meet x y)
    | V2 x, V2 y -> V2 (V2.meet x y)
    | TOP,x | x,TOP -> x
    | BOT,_ | _,BOT -> BOT
    | _ -> TOP

  let widen a b =
    match a,b with
    | V1 x, V1 y -> V1 (V1.widen x y)
    | V2 x, V2 y -> V2 (V2.widen x y)
    | BOT,x | x,BOT -> x
    | _ -> TOP


  (** {2 Value managers} *)
  (** ****************** *)

  let v1_man (man:('a,t) man) : ('a,V1.t) man = {
    man with
    get = (fun v ->
        match man.get v with
        | BOT -> V1.bottom
        | TOP -> V1.top
        | V1 v1 -> v1
        | V2 _ -> V1.bottom
      );
    set = (fun v1 v -> man.set (V1 v1) v);
  }

  let v2_man (man:('a,t) man) : ('a,V2.t) man = {
    man with
    get = (fun v ->
        match man.get v with
        | BOT -> V2.bottom
        | TOP -> V2.top
        | V1 _ -> V2.bottom
        | V2 v2 -> v2
      );
    set = (fun v2 v -> man.set (V2 v2) v);
  }

  let get man id a =
    match V1.get (v1_man man) id a with
    | Some v -> Some v
    | None -> V2.get (v2_man man) id a

  let set man id v a =
    match V1.set (v1_man man) id v a with
    | Some v -> Some v
    | None -> V2.set (v2_man man) id v a



  (** {2 Forward semantics} *)
  (** ********************* *)

  let is_v1_type t =
    List.exists (fun t' -> compare_typ t t' = 0) V1.types

  let is_v2_type t =
    List.exists (fun t' -> compare_typ t t' = 0) V2.types

  let of_constant t c =
    if is_v1_type t then
      V1 (V1.of_constant t c)
    else if is_v2_type t then
      V2 (V2.of_constant t c)
    else
      Exceptions.panic "of_constant called on unsupported constant %a of type %a"
        ~loc:__LOC__
        pp_constant c
        pp_typ t

  let unop man t op a =
    if is_v1_type t then
      V1 (V1.unop (v1_man man) t op a)
    else if is_v2_type t then
      V2 (V2.unop (v2_man man) t op a)
    else
      Exceptions.panic "unop called on unsupported operator %a of type %a"
        ~loc:__LOC__
        pp_operator op
        pp_typ t

  let binop man t op a b =
    if is_v1_type t then
      V1 (V1.binop (v1_man man) t op a b)
    else if is_v2_type t then
      V2 (V2.binop (v2_man man) t op a b)
    else
      Exceptions.panic "binop called on unsupported operator %a of type %a"
        ~loc:__LOC__
        pp_operator op
        pp_typ t

  let filter man a b =
    match man.get a with
    | BOT -> BOT
    | TOP -> TOP
    | V1 _ -> V1 (V1.filter (v1_man man) a b)
    | V2 _ -> V2 (V2.filter (v2_man man) a b)


  (** {2 Backward semantics} *)
  (** ********************** *)

  let bwd_unop man t op a r =
    if is_v1_type t then
      V1 (V1.bwd_unop (v1_man man) t op a r)
    else if is_v2_type t then
      V2 (V2.bwd_unop (v2_man man) t op a r)
    else
      Exceptions.panic "bwd_unop called on unsupported operator %a of type %a"
        ~loc:__LOC__
        pp_operator op
        pp_typ t

  let bwd_binop man t op a b r =
    if is_v1_type t then
      let a',b' = V1.bwd_binop (v1_man man) t op a b r in
      V1 a', V1 b'
    else if is_v2_type t then
      let a',b' = V2.bwd_binop (v2_man man) t op a b r in
      V2 a', V2 b'
    else
      Exceptions.panic "bwd_binop called on unsupported operator %a of type %a"
        ~loc:__LOC__
        pp_operator op
        pp_typ t

  let compare man t op a b r =
    match man.get a, man.get b with
    | V1 _, V2 _ | V2 _, V1 _ ->
      Exceptions.panic "compare called on unsupported arguments %a and %a"
        ~loc:__LOC__
        print (man.get a)
        print (man.get b)

    | BOT, _ | _, BOT -> BOT, BOT

    | TOP, TOP -> TOP, TOP

    | V1 _, _ | _, V1 _ ->
      let a',b' = V1.compare (v1_man man) t op a b r in
      V1 a', V1 b'
    | V2 _, _ | _, V2 _ ->
      let a',b' = V2.compare (v2_man man) t op a b r in
      V2 a', V2 b'


  (** {2 Evaluation query} *)
  (** ******************** *)

  let ask man q =
    let a = V1.ask (v1_man man) q in
    let b = V2.ask (v2_man man) q in
    Option.neutral2 (join_query q) a b


  (** {2 Reduction refiner} *)
  (** ********************* *)

  let refine man channel v =
    V1.refine (v1_man man) channel v |>
    Core.Channel.bind @@ V2.refine (v2_man man) channel



end
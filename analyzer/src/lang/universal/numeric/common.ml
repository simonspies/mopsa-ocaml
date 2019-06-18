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

(** Common constructs for numeric abstractions. *)

open Mopsa

module I = ItvUtils.IntItv
module C = CongUtils.IntCong

(** {2 Integer intervals} *)
(** ********************* *)

(** Integer intervals *)
type int_itv = I.t_with_bot


(** Query to evaluate the integer interval of an expression *)
type _ query += Q_int_interval : expr -> int_itv query


let () =
  register_query {
    join = (
      let f : type r. query_pool -> r query -> r -> r -> r =
        fun next query a b ->
          match query with

          | Q_int_interval e -> I.join_bot a b

          | _ -> next.join_query query a b
      in
      f
    );
    meet = (
      let f : type r. query_pool -> r query -> r -> r -> r =
        fun next query a b ->
          match query with

          | Q_int_interval e -> I.meet_bot a b

          | _ -> next.meet_query query a b
      in
      f
    );
  }



(** {2 Integer intervals with congruence} *)
(** ************************************* *)

(** Integer step intervals *)
type int_congr_itv = int_itv * C.t


(** Query to evaluate the integer interval of an expression *)
type _ query += Q_int_congr_interval : expr -> int_congr_itv query


let () =
  register_query {
    join = (
      let f : type r. query_pool -> r query -> r -> r -> r =
        fun next query a b ->
          match query with

          | Q_int_congr_interval e ->
            let (i1,c1), (i2,c2) = a, b in
            (I.join_bot i1 i2, C.join c1 c2)

          | _ -> next.join_query query a b
      in
      f
    );
    meet = (
      let f : type r. query_pool -> r query -> r -> r -> r =
        fun next query a b ->
          match query with

          | Q_int_congr_interval e ->
            let (i1,c1), (i2,c2) = a, b in
            let i = I.meet_bot i1 i2 in
            let c = C.meet c1 c2 in
            Bot.bot_absorb2 C.meet_inter c i |>
            Bot.bot_dfl1
              (Bot.BOT, C.minf_inf)
              (fun (c,i) -> (Bot.Nb i, c))

          | _ -> next.meet_query query a b
      in
      f
    );
  }
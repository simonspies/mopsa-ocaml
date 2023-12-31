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

(** Reduction rules for abstract evaluations *)

open Core.All


(** Manager used by reduction rules *)
type 'a eval_reduction_man = {
  get_man : 't. 't id -> ('a, 't) man; (** Get the manger of a domain *)
}


module type EVAL_REDUCTION =
sig
  val name   : string
  (** Name of the reduction rule *)

  val reduce : expr -> ('a,'b) man -> 'a eval_reduction_man -> 'a flow -> expr list -> 'a flow -> 'a eval option
  (** [reduce e results man input_flow output_flow] reduces a product evaluation *)
end


(** {2 Registration} *)
(** **************** *)

(** Registered eval reductions *)
let eval_reductions : (module EVAL_REDUCTION) list ref = ref []


(** Register a new eval reduction *)
let register_eval_reduction rule =
  eval_reductions := rule :: !eval_reductions

(** Find an eval reduction by its name *)
let find_eval_reduction name =
  List.find (fun v ->
      let module V = (val v : EVAL_REDUCTION) in
      compare V.name name = 0
    ) !eval_reductions

let eval_reductions () =
  List.map (fun v ->
      let module D = (val v : EVAL_REDUCTION) in
      D.name
    ) !eval_reductions

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

(** Pool of state and value abstractions *)

open Manager
open Domain
open Value
open Ast

(** {2 Pool of abstract domains} *)
(** **************************** *)

type 'a domain_pool =
  | Nil : unit domain_pool
  | Cons : (module Stacked.S with type t = 'a) * 'b domain_pool -> ('a * 'b) domain_pool

(** Product evaluations.
    Reduction operators do not process the whole
    product of all evaluations.
    Instead, the product is first written as a DNF, and reduction operators are 
    applied on each sub-conjunction individually. 
*)
type 'a evl_conj = ('a, expr) evl_case option list

(** Transform a conjunction into an evaluation *)
let conj_to_evl (c: 'a evl_conj) : ('a, expr) evl option =
  match List.partition (function None -> true | _ -> false) c with
  | _, [] -> None
  | _, l ->
    Some (
      List.map (function Some c -> Eval.case c | None -> assert false) l |>
      Eval.meet_list
    )

type 'a fold_fun = {
  doit : 't. 't domain -> 'a -> 'a
}

(** Manager of a pool of abstract domains *)
type ('a, 'd) domain_man = {
  (** Domains in the pool *)
  pool : 'd domain_pool;

  (** Get the abstract element of a member domain *)
  get_env : 't. 't domain -> 'a -> 't;

  (** Set the abstract element of a member domain *)
  set_env : 't. 't domain -> 't -> 'a -> 'a;

  (** Fold over the pool by applying the given function *)
  fold : 'b. 'b fold_fun -> 'b -> 'b;

  (** Get the evaluation of a member domain *)
  get_eval : 't. 't domain -> 'a evl_conj -> (expr option * 'a flow) option;

  (** Change the evaluation of a member domain *)
  set_eval : 't. 't domain -> expr -> 'a flow -> 'a evl_conj -> 'a evl_conj;

  (** Remove the evaluation of a member domains *)
  remove_eval : 't. 't domain -> 'a evl_conj -> 'a evl_conj;
}


(** {2 Pool of abstract values} *)
(** *************************** *)

type 'a value_pool =
  | Nil : unit value_pool
  | Cons : (module VALUE with type t = 'a) * 'b value_pool -> ('a * 'b) value_pool


(** Value manager, used by value reduction rules *)
type 'v value_man = {
  pool : 'v value_pool;
  get_value  : 't. 't value -> 'v -> 't;
  set_value  : 't. 't value -> 't -> 'v -> 'v;
}

(** Non-relational manager allows members of a domain pool to access
    abstract elements of a member non-relational abstract domains *)
type ('a, 'v) nonrel_man = {
  pool : 'v value_pool;
  get_var_value : 't. 't value -> var -> 'a -> 't;
  set_var_value : 't. 't value -> var -> 't -> 'a -> 'a;
}


(** {2 Mixed pool} *)
(** ************** *)

type (_, _) pool = Pool : 'd domain_pool * 'v value_pool -> ('d, 'v) pool

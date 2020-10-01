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

(** Signature of a value abstraction. *)

open Core.All


(*==========================================================================*)
(**                          {2 Value manager}                              *)
(*==========================================================================*)

type ('a,'v,'t) value_man = {
  get  : 'v -> 't;
  set  : 't -> 'v -> 'v;
  eval : expr -> 'v;
  ask  : 'r. ('a,'r) query -> 'r;
  refine : hint -> 'v -> 'v;
}

(*==========================================================================*)
(**                          {2 Value domain}                               *)
(*==========================================================================*)


module type VALUE =
sig

  (** {2 Header of the abstraction} *)
  (** ***************************** *)

  type t
  (** Type of the abstract value. *)

  val id : t id
  (** Identifier of the value domain *)

  val accept_type : typ -> bool
  (** Predicate of types abstracted by the value domain *)

  val name : string
  (** Name of the value domain *)

  val display : string
  (** Display name used in debug messages *)

  val bottom: t
  (** Least abstract element of the lattice. *)

  val top: t
  (** Greatest abstract element of the lattice. *)


  (** {2 Lattice operators} *)
  (** ********************* *)

  val is_bottom: t -> bool
  (** [is_bottom a] tests whether [a] is bottom or not. *)

  val subset: t -> t -> bool
  (** Partial order relation. [subset a1 a2] tests whether [a1] is
      related to (or included in) [a2]. *)

  val join: t -> t -> t
  (** [join a1 a2] computes an upper bound of [a1] and [a2]. *)

  val meet: t -> t -> t
  (** [meet a1 a2] computes a lower bound of [a1] and [a2]. *)

  val widen: 'a ctx -> t -> t -> t
  (** [widen ctx a1 a2] computes an upper bound of [a1] and [a2] that
      ensures stabilization of ascending chains. *)


  (** {2 Forward semantics} *)
  (** ********************* *)

  val filter : typ -> bool -> t -> t
  (** Keep values that may represent the argument truth value *)

  val constant : typ -> constant -> t
  (** Forward evaluation of constants *)

  val unop : typ -> operator -> t -> t
  (** Forward evaluation of unary expressions *)

  val binop : typ -> operator -> t -> t -> t
  (** Forward evaluation of binary expressions *)

  val het_unop : ('a,'v,t) value_man -> typ -> operator -> ('v*expr) -> t
  (** Forward evaluation of heterogenous unary expressions *)

  val het_binop : ('a,'v,t) value_man -> typ -> operator -> ('v*expr) -> ('v*expr) -> t
  (** Forward evaluation of heterogenous binary expressions *)


  (** {2 Backward semantics} *)
  (** ********************** *)

  val bwd_unop : typ -> operator -> t -> t -> t
  (** Backward evaluation of unary operators.
      [bwd_unop man op x r] returns x':
       - x' abstracts the set of v in x such as op v is in r
       i.e., we fiter the abstract values x knowing the result r of applying
       the operation on x
     *)

  val bwd_binop : typ -> operator -> t -> t -> t -> (t * t)
  (** Backward evaluation of binary operators.
      [bwd_binop man op x y r] returns (x',y') where
      - x' abstracts the set of v  in x such that v op v' is in r for some v' in y
      - y' abstracts the set of v' in y such that v op v' is in r for some v  in x
      i.e., we filter the abstract values x and y knowing that, after
      applying the operation op, the result is in r
  *)

  val predicate : typ -> operator -> bool -> t -> t
  (** Backward evaluation of unary boolean predicates.
      [predicate man op x true] returns the subset of x such that x is
      true.
      [predicate man op x false] is similar, but assumes that the predicate is false
  *)

  val compare : typ -> operator -> bool -> t -> t -> (t * t)
  (** Backward evaluation of boolean comparisons. [compare op true x y] returns (x',y') where:
       - x' abstracts the set of v  in x such that v op v' is true for some v' in y
       - y' abstracts the set of v' in y such that v op v' is true for some v  in x
       i.e., we filter the abstract values x and y knowing that the test is true

      [compare op x y false] is similar, but assumes that the test is false
  *)

  val bwd_het_unop : ('a,'v,t) value_man -> typ -> operator -> ('v*expr) -> t -> 'v

  val bwd_het_binop : ('a,'v,t) value_man -> typ -> operator -> ('v*expr) -> ('v*expr) -> t -> ('v * 'v)


  (** {2 Communication handlers } *)
  (** *************************** *)

  val ask : ('a,'v,t) value_man -> ('a,'r) query -> 'r option
  (** Query handler *)

  val refine : hint -> t -> t option
  (** Refinement handler *)


  (** {2 Pretty printer} *)
  (** ****************** *)

  val print: printer -> t -> unit
  (** Printer of an abstract element. *)

end


let default_bwd_unop t op v r = v
let default_bwd_binop t op v1 v2 r = (v1,v2)
let default_bwd_het_unop man t op (a,e) r = a
let default_bwd_het_binop man t op (a1,e1) (a2,e2) r = (a1,a2)
let default_predicate t op b v = v
let default_compare t op b v1 v2 = (v1,v2)


(*==========================================================================*)
(**                          {2 Registration}                               *)
(*==========================================================================*)

let values : (module VALUE) list ref = ref []

let register_value_abstraction dom =
  values := dom :: !values

let find_value_abstraction name =
  List.find (fun dom ->
      let module D = (val dom : VALUE) in
      compare D.name name = 0
    ) !values

let mem_value_abstraction name =
  List.exists (fun dom ->
      let module D = (val dom : VALUE) in
      compare D.name name = 0
    ) !values

let value_abstraction_names () =
  List.map (fun dom ->
      let module D = (val dom : VALUE) in
      D.name
    ) !values

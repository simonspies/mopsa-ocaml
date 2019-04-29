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

(** Stateless stacks are domains without an abstract element (e.g., iterators).
    Only transfer functions need to be defined.
*)

open Ast.All
open Interface
open Id
open Lattice
open Zone
open Flow
open Post
open Eval
open Log


(*==========================================================================*)
(**                         {2 Stack managers}                              *)
(*==========================================================================*)

(** Managers provide access to full analyzer and the sub-tree
    abstraction of the stack domain.
*)
type ('a, 't, 's) man = ('a,'t,'s) Intermediate.man = {
  (* Lattice operators over global abstract elements ['a] *)
  lattice : 'a lattice;

  (* Accessors to the domain's abstract element ['t] within ['a] *)
  get : 'a -> 't;
  set : 't -> 'a -> 'a;

  (* Accessors to the sub-tree abstract element ['s] within ['a] *)
  get_sub : 'a -> 's;
  set_sub : 's -> 'a -> 'a;

  (** Analyzer transfer functions *)
  post : ?zone:zone -> stmt -> 'a flow -> 'a post;
  exec : ?zone:zone -> stmt -> 'a flow -> 'a flow;
  exec_sub : ?zone:zone -> stmt -> 'a flow -> 'a post;
  eval : ?zone:(zone * zone) -> ?via:zone -> expr -> 'a flow -> (expr, 'a) eval;
  ask : 'r. 'r Query.query -> 'a flow -> 'r;

  (** Accessors to the domain's merge logs *)
  get_log : log -> log;
  set_log : log -> log -> log;

  (** Accessors to the sub-tree merge logs *)
  get_sub_log : log -> log;
  set_sub_log : log -> log -> log;

  (** Sub-tree merger *)
  merge_sub : 's -> 's * log -> 's * log -> 's;
}


(*==========================================================================*)
(**                         {2 Stack signature}                             *)
(*==========================================================================*)

module type STACK =
sig

  (** {2 Domain header} *)
  (** ***************** *)

  val name : string
  (** Name of the domain *)

  val interface : interface
  (** Zoning interface *)


  (** {2 Transfer functions} *)
  (** ********************** *)
  val init : program -> ('a, unit,'s) man -> 'a flow -> 'a flow
  (** Initialization routine *)

  val exec : zone -> stmt -> ('a, unit,'s) man -> 'a flow -> 'a post option
  (** Computation of post-conditions *)

  val eval : zone * zone -> expr -> ('a, unit,'s) man -> 'a flow -> (expr, 'a) eval option
  (** Evaluation of expressions *)

  val ask  : 'r Query.query -> ('a, unit,'s) man -> 'a flow -> 'r option
  (** Handler of queries *)

end

(** Create a full stack from a stateless domain. *)
module MakeIntermediate(S: STACK) : Intermediate.STACK with type t = unit =
struct

  type t = unit
  let bottom = ()
  let top = ()
  let is_bottom _ = false
  let merge _ _ _ = ()
  let print _ _ = ()

  include GenDomainId(struct
      type typ = unit
      let name = S.name
    end)

  let interface = S.interface


  let subset _ ((),s) ((),s') = true,s,s'
  let join _ ((),s) ((),s') = (),s,s'
  let meet _ ((),s) ((),s') = (),s,s'
  let widen _ _ ((),s) ((),s') = (),s,s',true

  let init = S.init
  let exec = S.exec
  let eval = S.eval
  let ask = S.ask
  let refine channel man flow = Channel.return flow

end


(*==========================================================================*)
(**                          {2 Registration}                               *)
(*==========================================================================*)


let stacks : (module STACK) list ref = ref []

let register_stack dom =
  stacks := dom :: !stacks

let find_stack name =
  List.find (fun dom ->
      let module S = (val dom : STACK) in
      compare S.name name = 0
    ) !stacks

let mem_stack name =
  List.exists (fun dom ->
      let module S = (val dom : STACK) in
      compare S.name name = 0
    ) !stacks

let names () =
  List.map (fun dom ->
      let module S = (val dom : STACK) in
      S.name
    ) !stacks


(*==========================================================================*)
(**                        {2 Utility functions}                            *)
(*==========================================================================*)

let assume = Intermediate.assume

let assume_eval = Intermediate.assume_eval

let assume_post = Intermediate.assume_post

let switch = Intermediate.switch

let switch_eval = Intermediate.switch_eval

let switch_post = Intermediate.switch_post

let exec_eval = Intermediate.exec_eval

let post_eval = Intermediate.post_eval

let post_eval_with_cleaners = Intermediate.post_eval_with_cleaners

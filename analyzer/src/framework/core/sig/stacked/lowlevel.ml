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

(** Low level signature of stacked domains. Similar to the general-purpose
    stacked domain signature, except that lattice operators are defined on
    the global abstraction.
*)


open Ast
open Program
open Expr
open Stmt
open Context
open Token
open Flow
open Lattice
open Eval
open Log
open Post
open Zone
open Id
open Interface
open Channel




(*==========================================================================*)
(**                         {2 Stack managers}                              *)
(*==========================================================================*)

(** Managers provide access to full analyzer and the sub-tree
    abstraction of the stack domain.
*)
type ('a, 't, 's) man = ('a, 't, 's) Manager.man = {
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


(** Low level signature of stacked abstract domains *)
module type STACK =
sig

  (** {2 Domain header} *)
  (** ***************** *)

  type t
  (** Type of an abstract elements. *)

  val id : t domain
  (** Domain identifier *)

  val name : string
  (** Name of the domain *)

  val interface : interface
  (** Interface of the domain *)

  val bottom: t
  (** Least abstract element of the lattice. *)

  val top: t
  (** Greatest abstract element of the lattice. *)

  val is_bottom: t -> bool
  (** [is_bottom a] tests whether [a] is bottom or not. *)

  val print: Format.formatter -> t -> unit
  (** Printer of an abstract element. *)


  (** {2 Lattice operators} *)
  (** ********************* *)

  val subset: ('a,t,'s) man -> uctx -> 'a -> 'a -> bool * 'a * 'a

  val join: ('a,t,'s) man -> uctx -> 'a -> 'a -> t * 'a * 'a

  val meet: ('a,t,'s) man -> uctx -> 'a -> 'a -> t * 'a * 'a

  val widen: ('a,t,'s) man -> uctx -> 'a -> 'a -> t * 'a * 'a * bool

  val merge: t -> t * log -> t * log -> t
  (** [merge pre (post1, log1) (post2, log2)] synchronizes two divergent
      post-conditions [post1] and [post2] using a common pre-condition [pre].

      Diverging post-conditions emerge after a fork-join trajectory in the
      abstraction DAG (e.g., a reduced product).

      The logs [log1] and [log2] represent a journal of internal statements
      executed during the the computation of the post-conditions over the
      two trajectories.
  *)


  (** {2 Transfer functions} *)
  (** ********************** *)

  val init : program -> ('a, t, 's) man -> 'a flow -> 'a flow
  (** Initialization function *)

  val exec : zone -> stmt -> ('a, t, 's) man -> 'a flow -> 'a post option
  (** Post-state of statements *)

  val eval : (zone * zone) -> expr -> ('a, t, 's) man -> 'a flow -> (expr, 'a) eval option
  (** Evaluation of expressions *)

  val ask  : 'r Query.query -> ('a, t, 's) man -> 'a flow -> 'r option
  (** Handler of queries *)

  val refine : channel -> ('a, t, 's) man -> 'a flow -> 'a flow with_channel
  (** Refinement using reduction channel *)

end






(*==========================================================================*)
(**                        {2 Utility functions}                            *)
(*==========================================================================*)


let set_domain_env = Manager.set_domain_env

let set_sub_env = Manager.set_sub_env

let get_domain_env = Manager.get_domain_env

let get_sub_env = Manager.get_sub_env

let map_domain_env = Manager.map_domain_env

let map_sub_env = Manager.map_sub_env

let mem_domain_env = Manager.mem_domain_env

let mem_sub_env = Manager.mem_sub_env

let assume = Manager.assume

let assume_eval = Manager.assume_eval

let assume_post = Manager.assume_post

let switch = Manager.switch

let switch_eval = Manager.switch_eval

let switch_post = Manager.switch_post

let exec_eval = Manager.exec_eval

let post_eval = Manager.post_eval

let post_eval_with_cleaners = Manager.post_eval_with_cleaners

let exec_stmt_on_all_flows = Manager.exec_stmt_on_all_flows

let exec_block_on_all_flows = Manager.exec_block_on_all_flows

let log_post_stmt = Manager.log_post_stmt

let log_post_sub_stmt = Manager.log_post_sub_stmt



(*==========================================================================*)
(**                          {2 Registration}                               *)
(*==========================================================================*)


(** Auto-logger lifter used when registering a domain *)
module AutoLogger(S:STACK) : STACK with type t = S.t =
struct
  include S
  let exec zone stmt man flow =
    S.exec zone stmt man flow |>
    Option.lift @@ log_post_stmt stmt man
end


let stacks : (module STACK) list ref = ref []

let register_stack dom =
  let module S = (val dom : STACK) in
  stacks := (module AutoLogger(S)) :: !stacks

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
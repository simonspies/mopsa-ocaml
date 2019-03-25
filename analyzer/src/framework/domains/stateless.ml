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

(** Stateless domains are domains without a lattice structure. Only
    transfer functions are defined. *)

open Ast.All
open Core.All

(***********************************************************************)
(**                      {2 Stateless domains}                         *)
(***********************************************************************)

module type DOMAIN =
sig

  val name : string
  val exec_interface : zone interface
  val eval_interface : (zone * zone) interface
  val init : program -> ('a, unit) man -> 'a flow -> 'a flow option
  val exec : zone -> stmt -> ('a, unit) man -> 'a flow -> 'a post option
  val eval : zone * zone -> expr -> ('a, unit) man -> 'a flow -> (expr, 'a) eval option
  val ask  : 'r Query.query -> ('a, unit) man -> 'a flow -> 'r option

end

(** Create a full domain from a stateless domain. *)
module MakeDomain(D: DOMAIN) : Core.Sig.Domain.DOMAIN =
struct

  type t = unit
  let bottom = ()
  let top = ()
  let is_bottom _ = false
  let subset _ _ = true
  let join _ _ = top
  let meet _ _ = top
  let widen _ _ _ = top
  let merge _ _ _ = top
  let print _ _ = ()

  include GenDomainId(struct
      type typ = unit
      let name = D.name
    end)

  let init = D.init

  let exec_interface = D.exec_interface
  let eval_interface = D.eval_interface

  let exec = D.exec
  let eval = D.eval
  let ask = D.ask

end

let register_domain modl =
  let module M = (val modl : DOMAIN) in
  let module D = MakeDomain(M) in
  Core.Sig.Domain.register_domain (module D)



(***********************************************************************)
(**                      {2 Stateless stacks}                          *)
(***********************************************************************)

module type STACK =
sig

  val name : string
  val exec_interface : zone interface
  val eval_interface : (zone * zone) interface
  val init : program -> ('a, unit) man -> 'a flow -> 'a flow option
  val exec : zone -> stmt -> ('a, unit) man -> ('a,unit,'s) stack_man -> 'a flow -> 'a post option
  val eval : zone * zone -> expr -> ('a, unit) man -> ('a,unit,'s) stack_man -> 'a flow -> (expr, 'a) eval option
  val ask  : 'r Query.query -> ('a, unit) man -> 'a flow -> 'r option

end

(** Create a full stack from a stateless domain. *)
module MakeStack(S: STACK) : Core.Sig.Stacked.STACK =
struct

  type t = unit
  let bottom = ()
  let top = ()
  let is_bottom _ = false
  let subset ((),s) ((),s') _ = true,s,s'
  let join ((),s) ((),s') _ = (),s,s'
  let meet ((),s) ((),s') _ = (),s,s'
  let widen _ ((),s) ((),s') _ = (),true,s,s'
  let merge _ _ _ = ()
  let print _ _ = ()

  include GenDomainId(struct
      type typ = unit
      let name = S.name
    end)

  let init = S.init

  let exec_interface = S.exec_interface
  let eval_interface = S.eval_interface

  let exec = S.exec
  let eval = S.eval
  let ask = S.ask

end

let register_stack modl =
  let module M = (val modl : STACK) in
  let module S = MakeStack(M) in
  Core.Sig.Stacked.register_stack_domain (module S)

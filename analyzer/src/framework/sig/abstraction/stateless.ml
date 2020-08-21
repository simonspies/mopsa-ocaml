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
open Core.All


module type STATELESS =
sig

  (** {2 Domain header} *)
  (** ***************** *)

  val name : string
  (** Name of the domain *)

  val id : unit id
  (** Identifier of the domain *)

  val interface : interface
  (** Zoning interface *)

  val alarms : alarm_class list
  (** List of alarms detected by the domain *)


  (** {2 Transfer functions} *)
  (** ********************** *)
  val init : program -> ('a, unit, 's) man -> 'a flow -> 'a flow
  (** Initialization routine *)

  val exec : zone -> stmt -> ('a, unit, 's) man -> 'a flow -> 'a post option
  (** Computation of post-conditions *)

  val eval : zone * zone -> expr -> ('a, unit, 's) man -> 'a flow -> 'a eval option
  (** Evaluation of expressions *)

  val ask  : 'r query -> ('a, unit, 's) man -> 'a flow -> 'r option
  (** Handler of queries *)

end

module MakeDomain(S: STATELESS) : Domain.DOMAIN with type t = unit =
struct

  type t = unit
  let name = S.name
  let id = S.id
  let bottom = ()
  let top = ()
  let is_bottom () = false
  let merge _ _ _ = ()
  let print _ _ = ()

  let interface = S.interface
  let alarms = S.alarms

  let subset () () = true
  let join () () = ()
  let meet () () = ()
  let widen _ () () = ()

  let init = S.init
  let exec = S.exec
  let eval = S.eval
  let ask = S.ask

end


(*==========================================================================*)
(**                          {2 Registration}                               *)
(*==========================================================================*)


let domains : (module STATELESS) list ref = ref []

let register_stateless_domain dom =
  domains := dom :: !domains

let find_stateless_domain name =
  List.find (fun dom ->
      let module S = (val dom : STATELESS) in
      compare S.name name = 0
    ) !domains

let mem_stateless_domain name =
  List.exists (fun dom ->
      let module S = (val dom : STATELESS) in
      compare S.name name = 0
    ) !domains

let stateless_domain_names () =
  List.map (fun dom ->
      let module S = (val dom : STATELESS) in
      S.name
    ) !domains
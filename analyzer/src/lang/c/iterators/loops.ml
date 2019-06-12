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

(** Interpreter of for and do-while loops. *)

open Mopsa
open Framework.Core.Sig.Domain.Stateless
open Ast
open Zone

(** {2 Domain definition} *)
(** ===================== *)

module Domain =
struct

  (** Domain identification *)
  (** ===================== *)

  include GenStatelessDomainId(struct
      let name = "c.iterators.loops"
    end)

  (** Zoning definition *)
  (** ================= *)

  let interface = {
    iexec = {provides = [Z_c]; uses = []};
    ieval = {provides = []; uses = []};
  }

  (** Initialization *)
  (** ============== *)

  let init _ _ flow = flow


  let exec zone stmt man flow =
    match skind stmt with
    | S_c_for(init, cond, incr, body) ->
      let range = stmt.srange in
      let stmt = Universal.Ast.(
          mk_block [
            init;
            mk_stmt (S_while (
                (match cond with None -> mk_one range | Some e -> e),
                (match incr with None -> body | Some e -> mk_block [body; mk_stmt (S_expression e) e.erange] body.srange)
              )) range
          ] range
        )
      in
      man.exec stmt flow |> Post.return |> Option.return

    | S_c_do_while(body, cond) ->
      let range = stmt.srange in
      let stmt = Universal.Ast.(
          mk_block [
            body;
            mk_stmt (S_while (cond, body)) range
          ] range
        )
      in
      man.exec stmt flow |> Post.return |> Option.return

    | _ -> None

  let eval _ _ _ _  = None

  let ask _ _ _  = None

end

let () =
  Framework.Core.Sig.Domain.Stateless.register_domain (module Domain)
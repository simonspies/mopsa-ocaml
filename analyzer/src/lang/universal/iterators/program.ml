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

(** Main handler of Universal programs. *)

open Mopsa
open Ast
open Zone

module Domain =
struct

  type _ domain += D_universal_program : unit domain

  let id = D_universal_program
  let name = "universal.iterators.program"
  let identify : type a. a domain -> (unit, a) eq option =
    function
    | D_universal_program -> Some Eq
    | _ -> None

  let debug fmt = Debug.debug ~channel:name fmt

  let exec_interface = {export = [Z_u]; import = []}
  let eval_interface = {export = []; import = []}

  let init prog man flow = None

  let exec zone stmt man flow =
    match skind stmt with
    | S_program { prog_kind = P_universal{universal_main} } ->
      Some (
        man.exec universal_main flow |>
        Post.of_flow
      )

    | _ -> None

  let eval zone exp man flow = None

  let ask query man flow = None

end

let () =
  Framework.Domains.Stateless.register_domain (module Domain)

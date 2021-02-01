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


(** Evaluation of compiler's builtin functions *)


open Mopsa
open Sig.Abstraction.Stateless
open Universal.Ast
open Ast


module Domain =
struct


  (** Domain identification *)
  (** ===================== *)

  include GenStatelessDomainId(struct
      let name = "c.libs.compiler"
    end)

  let checks = []
  
  (** {2 Transfer functions} *)
  (** ====================== *)

  let init _ _ flow =  flow

  let exec stmt man flow = None


  (** {2 Evaluation entry point} *)
  (** ========================== *)

  let eval exp man flow =
    match ekind exp with

    (* 𝔼⟦ __builtin_constant_p(e) ⟧ *)
    | E_c_builtin_call("__builtin_constant_p", [e]) ->

      (* __builtin_constant_ determines if [e] is known 
         to be constant at compile time *)
      let ret =
        match remove_casts e |> ekind with
        | E_constant _ -> mk_one exp.erange
        | _ -> mk_z_interval Z.zero Z.one exp.erange
      in
      Eval.singleton ret flow |>
      OptionExt.return

    | E_c_builtin_call("__builtin_expect", [e;v]) ->
      man.eval e flow |>
      OptionExt.return


    | _ -> None

  let ask _ _ _  = None

  let print_expr _ _ _ _ = ()

end

let () =
  register_stateless_domain (module Domain)
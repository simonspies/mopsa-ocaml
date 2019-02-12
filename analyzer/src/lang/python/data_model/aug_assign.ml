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

(** Python data model for augmented assignments. *)


open Mopsa
open Ast
open Addr
open Operators
open Universal.Ast

module Domain = struct

  type _ domain += D_python_data_model_aug_assign : unit domain

  let id = D_python_data_model_aug_assign
  let name = "python.data_model.aug_assign"
  let identify : type a. a domain -> (unit, a) eq option = function
    | D_python_data_model_aug_assign -> Some Eq
    | _ -> None

  let debug fmt = Debug.debug ~channel:name fmt

  let exec_interface = {export = [Zone.Z_py]; import = []}
  let eval_interface = {export = []; import = []}

  let init _ _ flow = Some flow
  let eval _ _ _ _ = None


  let exec zs stmt man flow =
    let range = srange stmt in
    match skind stmt with
    | S_py_aug_assign(x, op, e) ->
       let x0 = x in
       Eval.eval_list [e; x] (man.eval  ~zone:(Zone.Z_py, Zone.Z_py_obj)) flow |>
         Post.bind man (fun el flow ->
             let e, x = match el with [e; x] -> e, x | _ -> assert false in

             let op_fun = Operators.binop_to_incr_fun op in
             man.eval  ~zone:(Zone.Z_py, Zone.Z_py_obj)  (mk_py_type x range) flow |>
               Post.bind man (fun cls flow ->
                   let cls = object_of_expr cls in
                   Post.assume
                     (Utils.mk_object_hasattr cls op_fun range)
                     man
                     ~fthen:(fun true_flow ->
                       let stmt = mk_assign x0 (mk_py_call (mk_py_object_attr cls op_fun range) [x; e] range) range in
                       man.exec stmt true_flow |> Post.of_flow
                     )
                     ~felse:(fun false_flow ->
                       debug "Fallback on default assignment@\n";
                       let default_assign = mk_assign x0 (mk_binop x op e range) range in
                       man.exec default_assign flow |> Post.of_flow
                     )
                     flow
                 )
           )
       |> OptionExt.return

    | _ -> None

  let ask _ _ _ = None

end

let () =
  Framework.Domains.Stateless.register_domain (module Domain)

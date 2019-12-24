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


open Mopsa
open Framework.Core.Sig.Domain.Stateless
open Ast
open Addr
open MapExt
open Universal.Ast

module Domain =
  struct

    include GenStatelessDomainId(struct
        let name = "python.libs.typing"
      end)

    let alarms = []

    let interface = {
      iexec = { provides = []; uses = [] };
      ieval = { provides = [Zone.Z_py, Zone.Z_py_obj]; uses = [Zone.Z_py, Zone.Z_py_obj] }
    }

    let init prog man flow =
      flow

    let exec _ _ _ _ = None

    let eval zones exp man flow =
      let range = erange exp in
      match ekind exp with
      | E_py_annot {ekind = E_py_index_subscript ({ekind = E_py_object ({addr_kind = A_py_class (C_user c, _)}, _)}, {ekind = E_py_tuple annots}) } when get_orig_vname c.py_cls_var = "Union" ->
        bind_list (List.map (fun (e:expr) -> mk_expr (E_py_annot e) range) annots) (man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj)) flow |>
        bind_some (fun types flow ->
            Eval.join_list ~empty:(fun () -> Eval.empty_singleton flow)
              (List.map (fun e -> Eval.singleton e flow) types)
          )
        |> Option.return


      | _ -> None

    let ask _ _ _ = None

  end

let () = Framework.Core.Sig.Domain.Stateless.register_domain (module Domain)
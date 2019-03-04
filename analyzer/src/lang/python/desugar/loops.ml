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

(** Inliner of imported packages. *)

open Mopsa
open Universal.Ast
open Ast

module Domain =
  struct

    type _ domain += D_python_desugar_loops : unit domain

    let id = D_python_desugar_loops
    let name = "python.desugar.loops"
    let identify : type a. a domain -> (unit, a) eq option = function
      | D_python_desugar_loops -> Some Eq
      | _ -> None

    let debug fmt = Debug.debug ~channel:name fmt

    let exec_interface = {export = [Zone.Z_py]; import = []}
    let eval_interface = {export = []; import = []}

    let init _ _ flow = Some flow
    let eval _ _ _ _ = None


    let exec zone stmt man flow =
      let range = srange stmt in
      match skind stmt with
      | S_py_while (test, body, orelse) ->
         man.exec
           (mk_while
              (mk_one range)
              (mk_block [
                   mk_if
                     (mk_not test range)
                     (mk_block [
                          orelse;
                          mk_stmt S_break range
                        ] range)
                     (mk_block [] range)
                     range
                 ;
                   body
                 ] range)
              range
           ) flow
         |> Post.of_flow
         |> OptionExt.return

      | S_py_for(target, iterable, body, orelse) ->
         (* iter is better than iterable.__iter__, as the error
            created is generated by iter() (TypeError: '...' object is
            not iterable), and is not an AttributeError stating that
            __iter__ does not exist *)
         (* same for next *)
         let tmp = mktmp () in
         (* Post.bind man (fun iter flow -> *)
         let l_else =
           match skind orelse with
           | S_block [] -> [mk_stmt S_break range]
           | _ -> [orelse; mk_stmt S_break range] in
         let stmt =
           mk_block
             [ mk_assign (mk_var tmp range) (Utils.mk_builtin_call "iter" [iterable] range) range;
               mk_while
                 (mk_py_true range)
                 (mk_block [
                      (Utils.mk_try_stopiteration
                         (mk_assign
                            target
                            (Utils.mk_builtin_call "next" [mk_var tmp range] range)
                            range
                         )
                         (mk_block l_else range)
                         range)
                    ;
                      body
                    ] range)
                 range
             ]
             range
         in
         man.exec stmt flow |>
         Post.clean [mk_remove_var tmp range] man |>
         Post.return


      | _ -> None

    let ask _ _ _ = None

  end

let () =
  Framework.Domains.Stateless.register_domain (module Domain)

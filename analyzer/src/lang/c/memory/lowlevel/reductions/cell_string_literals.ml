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

(** Reduction rule between cells and string literals domains *)

open Mopsa
open Sig.Stacked.Reduction
open Universal.Ast
open Ast
open Zone

module Reduction =
struct

  let name = "c.memory.lowlevel.reductions.cell_string_literals"

  let debug fmt = Debug.debug ~channel:name fmt

  let cells = Cells.Domain.id
  let strings = String_literals.Domain.id


  let reduce exp man evals flow =
    let oe1 = man.get_eval cells evals in
    let oe2 = man.get_eval strings evals in

    (* Reduce only when both domains did an evaluation *)
    OptionExt.apply2
      (fun e1 e2 ->
         match ekind e1, ekind e2 with
          (* Constants from the string literals domain should be precise *)
          | _, E_constant (C_int _)
          | _, E_constant (C_c_character _)
          | _, E_constant (C_int_interval _) ->
            (* Remove cell evaluation *)
            let evals = man.del_eval cells evals in
            Cases.singleton evals flow

          (* Otherwise, keep cells *)
          | _ ->
            let evals = man.del_eval strings evals in
            Cases.singleton evals flow
      )
      (Cases.singleton evals flow)
      oe1 oe2

end

let () =
  register_eval_reduction (module Reduction)

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

(**
  Main entry point of the C parser 
 *)


let parse_file
    (file:string)
    (opts:string list)
    (ctx:Clang_to_C.context)
  =
  let target_options = Clang_parser.get_default_target_options () in
  (* remove some options that are in the way *)
  let filtered_opts =
    List.filter (fun o -> not (List.mem o ["-MF"])) opts
  in
  let opts = "-fparse-all-comments":: (* needed to get all comments *)
               filtered_opts
  in

  let obj, diag, coms, macros = Clang_parser.parse target_options file (Array.of_list opts) in
  
  let is_error =
    List.exists
      (function Clang_AST.({diag_level = Level_Error | Level_Fatal}) -> true | _ -> false)
       diag
  in

  if not is_error then
    Clang_to_C.add_translation_unit ctx (Filename.basename file) obj coms macros
  else
    let errors =
      List.map
        (fun diag ->
           let open Clang_AST in
           let pos = Location.mk_pos
               diag.diag_loc.loc_file
               diag.diag_loc.loc_line
               diag.diag_loc.loc_column
           in
           let range = Location.mk_orig_range pos pos in
           (range, diag.diag_message)
        )
        diag
    in
    Exceptions.syntax_errors errors

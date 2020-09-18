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

(** Render the output of an analysis depending on the selected engine. *)

open Core.All


type format =
  | F_text (* Textual output *)
  | F_json (* Formatted output in JSON *)


(* Command line option *)
(* ------------------- *)

let opt_format = ref F_text
let opt_file = ref None
let opt_display_lastflow = ref false
let opt_silent = ref false

(* Result rendering *)
(* ---------------- *)

(* Print collected alarms in the desired output format *)
let report man flow time files =
  let report = Core.Flow.get_report flow in
  let return_v = if !opt_silent || is_safe_report report then 0 else 1 in
  let lf = if !opt_display_lastflow then Some flow else None in
  let _ = match !opt_format with
    | F_text -> Text.report ~flow:lf man report time files !opt_file
    | F_json -> Json.report man report time files !opt_file in
  return_v

let panic ~btrace exn time files =
  let () = match !opt_format with
    | F_text -> Text.panic ~btrace exn files time !opt_file
    | F_json -> Json.panic ~btrace exn files time !opt_file
  in
  2

let help (args:ArgExt.arg list) =
  match !opt_format with
  | F_text -> Text.help args !opt_file
  | F_json -> Json.help args !opt_file

let list_domains (domains:string list) =
  match !opt_format with
  | F_text -> Text.list_domains domains !opt_file
  | F_json -> Json.list_domains domains !opt_file

let print range printer flow =
  match !opt_format with
  | F_text -> Text.print range printer flow !opt_file
  | F_json -> Json.print range printer flow !opt_file

let list_checks (checks:check list) =
  match !opt_format with
  | F_text -> Text.list_checks checks !opt_file
  | F_json -> Json.list_checks checks !opt_file

let list_hooks (hooks:string list) =
  match !opt_format with
  | F_text -> Text.list_hooks hooks !opt_file
  | F_json -> Json.list_hooks hooks !opt_file

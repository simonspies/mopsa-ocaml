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

(** Main entry point of the stub parser *)

open Mopsa_utils
open Mopsa_c_parser
open Location

let debug fmt = Debug.debug ~channel:"c_stubs_parser.main" fmt

(** Check whether a comment is a stub comment *)
let find_stub_comment_opt com_list =
  List.find_opt (fun com ->
      let comment = com.Clang_AST.com_text |>
                    String.trim
      in
      let lexeme = "/*$" in
      let start = String.sub comment 0 (String.length lexeme) in
      start = lexeme
    ) com_list


(** Parse the stub specification from comments of a function *)
let parse_function_comment
    (func:C_AST.func)
    (prj:C_AST.project)
    (macros:string MapExt.StringMap.t)
    (enums:Z.t MapExt.StringMap.t)
    (preds: Cst.predicate with_range list)
    (stubs:(string,Cst.stub) Hashtbl.t)
  : Ast.stub option
  =
  match find_stub_comment_opt func.func_com with
  | None -> None
  | Some com ->
    let comment = com.com_text in
    let file = com.com_range.range_begin.loc_file in
    let line = com.com_range.range_begin.loc_line in
    let col = com.com_range.range_begin.loc_column in

    (* Create the lexing buffer *)
    let buf = Lexing.from_string comment in
    buf.lex_curr_p <- {
      pos_fname = file;
      pos_lnum = line;
      pos_bol = 0;
      pos_cnum = col;
    };

    try
      (* Parse the comment *)
      let cst = Parser.parse_stub Lexer.read buf in
      match cst with
      | None -> None

      | Some cst ->
        (* Remove predicates and macros *)
        let cst1 = Passes.Predicate_expansion.doit cst preds in
        let cst2 = Passes.Macro_expansion.doit cst1 macros enums in

        (* Save the stub in the context, so it can be used later when
           resolving aliases *)
        Hashtbl.add stubs func.func_org_name cst2;

        (* Resolve scoping of variables *)
        let cst3 = Passes.Scoping.doit cst2 in

        (* Translate CST into AST *)
        let ast = Passes.Cst_to_ast.doit prj func cst3 in
        Some ast
    with
    | Lexer.SyntaxError s ->
      let range = Location.from_lexing_range (Lexing.lexeme_start_p buf) (Lexing.lexeme_end_p buf) in
      Exceptions.syntax_error range "%s" s

    | Parser.Error ->
      let range = Location.from_lexing_range (Lexing.lexeme_start_p buf) (Lexing.lexeme_end_p buf) in
      Exceptions.unnamed_syntax_error range



(** Check whether a comment is a stub directive *)
let is_directive com =
  match com with
  | [com] ->
    let comment = com.Clang_AST.com_text |>
                  String.trim
    in
    let lexeme = "/*$$$" in
    String.length comment > String.length lexeme &&
    lexeme = String.sub comment 0 (String.length lexeme)

  | _ -> false



(** Parse comment of a stub directive *)
let parse_directive_comment
    (com:Clang_AST.comment list)
    (range:Clang_AST.range)
    (prj:C_AST.project)
    (macros:string MapExt.StringMap.t)
    (enums:Z.t MapExt.StringMap.t)
    (preds:Cst.predicate with_range list)
    (stubs:(string,Cst.stub) Hashtbl.t)
  : Ast.stub option
  =
  (* Create a dummy init function *)
  let func = C_AST.{
      func_uid = 0;
      func_org_name = "$directive";
      func_unique_name = "$directive";
      func_is_static = false;
      func_return = C_AST.T_void, C_AST.no_qual;
      func_parameters = [||];
      func_body = None;
      func_static_vars = [];
      func_local_vars = [];
      func_variadic = false;
      func_range = range;
      func_name_range = range;
      func_com = com;
    }
  in
  parse_function_comment func prj macros enums preds stubs


(** Check whether a comment is a global predicate *)
let is_global_predicate com =
  match com with
  | [com] ->
    let comment = com.Clang_AST.com_text |>
                  String.trim
    in
    let lexeme = "/*$$" in
    String.length comment > String.length lexeme &&
    lexeme = String.sub comment 0 (String.length lexeme)

  | _ -> false

(** Parse comment specifying a global predicate *)
let parse_global_predicate_comment com =
  match com with
  | [] -> []
  | _ :: _ :: _ -> []
  | [com] ->
    let comment = com.Clang_AST.com_text in
    let file = com.com_range.range_begin.loc_file in
    let line = com.com_range.range_begin.loc_line in
    let col = com.com_range.range_begin.loc_column in

    (* Create the lexing buffer *)
    let buf = Lexing.from_string comment in
    buf.lex_curr_p <- {
      pos_fname = file;
      pos_lnum = line;
      pos_bol = 0;
      pos_cnum = col;
    };

    (* Parse the comment *)
    try
      let cst = Parser.parse_stub Lexer.read buf in
      OptionExt.apply (fun cst ->
          List.fold_left (fun acc section ->
              match section with
              | Cst.S_predicate pred -> pred :: acc
              | _ -> acc
            ) [] cst.content
        ) [] cst
    with
    | Lexer.SyntaxError s ->
      let range = Location.from_lexing_range (Lexing.lexeme_start_p buf) (Lexing.lexeme_end_p buf) in
      Exceptions.syntax_error range "%s" s

    | Parser.Error ->
      let range = Location.from_lexing_range (Lexing.lexeme_start_p buf) (Lexing.lexeme_end_p buf) in
      Exceptions.unnamed_syntax_error range


(** Resolve a stub alias *)
let resolve_alias
    (alias:string)
    (func:C_AST.func)
    (prj:C_AST.project)
    (stubs:(string,Cst.stub) Hashtbl.t)
  : Ast.stub
  =
  (* Find the alias *)
  let cst =
    try Hashtbl.find stubs alias
    with Not_found -> Exceptions.panic "cannot find alias stub %s" alias
  in

  (* Resolve scoping of variables *)
  let cst2 = Passes.Scoping.doit cst in

  (* Translate CST into AST *)
  Passes.Cst_to_ast.doit prj func cst2
(****************************************************************************)
(*                                                                          *)
(* This file is part of MOPSA, a Modular Open Platform for Static Analysis. *)
(*                                                                          *)
(* Copyright (C) 2019 The MOPSA Project.                                    *)
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
  Lexer for a very simple C-like "curly bracket" language.
 *)

{
open Lexing
open U_ast
open U_parser

let character_of_string s =
(* TODO: faire ça bien: *)
s.[0]
(* keyword table *)
let kwd_table = Hashtbl.create 10
let _ =
  List.iter (fun (a,b) -> Hashtbl.add kwd_table a b)
    [
     (* types *)
     "void",   TOK_VOID;
     "int",    TOK_INT;
     "real",   TOK_REAL;
     "string", TOK_STRING;
     "str", TOK_STRING;
     "char",   TOK_CHAR;
     "array",  TOK_ARRAY;

     (* constants *)
     "true",   TOK_TRUE;
     "false",  TOK_FALSE;

     (* expression operators *)
     "rand",   TOK_RAND;
     "randf",   TOK_RANDF;
     "round",  TOK_ROUND;

     (* control flow *)
     "while",  TOK_WHILE;
     "for",    TOK_FOR;
     "if",     TOK_IF;
     "else",   TOK_ELSE;
     "return", TOK_RETURN;
     "break",  TOK_BREAK;
     "continue", TOK_CONTINUE;

     (* special statements *)
     "assert", TOK_ASSERT;
     "assume", TOK_ASSUME;
     "print",  TOK_PRINT;
   ]

}

(* special character classes *)
let space = [' ' '\t' '\r']+
let newline = "\n" | "\r" | "\r\n"

(* utilities *)
let digit = ['0'-'9']
let digit_ = ['0'-'9' '_']

(* integers *)
let int_dec = digit digit_*
let int_bin = ("0b" | "0B") ['0'-'1'] ['0'-'1' '_']*
let int_oct = ("0o" | "0O") ['0'-'7'] ['0'-'7' '_']*
let int_hex = ("0x" | "0X") ['0'-'9' 'a'-'f' 'A'-'F'] ['0'-'9' 'a'-'f' 'A'-'F' '_']*
let const_int = int_bin | int_oct | int_dec | int_hex

let const_real =
   digit+ "." digit*

(* tokens *)
rule token = parse

(* identifier (TOK_id) or reserved keyword *)
| ['a'-'z' 'A'-'Z' '_'] ['a'-'z' 'A'-'Z' '0'-'9' '_']* as id
{ try Hashtbl.find kwd_table id with Not_found -> TOK_id id }

(* symbols *)
| "("    { TOK_LPAREN }
| ")"    { TOK_RPAREN }
| "["    { TOK_LBRACKET }
| "]"    { TOK_RBRACKET }
| "{"    { TOK_LCURLY }
| "}"    { TOK_RCURLY }
| "*"    { TOK_STAR }
| "+"    { TOK_PLUS }
| "-"    { TOK_MINUS }
| "!"    { TOK_EXCLAIM }
| "/"    { TOK_DIVIDE }
| "<"    { TOK_LESS }
| ">"    { TOK_GREATER }
| "<="   { TOK_LESS_EQUAL }
| ">="   { TOK_GREATER_EQUAL }
| "=="   { TOK_EQUAL_EQUAL }
| "!="   { TOK_NOT_EQUAL }
| "&&"   { TOK_AND_AND }
| "|"    { TOK_BAR }
| "||"   { TOK_BAR_BAR }
| ";"    { TOK_SEMICOLON }
| ","    { TOK_COMMA }
| "="    { TOK_EQUAL }
| "@"    { TOK_CONCAT }

(* literals *)
| const_int    as c { TOK_int c  }
| const_real   as r { TOK_real r }

(* spaces, comments *)
| "/*" { comment lexbuf; token lexbuf }
| "\"" { stringer (Buffer.create 12) lexbuf}
| "\'"  { character (Buffer.create 12) lexbuf}
| "//" [^ '\n' '\r']* { token lexbuf }
| newline { new_line lexbuf; token lexbuf }
| space { token lexbuf }

(* end of files *)
| eof { TOK_EOF }


(* nested comments (handled recursively)  *)
and comment = parse
| "*/" { () }
| [^ '\n' '\r'] { comment lexbuf }
| newline { new_line lexbuf; comment lexbuf }

and stringer buf = parse
| "\"" { TOK_string( Buffer.contents buf ) }
| [^ '\"']+ { Buffer.add_string buf (Lexing.lexeme lexbuf) ; stringer buf lexbuf }

and character buf = parse
| "\'" { TOK_char( character_of_string (Buffer.contents buf)) }
| [^ '\'']+ { Buffer.add_string buf (Lexing.lexeme lexbuf) ; character buf lexbuf }

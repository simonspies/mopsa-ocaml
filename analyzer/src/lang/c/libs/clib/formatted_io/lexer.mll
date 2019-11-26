{
  open Parser

  let format = ref false
}

let num = ['0'-'9'] ['0'-'9']*

(* TODO:
   - map z, j, t to size_t, intmax_t, ptrdiff_t instead of long long
   - detect unsupported n, $, *
*)

rule read =
  parse
  | "%%"        { format:= false; read lexbuf }
  | "%"         { format := true; read lexbuf }
  | "+"         { if !format then PLUS else read lexbuf }
  | "-"         { if !format then MINUS else read lexbuf }
  | "0"         { if !format then ZERO else read lexbuf }
  | " "         { if !format then SPACE else read lexbuf }
  | "#"         { if !format then SHARP else read lexbuf }
  | num         { if !format then NUM (int_of_string (Lexing.lexeme lexbuf)) else read lexbuf }
  | "*"         { if !format then STAR else read lexbuf }
  | "."         { if !format then DOT else read lexbuf }
  | "hh" 	{ if !format then HH else read lexbuf }
  | "h"         { if !format then H else read lexbuf }
  | "ll"        { if !format then LL else read lexbuf }
  | "l"         { if !format then L else read lexbuf }
  | "L"         { if !format then CAP_L else read lexbuf }
  | "z"         { if !format then LL else read lexbuf }
  | "t"         { if !format then LL else read lexbuf }
  | "j"         { if !format then LL else read lexbuf }
  | "d"         { if !format then D else read lexbuf }
  | "i"         { if !format then I else read lexbuf }
  | "u"         { if !format then U else read lexbuf }
  | "f" | "F"   { if !format then F else read lexbuf }
  | "g" | "G"   { if !format then G else read lexbuf }
  | "a" | "A"   { if !format then A else read lexbuf }
  | "p"         { if !format then P else read lexbuf }
  | "s"		{ if !format then S else read lexbuf }
  | "x" | "X"	{ if !format then X else read lexbuf }
  | "o"	  	{ if !format then O else read lexbuf }
  | "c" 	{ if !format then C else read lexbuf }
  | eof         { EOF }
  | _           { format := false; read lexbuf }



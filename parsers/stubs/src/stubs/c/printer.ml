(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

open Ast
open Format

let pp_var fmt v = pp_print_string fmt v.var_name

let pp_resource fmt resource = pp_print_string fmt resource

let pp_builtin fmt f =
  match f with
  | SIZE   -> pp_print_string fmt "size"
  | OFFSET -> pp_print_string fmt "offset"
  | BASE   -> pp_print_string fmt "base"
  | OLD    -> pp_print_string fmt "old"


let rec pp_expr fmt exp =
  match kind exp with
  | E_int n -> Z.pp_print fmt n
  | E_float f -> pp_print_float fmt f
  | E_string s -> fprintf fmt "\"%s\"" s
  | E_char c -> fprintf fmt "'%c'" c
  | E_var v -> pp_var fmt v
  | E_unop (op, e) -> fprintf fmt "%a(%a)" pp_unop op pp_expr e
  | E_binop (op, e1, e2) -> fprintf fmt "(%a) %a (%a)" pp_expr e1 pp_binop op pp_expr e2
  | E_addr_of e -> fprintf fmt "&(%a)" pp_expr e
  | E_deref e -> fprintf fmt "*(%a)" pp_expr e
  | E_cast(t, e) -> fprintf fmt "(%a) %a" pp_typ t pp_expr e
  | E_subscript(a, i) -> fprintf fmt "%a[%a]" pp_expr a pp_expr i
  | E_member(s, f) -> fprintf fmt "%a.%s" pp_expr s f
  | E_arrow(p, f) -> fprintf fmt "%a->%s" pp_expr p f
  | E_builtin_call(f, arg) -> fprintf fmt "%a(%a)" pp_builtin f pp_expr arg
  | E_return -> pp_print_string fmt "return"

and pp_unop fmt =
  function
  | PLUS    -> pp_print_string fmt "+"
  | MINUS   -> pp_print_string fmt "-"
  | LNOT    -> pp_print_string fmt "!"
  | BNOT    -> pp_print_string fmt "~"

and pp_binop fmt =
  function
  | ADD     -> pp_print_string fmt "+"
  | SUB     -> pp_print_string fmt "-"
  | MUL     -> pp_print_string fmt "*"
  | DIV     -> pp_print_string fmt "/"
  | MOD     -> pp_print_string fmt "%"
  | RSHIFT  -> pp_print_string fmt ">>"
  | LSHIFT  -> pp_print_string fmt "<<"
  | LOR     -> pp_print_string fmt "||"
  | LAND    -> pp_print_string fmt "&&"
  | LT      -> pp_print_string fmt "<"
  | LE      -> pp_print_string fmt "<="
  | GT      -> pp_print_string fmt ">"
  | GE      -> pp_print_string fmt ">="
  | EQ      -> pp_print_string fmt "=="
  | NEQ     -> pp_print_string fmt "!="
  | BOR     -> pp_print_string fmt "|"
  | BAND    -> pp_print_string fmt "&"
  | BXOR    -> pp_print_string fmt "^"

and pp_typ fmt =
  function
  | T_int -> pp_print_string fmt "int"
  | T_char -> pp_print_string fmt "char"
  | T_pointer t -> fprintf fmt "%a *" pp_typ t
  | T_user t  -> pp_var fmt t
  | T_long -> pp_print_string fmt "int"
  | T_float -> pp_print_string fmt "int"
  | T_double -> pp_print_string fmt "int"
  | T_signed t -> fprintf fmt "signed %a" pp_typ t
  | T_unsigned t -> fprintf fmt "signed %a" pp_typ t
  | T_const t -> fprintf fmt "signed %a" pp_typ t
  | T_struct s -> fprintf fmt "struct %a" pp_var s
  | T_union u -> fprintf fmt "union %a" pp_var u
  | T_unknown -> pp_print_string fmt "?"

let rec pp_formula fmt (f:formula with_range) =
  match kind f with
  | F_expr e -> pp_expr fmt e
  | F_bool true  -> pp_print_string fmt "true"
  | F_bool false -> pp_print_string fmt "false"
  | F_binop (op, f1, f2) -> fprintf fmt "(%a) %a (%a)" pp_formula f1 pp_log_binop op pp_formula f2
  | F_not f -> fprintf fmt "not (%a)" pp_formula f
  | F_forall (x, set, f) -> fprintf fmt "∀ %a ∈ %a: @[%a@]" pp_var x pp_set set pp_formula f
  | F_exists (x, set, f) -> fprintf fmt "∃ %a ∈ %a: @[%a@]" pp_var x pp_set set pp_formula f
  | F_in (x, set) -> fprintf fmt "%a ∈ %a" pp_var x pp_set set
  | F_free e -> fprintf fmt "free(%a)" pp_expr e

and pp_log_binop fmt =
  function
  | AND -> pp_print_string fmt "and"
  | OR -> pp_print_string fmt "or"
  | IMPLIES -> pp_print_string fmt "implies"

and pp_set fmt =
  function
  | S_interval(e1, e2) -> fprintf fmt "[%a .. %a]" pp_expr e1 pp_expr e2
  | S_resource(r) -> pp_resource fmt r

let pp_arguments fmt args =
  pp_print_list ~pp_sep:(fun fmt () -> pp_print_string fmt ", ") pp_expr fmt args

let pp_list pp fmt l =
  pp_print_list ~pp_sep:(fun fmt () -> fprintf fmt "@\n") pp fmt l

let pp_opt pp fmt o =
  match o with
  | None -> ()
  | Some x -> pp fmt x


let rec pp_local fmt local =
  map_kind local @@ fun local ->
  fprintf fmt "local: %a = @[%a@];"
    pp_var local.local_var
    pp_local_value local.local_value

and pp_local_value fmt v =
  match v with
  | Local_new resouce -> fprintf fmt "new %a" pp_resource resouce
  | Local_function_call (f, args) -> fprintf fmt "%a(%a)" pp_var f pp_arguments args


let pp_predicate fmt (predicate:predicate with_range) =
  map_kind predicate @@ fun predicate ->
  fprintf fmt "predicate %a: @[%a@];"
    pp_var predicate.predicate_var
    pp_formula predicate.predicate_body

let pp_requires fmt requires =
  map_kind requires @@ fun requires ->
  fprintf fmt "requires: @[%a@];" pp_formula requires

let pp_assigns fmt assigns =
  map_kind assigns @@ fun assigns ->
  fprintf fmt "assigns: %a%a;"
    pp_expr assigns.assign_target
    (pp_opt (fun fmt (l, u) ->
         fprintf fmt "[%a .. %a]" pp_expr l pp_expr u
       )
    ) assigns.assign_range


let pp_assumes fmt (assumes:assumes with_range) =
  map_kind assumes @@ fun assumes ->
  fprintf fmt "assumes: @[%a@];" pp_formula assumes

let pp_ensures fmt ensures =
  map_kind ensures @@ fun ensures ->
  fprintf fmt "ensures: @[%a@];" pp_formula ensures

let pp_case fmt case =
  map_kind case @@ fun case ->
  fprintf fmt "case \"%s\":@\n  @[%a%a%a%a%a@]"
    case.case_label
    (pp_list pp_assumes) case.case_assumes
    (pp_list pp_local) case.case_local
    (pp_list pp_requires) case.case_requires
    (pp_list pp_assigns) case.case_assigns
    (pp_list pp_ensures) case.case_ensures

let pp_stub fmt stub =
  fprintf fmt "%a%a%a%a%a%a"
    (pp_list pp_local) stub.stub_local
    (pp_list pp_predicate) stub.stub_predicates
    (pp_list pp_requires) stub.stub_requires
    (pp_list pp_assigns) stub.stub_assigns
    (pp_list pp_case) stub.stub_case
    (pp_list pp_ensures) stub.stub_ensures

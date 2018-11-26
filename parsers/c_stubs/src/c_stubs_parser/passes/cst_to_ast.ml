(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(** Translate a CST into a AST by resolving types, variables and
   functions defined in the project. *)

open Location
open Cst


let debug fmt = Debug.debug ~channel:"c_stubs_parser.passes.cst_to_ast" fmt


(** {2 Generic visitors} *)
(** ******************** *)

let rec visit_list visit l prj func =
  match l with
  | [] -> []
  | hd :: tl ->
    let hd' = visit hd prj func in
    let tl' = visit_list visit tl prj func in
    hd' :: tl'

let visit_option visit o prj func =
  match o with
  | None -> None
  | Some x -> Some (visit x prj func)

let visit_pair visitor1 visitor2 (x, y) prj func =
  (visitor1 x prj func, visitor2 y prj func)


(** {2 Types} *)
(** ********* *)

let find_record r prj =
  let open C_AST in
  StringMap.bindings prj.proj_records |>
  List.split |>
  snd |>
  List.find (fun r' -> compare r'.record_org_name r.vname = 0)

let find_typedef t prj =
  let open C_AST in
  StringMap.bindings prj.proj_typedefs |>
  List.split |>
  snd |>
  List.find (fun t' -> compare t'.typedef_org_name t.vname = 0)

let find_enum e prj =
  let open C_AST in
  StringMap.bindings prj.proj_enums |>
  List.split |>
  snd |>
  List.find (fun e' -> compare e'.enum_org_name e.vname = 0)

let find_function f prj =
  let open C_AST in
  StringMap.bindings prj.proj_funcs |>
  List.split |>
  snd |>
  List.find (fun f' -> compare f'.func_org_name f.vname = 0)

let rec visit_qual_typ t prj func : C_AST.type_qual=
  let (t0, is_const) = t in
  let t0' = visit_typ t0 prj func in
  let qual = C_AST.{ qual_is_const = is_const; } in
  t0', qual

and visit_typ t prj func =
  match t with
  | T_void -> C_AST.T_void
  | T_char -> C_AST.(T_integer (Char SIGNED)) (* FIXME: get the signedness defined by the platform *)
  | T_signed_char -> C_AST.(T_integer SIGNED_CHAR)
  | T_unsigned_char -> C_AST.(T_integer UNSIGNED_CHAR)
  | T_signed_short -> C_AST.(T_integer SIGNED_SHORT)
  | T_unsigned_short -> C_AST.(T_integer UNSIGNED_SHORT)
  | T_signed_int -> C_AST.(T_integer SIGNED_INT)
  | T_unsigned_int -> C_AST.(T_integer UNSIGNED_INT)
  | T_signed_long -> C_AST.(T_integer SIGNED_LONG)
  | T_unsigned_long -> C_AST.(T_integer UNSIGNED_LONG)
  | T_signed_long_long -> C_AST.(T_integer SIGNED_LONG_LONG)
  | T_unsigned_long_long -> C_AST.(T_integer UNSIGNED_LONG_LONG)
  | T_signed_int128 -> C_AST.(T_integer SIGNED_INT128)
  | T_unsigned_int128 -> C_AST.(T_integer UNSIGNED_INT128)
  | T_float -> C_AST.(T_float FLOAT)
  | T_double -> C_AST.(T_float DOUBLE)
  | T_long_double -> C_AST.(T_float LONG_DOUBLE)
  | T_array(t, len) -> C_AST.T_array (visit_qual_typ t prj func , visit_array_length len prj func )
  | T_struct(s) -> C_AST.T_record (find_record s prj)
  | T_union(u) -> C_AST.T_record (find_record u prj)
  | T_typedef(t) -> C_AST.T_typedef (find_typedef t prj)
  | T_pointer(t) -> C_AST.T_pointer (visit_qual_typ t prj func )
  | T_enum(e) -> C_AST.T_enum (find_enum e prj)
  | T_unknown -> Exceptions.panic "unknown type not resolved"

and visit_array_length len prj func =
  match len with
  | A_no_length -> C_AST.No_length
  | A_constant_length n -> C_AST.Length_cst n


let int_type = C_AST.(T_integer SIGNED_INT, no_qual)
let bool_type = C_AST.(T_bool, no_qual)
let float_type = C_AST.(T_float FLOAT, no_qual)
let double_type = C_AST.(T_float DOUBLE, no_qual)
let string_type s = C_AST.(T_array((T_integer(SIGNED_CHAR), no_qual), Length_cst (Z.of_int (1 + String.length s))), no_qual)
let char_type = C_AST.(T_integer (Char SIGNED), no_qual)
let pointer_type t = C_AST.(T_pointer t, no_qual)

let pointed_type t =
  let t0, _ = t in
  match t0 with
  | C_AST.T_pointer t' -> t'
  | C_AST.T_array(t', _) -> t'
  | _ -> Exceptions.panic "pointed_type(cst_to_ast.ml): unsupported type %s" (C_print.string_of_type_qual t)

let subscript_type t = pointed_type t

let field_type t f =
  match fst t with
  | C_AST.T_record r ->
    begin try
      let field = Array.to_list r.C_AST.record_fields |>
                  List.find (fun field -> compare field.C_AST.field_org_name f = 0)
      in
      field.field_type
    with Not_found ->
      Exceptions.panic "field_type(cst_to_ast.ml): unknown field %s in record %s"
        f r.C_AST.record_org_name
  end
  | _ -> Exceptions.panic "field_type(cst_to_ast.ml): unsupported type %s"
           (C_print.string_of_type_qual t)

let builtin_type f arg =
  match f.content with
  | SIZE   -> int_type
  | OFFSET -> int_type
  | BASE   -> Exceptions.panic "builtin_type(cst_to_ast.ml): type of base(..) not implemented"
  | OLD    -> arg.content.Ast.typ


(** {2 Expressions} *)
(** *************** *)

let visit_unop = function
  | PLUS  -> Ast.PLUS
  | MINUS -> Ast.MINUS
  | LNOT  -> Ast.LNOT
  | BNOT  -> Ast.BNOT

let visit_binop = function
  | ADD -> Ast.ADD
  | SUB -> Ast.SUB
  | MUL -> Ast.MUL
  | DIV -> Ast.DIV
  | MOD -> Ast.MOD
  | RSHIFT -> Ast.RSHIFT
  | LSHIFT -> Ast.LSHIFT
  | LOR -> Ast.LOR
  | LAND -> Ast.LAND
  | LT -> Ast.LT
  | LE -> Ast.LE
  | GT -> Ast.GT
  | GE -> Ast.GE
  | EQ -> Ast.EQ
  | NEQ -> Ast.NEQ
  | BOR -> Ast.BOR
  | BAND -> Ast.BAND
  | BXOR -> Ast.BXOR

let visit_var v prj func =
  let open C_AST in
  if v.vlocal then
    {
      var_uid = v.vuid; (** FIXME: ensure that v.vuid is unique in the entire project *)
      var_org_name = v.vname;
      var_unique_name = v.vname ^ (string_of_int v.vuid); (** FIXME: give better unique names *)
      var_kind = Variable_local func;
      var_type = visit_qual_typ v.vtyp prj func;
      var_init = None;
      var_range = Clang_AST.{
          range_begin = {
            loc_file = get_range_start v.vrange |> get_pos_file;
            loc_line = get_range_start v.vrange |> get_pos_line;
            loc_column = get_range_start v.vrange |> get_pos_column;
          };
          range_end = {
            loc_file = get_range_end v.vrange |> get_pos_file;
            loc_line = get_range_end v.vrange |> get_pos_line;
            loc_column = get_range_end v.vrange |> get_pos_column;
          }
        };
      var_com = [];
    }
  else
    (* Search for the variable in the parameters of the function or
       the globals of the project *)
    let vars = Array.to_list func.func_parameters @
               (StringMap.bindings prj.proj_vars |> List.split |> snd)
    in
    try List.find (fun v' -> compare v'.var_org_name v.vname = 0) vars
    with Not_found -> Exceptions.panic "cst_to_ast: variable %a not found" pp_var v

let rec unroll_type t =
  let open C_AST in
  match fst t with
  | T_typedef td -> unroll_type td.typedef_def
  | T_enum e -> T_integer e.enum_integer_type, snd t
  | _ -> t

let rec promote_expression_type (e: Ast.expr with_range) =
  let open C_AST in
  bind_range e @@ fun ee ->
  let t = unroll_type ee.typ in
  match fst t with
  | T_integer (SIGNED_INT | UNSIGNED_INT |
               SIGNED_LONG | UNSIGNED_LONG |
               SIGNED_LONG_LONG | UNSIGNED_LONG_LONG |
               SIGNED_INT128 | UNSIGNED_INT128
              ) ->
    ee

  | T_integer (Char SIGNED | SIGNED_CHAR | SIGNED_SHORT) ->
    let tt = (T_integer SIGNED_INT), snd t in
    { kind = E_cast(tt, false, e); typ = tt }

  | T_integer (Char UNSIGNED | UNSIGNED_CHAR | UNSIGNED_SHORT) ->
    let tt = (T_integer UNSIGNED_INT), snd t in
    { kind = E_cast(tt, false, e); typ = tt }

  | T_float _ -> ee

  | T_pointer _ -> ee

  | T_array _ -> ee

  | _ -> Exceptions.panic "promote_expression_type: unsupported type %s"
           (C_print.string_of_type_qual t)

let convert_expression_type (e:Ast.expr with_range) t =
  bind_range e @@ fun ee ->
  if compare ee.typ t = 0 then ee
  else { kind = E_cast(t, false, e); typ = t }

let binop_type t1 t2 =
  let open C_AST in
  match fst (unroll_type t1), fst (unroll_type t2) with
  | _, _ when compare t1 t2 = 0 -> t1

  | T_float LONG_DOUBLE, _ -> t1
  | _, T_float LONG_DOUBLE -> t2

  | T_float DOUBLE, _ -> t1
  | _, T_float DOUBLE -> t2

  | T_float FLOAT, _ -> t1
  | _, T_float FLOAT -> t2

  | T_integer UNSIGNED_LONG_LONG, T_integer _ -> t1
  | T_integer _, T_integer UNSIGNED_LONG_LONG -> t2

  | T_integer UNSIGNED_LONG, T_integer _ -> t1
  | T_integer _, T_integer UNSIGNED_LONG -> t2

  | T_integer UNSIGNED_INT, T_integer SIGNED_INT -> t1
  | T_integer SIGNED_INT, T_integer UNSIGNED_INT -> t2

  | T_pointer _, T_integer _ -> t1
  | T_integer _, T_pointer _ -> t2

  | _ -> Exceptions.panic "binop_type: unsupported case: %s and %s"
           (C_print.string_of_type_qual t1)
           (C_print.string_of_type_qual t2)

let rec visit_expr e prj func =
  bind_range e @@ fun ee ->
  let kind, typ = match ee with
    | E_int(n) -> Ast.E_int(n), int_type

    | E_float(f) -> Ast.E_float(f), float_type

    | E_string(s) -> Ast.E_string(s), string_type s

    | E_char(c) -> Ast.E_char(c), char_type

    | E_var(v) ->
      let v = visit_var v prj func in
      Ast.E_var v, v.var_type

    | E_unop(op, e')      ->
      let e' = visit_expr e' prj func in
      let e' = promote_expression_type e' in
      let ee' =
        with_range
          Ast.{ kind = E_unop(visit_unop op, e'); typ = e'.content.typ }
          e.range
      in

      E_cast(e'.content.typ, false, ee'), e'.content.typ

    | E_binop(op, e1, e2) ->
      let e1 = visit_expr e1 prj func in
      let e2 = visit_expr e2 prj func in

      let e1 = promote_expression_type e1 in
      let e2 = promote_expression_type e2 in

      let t = binop_type e1.content.typ e2.content.typ in

      let e1 = convert_expression_type e1 t in
      let e2 = convert_expression_type e2 t in

      let ee' = with_range
          Ast.{ kind = E_binop(visit_binop op, e1, e2); typ = t }
          e.range
      in
      
      begin match op with
        | EQ | NEQ | LT | LE | GT | GE -> ee'.content.kind, ee'.content.typ
        | _ -> Ast.E_cast(t, false, ee'), t
      end

    | E_addr_of(e')       ->
      let e' = visit_expr e' prj func in
      Ast.E_addr_of e', pointer_type e'.content.typ

    | E_deref(e')         ->
      let e' = visit_expr e' prj func in
      Ast.E_deref e', pointed_type e'.content.typ

    | E_cast(t, e') ->
      let t = visit_qual_typ t prj func in
      Ast.E_cast(t, true, visit_expr e' prj func ), t

    | E_subscript(a, i)   ->
      let a  = visit_expr a prj func in
      Ast.E_subscript(a, visit_expr i prj func ), subscript_type a.content.typ

    | E_member(s, f)      ->
      let s = visit_expr s prj func in
      Ast.E_member(s, f), field_type s.content.typ f

    | E_arrow(p, f) ->
      let p = visit_expr p prj func in
      Ast.E_arrow(p, f), field_type (pointed_type p.content.typ) f

    | E_builtin_call(f,a) ->
      let a = visit_expr a prj func in
      Ast.E_builtin_call(visit_builtin f, a), builtin_type f a

    | E_return -> Ast.E_return, func.func_return
  in
  Ast.{ kind; typ }

and visit_builtin b =
  bind_range b @@ function
  | OLD    -> Ast.OLD
  | SIZE   -> Ast.SIZE
  | OFFSET -> Ast.OFFSET
  | BASE   -> Ast.BASE


(** {2 Formulas} *)
(** ************ *)

let visit_log_binop = function
  | AND -> Ast.AND
  | OR  -> Ast.OR
  | IMPLIES -> Ast.IMPLIES

let visit_set s prj func =
  match s with
  | S_interval(e1, e2) -> Ast.S_interval(visit_expr e1 prj func , visit_expr e2 prj func )
  | S_resource(r) -> Ast.S_resource(r)

let rec visit_formula f prj func =
  bind_range f @@ fun f ->
  match f with
  | F_expr(e) -> Ast.F_expr (visit_expr e prj func )
  | F_bool(b) -> Ast.F_bool b
  | F_binop(op, f1, f2) -> Ast.F_binop(visit_log_binop op, visit_formula f1 prj func , visit_formula f2 prj func )
  | F_not f' -> Ast.F_not (visit_formula f' prj func)
  | F_forall(v, t, s, f') ->
    let v' = visit_var v prj func in
    Ast.F_forall(v', visit_set s prj func, visit_formula f' prj func)
  | F_exists(v, t, s, f') ->
    let v' = visit_var v prj func in
    Ast.F_exists(v', visit_set s prj func, visit_formula f' prj func)
  | F_in(v, s) -> Ast.F_in(visit_var v prj func, visit_set s prj func)
  | F_free(e) -> Ast.F_free(visit_expr e prj func)
  | F_predicate(p, args) -> Exceptions.panic "cst_to_ast: predicate %a not expanded" pp_var p


(** {2 Stub sections} *)
(** **************** *)

let visit_requires req prj func =
  bind_range req @@ fun req ->
  visit_formula req prj func

let visit_assumes asm prj func =
  bind_range asm @@ fun asm ->
  visit_formula asm prj func

let visit_assigns a prj func =
  bind_range a @@ fun a ->
  Ast.{
    assign_target = visit_expr a.Cst.assign_target prj func;
    assign_offset = visit_option (visit_pair visit_expr visit_expr) a.Cst.assign_offset prj func;
  }

let visit_ensures ens prj func =
  bind_range ens @@ fun ens ->
  visit_formula ens prj func

let visit_local loc prj func =
  bind_range loc @@ fun loc ->
  let lvar = visit_var loc.lvar prj func in
  let lval =
    match loc.lval with
    | L_new r -> Ast.L_new r
    | L_call (f, args) ->
      let f = bind_range f @@ fun f -> find_function f prj in
      Ast.L_call (f, visit_list visit_expr args prj func)
  in
  Ast.{ lvar; lval }

let visit_case c prj func =
  bind_range c @@ fun c ->
  let requires = visit_list visit_requires c.case_requires prj func in
  let assumes = visit_list visit_assumes c.case_assumes prj func in
  let assigns = visit_list visit_assigns c.case_assigns prj func in
  let local = visit_list visit_local c.case_local prj func in
  let ensures = visit_list visit_ensures c.case_ensures prj func in

  Ast.{
    case_label = c.case_label;
    case_assumes = assumes;
    case_requires = requires;
    case_post = {
      post_assigns = assigns;
      post_local   = local;
      post_ensures = ensures;
    }
  }

(** {2 Entry point} *)
(** *************** *)

let doit
    (prj:C_AST.project)
    (func: C_AST.func)
    (stub:Cst.stub with_range)
  : Ast.stub with_range
  =
  bind_range stub @@ fun stub ->
  match stub with
  | S_simple s ->
    let requires = visit_list visit_requires s.simple_stub_requires prj func in
    let assigns = visit_list visit_assigns s.simple_stub_assigns prj func  in
    let local = visit_list visit_local s.simple_stub_local prj func  in
    let ensures = visit_list visit_ensures s.simple_stub_ensures prj func in

    Ast.{
      stub_requires = requires;
      stub_body = B_post {
          post_assigns = assigns;
          post_local   = local;
          post_ensures = ensures;
        }
    }

  | S_case c ->
    let requires = visit_list visit_requires c.case_stub_requires prj func in
    Ast.{
      stub_requires = requires;
      stub_body = B_cases (visit_list visit_case c.case_stub_cases prj func);
    }
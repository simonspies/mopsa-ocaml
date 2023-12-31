(**

  Copyright (c) 2017-2019 Aymeric Fromherz and The MOPSA Project

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
 *)

open Mopsa_utils
open Ast

let debug fmt = Debug.debug ~channel:"frontend.uid" fmt

let pp_scope fmt (globals, locals) =
  let open Format in
  let comma_sep = fun fmt () -> fprintf fmt ", " in
  let pp_varlist = pp_print_list ~pp_sep:comma_sep Pp.print_var in
  fprintf fmt "Globals = @[@\n%a@]@\nLocals = @[@\n%a@]@\n"
    pp_varlist globals pp_varlist locals

let counter = ref 0

let create_new_uid v = incr counter; {v with uid = !counter}

let gc = List.map (fun v -> {name=v; uid=0} |> create_new_uid) Builtins.all

let start_counter_at (d:int) : unit =
  if d > 0 then counter := d

let rec translate_program program =
  let pp_globs = (Format.pp_print_list ~pp_sep:(fun fmt () -> Format.fprintf fmt "@\n") (fun fmt var -> Format.fprintf fmt "%s:%d" var.name var.uid)) in
  debug "starting at counter = %d@\n" !counter;
  debug "program.prog_globals = %a@\n" pp_globs program.prog_globals;
  let globals = List.rev @@ List.fold_left (fun acc var_wouid ->
      (* if List.mem var_wouid.name Builtins.all then
       *   acc
       * else *)
        (create_new_uid var_wouid) :: acc) [] program.prog_globals in
  debug "globals is now:@\n%a@\n" pp_globs globals;
  let translated_prog = {
    prog_body = translate_stmt (globals @ gc, []) program.prog_body;
    prog_globals = globals;
  } in
  translated_prog, !counter

and translate_stmt (scope: (var list) * (var list)) stmt =
  let range = stmt.srange in
  let (globals, lscope) = scope in
  match stmt.skind with
  | S_function f ->
    let func_var = find_in_scope scope range f.func_var in
    let func_nonlocals = List.map (find_in_scope ([], lscope) range) f.func_nonlocals in
    let func_globals = List.map (find_in_scope (globals, []) range) f.func_globals in
    let func_locals = List.map create_new_uid f.func_locals in
    let func_parameters = List.map create_new_uid f.func_parameters in
    let func_defaults = List.map (translate_expr_option scope) f.func_defaults in
    let func_vararg = OptionExt.lift create_new_uid f.func_vararg in
    let func_kwonly_args = List.map create_new_uid f.func_kwonly_args in
    let func_kwonly_defaults = List.map (translate_expr_option scope) f.func_kwonly_defaults in
    let func_kwarg = OptionExt.lift create_new_uid f.func_kwarg in
    let func_decors = List.map (translate_expr scope) f.func_decors in
    let func_types_in = List.map (translate_expr_option scope) f.func_types_in in
    let func_type_out = translate_expr_option scope f.func_type_out in
    let other_parameters = (match func_vararg with | None -> [] | Some v -> [v]) @ func_kwonly_args @ (match func_kwarg with | None -> [] | Some v -> [v]) in
    let parent_scope = List.filter (fun v -> List.for_all (fun v' -> v.name != v'.name ) (func_var :: func_locals @ func_parameters @ other_parameters)) lscope in
    (* some issues with conflicting names. Example:
       class date: pass
       class datetime(date):
          def date(self): return date() <- this date should be the class, not the function
     *)
    let new_lscope = func_parameters @ other_parameters @ func_locals @ func_nonlocals @ parent_scope in
    { stmt with
      skind = S_function {
          func_var;
          func_body = translate_stmt (globals @ [func_var], new_lscope) f.func_body;
          func_parameters;
          func_defaults;
          func_vararg;
          func_kwonly_args;
          func_kwonly_defaults;
          func_kwarg;
          func_nonlocals;
          func_locals;
          func_globals;
          func_is_generator = f.func_is_generator;
          func_decors;
          func_types_in;
          func_type_out;
          func_range = f.func_range;
        }
    }

  | S_class cls ->
     let cls_var = find_in_scope scope range cls.cls_var in
     let cls_static_attributes = List.map create_new_uid cls.cls_static_attributes in
     let cls_decors = List.map (translate_expr scope) cls.cls_decors in
     let parent_scope = List.filter (fun v -> List.for_all (fun v' -> v.name != v'.name ) (cls_var :: cls_static_attributes)) lscope in
     let new_lscope = cls_var :: cls_static_attributes @ parent_scope in
      {stmt with
       skind = S_class {
           cls_var = find_in_scope scope range cls.cls_var;
           cls_body = translate_stmt (globals, new_lscope) cls.cls_body;
           cls_static_attributes;
           cls_bases = List.map (translate_expr scope) cls.cls_bases;
           cls_decors;
           cls_keywords = List.map (fun (k, v) -> (k, translate_expr scope v)) cls.cls_keywords;
           cls_range = cls.cls_range;
         }
      }

    (* The remaining statements are just visited by induction since they don't change the scope *)
    | S_assign (target, expr) ->
      {stmt with skind = S_assign (translate_expr scope target, translate_expr scope expr)}

    | S_type_annot (target, typ) ->
      {stmt with skind = S_type_annot (translate_expr scope target, translate_expr scope typ)}

    | S_aug_assign (target, op, expr) ->
      {stmt with skind = S_aug_assign (translate_expr scope target, op, translate_expr scope expr)}

    | S_expression expr ->
      {stmt with skind = S_expression (translate_expr scope expr)}

    | S_while (test, body, orelse) ->
      {stmt with skind = S_while (translate_expr scope test, translate_stmt scope body, translate_stmt_option scope orelse)}

    | S_block(sl) ->
      {stmt with skind = S_block (List.map (translate_stmt scope) sl)}

    | S_if (test, body, orelse) ->
      {stmt with skind = S_if (translate_expr scope test, translate_stmt scope body, translate_stmt_option scope orelse)}

    | S_try (body, handlers, orelse, finally) ->
      {stmt with skind = S_try (translate_stmt scope body, List.map (translate_except_handler scope range) handlers, translate_stmt_option scope orelse, translate_stmt_option scope finally)}

    | S_for (target, iter, body, orelse) ->
      {stmt with skind = S_for (translate_expr scope target, translate_expr scope iter, translate_stmt scope body, translate_stmt_option scope orelse)}

    | S_return expr ->
      {stmt with skind = S_return (translate_expr scope expr)}

    | S_raise(e, c) ->
      {stmt with skind = S_raise (translate_expr_option scope e, translate_expr_option scope c)}

    | S_import(modul, None, vroot) ->
      {stmt with skind = S_import(modul, None, find_in_scope scope range vroot)}

    | S_import(modul, Some vasname, vroot) ->
      {stmt with skind = S_import(modul, Some (find_in_scope scope range vasname), find_in_scope scope range vroot)}

    | S_import_from(modul, name, vroot, vname) ->
      {stmt with skind = S_import_from(modul, name, find_in_scope scope range vroot, find_in_scope scope range vname)}

    | S_delete e ->
      {stmt with skind = S_delete (translate_expr scope e)}

    | S_assert(e, msg) ->
      {stmt with skind = S_assert (translate_expr scope e, translate_expr_option scope msg)}

    | S_with(ctx, None, body) ->
      {stmt with skind = S_with (translate_expr scope ctx, None, translate_stmt scope body)}

    | S_with(ctx, Some target, body) ->
      {stmt with skind = S_with (translate_expr scope ctx, Some (translate_expr scope target), translate_stmt scope body)}

    | S_pass
    | S_continue
    | S_break
      -> stmt

and translate_expr scope expr =
  let range = expr.erange in
  match expr.ekind with
  | E_id(v) ->
    {expr with ekind = E_id (find_in_scope scope range v)}

  | E_attr (obj, attr) ->
    {expr with ekind = E_attr (translate_expr scope obj, attr)}

  | E_call (f, args, keywords) ->
    {expr with ekind = E_call (
         translate_expr scope f,
         List.map (translate_expr scope) args,
         List.map (fun (k, v) -> (k, translate_expr scope v)) keywords
       )
    }

  | E_list elts ->
    {expr with ekind = E_list (List.map (translate_expr scope) elts)}

  | E_index_subscript (obj, index) ->
    {expr with ekind = E_index_subscript (translate_expr scope obj, translate_expr scope index)}

  | E_slice_subscript (obj, lower, upper, step) ->
    {expr with ekind = E_slice_subscript (translate_expr scope obj, translate_expr scope lower, translate_expr scope upper, translate_expr scope step)}

  | E_tuple elts ->
    {expr with ekind = E_tuple (List.map (translate_expr scope) elts)}

  | E_set elts ->
    {expr with ekind = E_set (List.map (translate_expr scope) elts)}

  | E_dict (keys, values) ->
    {expr with ekind = E_dict (List.map (translate_expr scope) keys, List.map (translate_expr scope) values)}

  | E_generator_comp (expr, comprhs) ->
    let comprhs, scope' = List.fold_left translate_comprehension ([], scope) comprhs in
    {expr with ekind = E_generator_comp (translate_expr scope' expr, List.rev comprhs)}

  | E_list_comp (expr, comprhs) ->
    let comprhs, scope' = List.fold_left translate_comprehension ([], scope) comprhs in
    {expr with ekind = E_list_comp (translate_expr scope' expr, List.rev comprhs)}

  | E_set_comp (expr, comprhs) ->
    let comprhs, scope' = List.fold_left translate_comprehension ([], scope) comprhs in
    {expr with ekind = E_set_comp (translate_expr scope' expr, List.rev comprhs)}

  | E_dict_comp (keys, values, comprhs) ->
    let comprhs, scope' = List.fold_left translate_comprehension ([], scope) comprhs in
    {expr with ekind = E_dict_comp (translate_expr scope' keys, translate_expr scope' values, List.rev comprhs)}

  | E_if(test, body, orelse)  ->
    {expr with ekind = E_if (translate_expr scope test, translate_expr scope body, translate_expr scope orelse)}

  | E_yield expr  ->
    {expr with ekind = E_yield (translate_expr scope expr)}

  | E_yield_from expr  ->
    {expr with ekind = E_yield_from (translate_expr scope expr)}

  | E_lambda l ->
    let (globals, lscope) = scope in
    let lambda_parameters = List.map create_new_uid l.lambda_parameters in
    let lambda_defaults = List.map (translate_expr_option scope) l.lambda_defaults in
    let parent_scope = List.filter (fun v -> List.for_all (fun v' -> v.name != v'.name ) lambda_parameters) lscope in
    let new_lscope = lambda_parameters @ parent_scope in

    { expr with
      ekind = E_lambda {
          lambda_body = translate_expr (globals, new_lscope) l.lambda_body;
          lambda_parameters;
          lambda_defaults;
        }
    }

  | E_multi_compare(left, ops, rights) ->
    { expr with
      ekind = E_multi_compare (
          translate_expr scope left,
          ops,
          List.map (translate_expr scope) rights
        );
    }

  | E_binop (left, op, right) ->
    {expr with ekind = E_binop (translate_expr scope left, op, translate_expr scope right)}

  | E_unop (op, operand) ->
    {expr with ekind = E_unop (op, translate_expr scope operand)}

  | E_num _ | E_true | E_false | E_none | E_notimplemented | E_str _ | E_bytes _ | E_ellipsis -> expr

and translate_stmt_option scope = function
  | None -> None
  | Some stmt -> Some (translate_stmt scope stmt)

and translate_expr_option scope = function
  | None -> None
  | Some expr -> Some (translate_expr scope expr)

and translate_except_handler scope range = function
  | (typ, v, body) ->
    (translate_expr_option scope typ, (match v with None -> None | Some v -> Some (find_in_scope scope range v)), translate_stmt scope body)

and translate_comprehension (comprhs, scope) (target, iter, conds) =
  let (globals, lscope) = scope in
  let lscope' =
    let rec aux e =
      match e.ekind with
      | E_id v ->
        let v' = create_new_uid v in
        [v']
      | E_list el
      | E_tuple el ->
        List.map aux el |> List.flatten
      | _ -> assert false
    in
    aux target
  in
  let lscope'' = List.filter (fun v -> not (List.exists (fun v' -> v.name = v'.name) lscope')) lscope in
  let scope' = (globals, lscope'' @ lscope') in
  let comprh' = (translate_expr scope' target, translate_expr scope iter, List.map (translate_expr scope') conds) in
  (comprh' :: comprhs), scope'

and find_in_scope (globals, lscope) range v =
  let search v' = v.name = v'.name in
  try
    List.find search lscope
  with Not_found ->
    try List.find search globals
    with Not_found ->
      Exceptions.panic "Unbounded variable %a at range %a" Pp.print_var v Location.pp_range range

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

(** Visitor of Python AST. *)

open Mopsa
open Ast

(* Assumes: List.length (List.flatten old_struct) = List.length new_els *)
(* Ensures: list list structure is the same between old_struct and the output *)
let recompose (old_struct : 'a list list) (new_els: 'a list) : 'a list list =
  let rec aux (old_struct: 'a list list) (new_els: 'a list) (acc_cur: 'a list) : 'a list list =
    match old_struct with
    | [] ->
      assert(new_els = []);
      assert(acc_cur = []);
      []
    | oldhdl :: oldtll ->
      begin match oldhdl with
      | [] -> List.rev acc_cur :: aux oldtll new_els []
      | ohd :: otl ->
        begin match new_els with
          | [] -> assert false
          | ehd :: etl -> aux (otl :: oldtll) etl (ehd :: acc_cur)
        end
      end
  in aux old_struct new_els []

(* Assumes: there are as many non-none elements in old as they are in news *)
(* Ensures: the structure from old is preserved but with the new values provided in news *)
let fill_some (old: 'a option list) (news: 'b list) : 'b option list =
  List.fold_left (fun (news, acc) old_el ->
      match old_el with
      | None -> (news, None :: acc)
      | Some _ ->
        begin match news with
          | [] -> assert false
          | hdn :: tln -> (tln, Some hdn :: acc)
        end
    ) (news, []) old |> snd |> List.rev



let () =
  register_expr_visitor (fun default exp ->
      match ekind exp with
      | E_py_ll_hasattr(e1, e2) ->
         {exprs = [e1; e2]; stmts = [];},
         (fun parts -> let e1, e2 = match parts.exprs with
                         | [e1; e2] -> e1, e2
                         | _ -> assert false in
                       {exp with ekind = E_py_ll_hasattr(e1, e2)})

      | E_py_ll_getattr(e1, e2) ->
         {exprs = [e1; e2]; stmts = [];},
         (fun parts -> let e1, e2 = match parts.exprs with
                         | [e1; e2] -> e1, e2
                         | _ -> assert false in
                       {exp with ekind = E_py_ll_getattr(e1, e2)})

      | E_py_ll_setattr(e1, e2, Some e3) ->
        {exprs = [e1; e2; e3]; stmts = [];},
        (fun parts -> let e1, e2, e3 = match parts.exprs with
             | [e1; e2; e3] -> e1, e2, e3
             | _ -> assert false in
           {exp with ekind = E_py_ll_setattr(e1, e2, Some e3)})

      | E_py_ll_setattr(e1, e2, None) ->
        {exprs = [e1; e2]; stmts = [];},
        (fun parts -> let e1, e2 = match parts.exprs with
             | [e1; e2; e3] -> e1, e2
             | _ -> assert false in
           {exp with ekind = E_py_ll_setattr(e1, e2, None)})

      | E_py_undefined _ -> leaf exp

      | E_py_object _ -> leaf exp

      | E_py_annot e ->
        {exprs = [e]; stmts = [];},
        (fun parts -> {exp with ekind = E_py_annot (List.hd parts.exprs)})

      | E_py_check_annot (e1, e2) ->
        {exprs = [e1; e2]; stmts = [];},
        (function
          | {exprs = [v1; v2]} -> {exp with ekind = E_py_check_annot(v1, v2)}
          | _ -> assert false
        )


      | E_py_list elts ->
        {exprs = elts; stmts = [];},
        (fun parts -> {exp with ekind = E_py_list(parts.exprs)})

      | E_py_set elts ->
        {exprs = elts; stmts = [];},
        (fun parts -> {exp with ekind = E_py_set(parts.exprs)})

      | E_py_tuple elts ->
        {exprs = elts; stmts = [];},
        (fun parts -> {exp with ekind = E_py_tuple(parts.exprs)})

      | E_py_attribute(obj, attr) ->
        {exprs = [obj]; stmts = [];},
        (fun parts -> {exp with ekind = E_py_attribute(List.hd parts.exprs, attr)})

      | E_py_dict(keys, values) ->
        {exprs = keys @ values; stmts = [];},
        (function
          | {exprs} ->
            let rec nhd n l =
              if n = 0 then []
              else
                match l with
                | hd :: tl -> hd :: (nhd (n - 1) tl)
                | _ -> assert false
            and  ntl n l =
              if n = 0 then l
              else
                match l with
                | _ :: tl -> ntl (n - 1) tl
                | _ -> assert false
            in
            let keys = nhd (List.length keys) exprs
            and values = ntl (List.length keys) exprs
            in
            {exp with ekind = E_py_dict(keys, values)}
        )

      | E_py_index_subscript(obj, index) ->
        {exprs = [obj; index]; stmts = [];},
        (fun parts -> {exp with ekind = E_py_index_subscript(List.hd parts.exprs, List.hd @@ List.tl parts.exprs)})

      | E_py_slice_subscript(obj, a, b, s) ->
        {exprs = [obj; a; s; b]; stmts = [];},
        (function {exprs = [obj; a; s; b]} -> {exp with ekind = E_py_slice_subscript(obj, a, b, s)} | _ -> assert false)

      | E_py_yield(e) ->
        {exprs = [e]; stmts = [];},
        (function {exprs = [e]} -> {exp with ekind = E_py_yield(e)} | _ -> assert false)

      | E_py_yield_from(e) ->
        {exprs = [e]; stmts = [];},
        (function {exprs = [e]} -> {exp with ekind = E_py_yield_from(e)} | _ -> assert false)

      | E_py_if(test, body, orelse) ->
        {exprs = [test; body; orelse]; stmts = [];},
        (function {exprs = [test; body; orelse]} -> {exp with ekind = E_py_if(test, body, orelse)} | _ -> assert false)

      | E_py_list_comprehension(e, comprhs)
      | E_py_set_comprehension(e, comprhs)
      | E_py_generator_comprehension(e, comprhs) ->
        let open Universal.Ast in
        let iters, targets, conds = comprhs |> List.fold_left (fun (acc1, acc2, acc3) (target, iter, conds) ->
            (* todo: do not change conds into stmts, use the structure of comprhs in the rebuild function to know if sth is an iter or a compr *)
            iter :: acc1, target :: acc2, (Universal.Ast.mk_block (List.map (fun x -> Universal.Ast.mk_expr_stmt x exp.erange) conds) exp.erange) :: acc3
          ) ([], [], [])
        in
        {exprs = e :: iters; stmts = conds},
        (function
          | {exprs = e :: iters; stmts = conds} ->
            let comprhs =
              List.combine (List.combine iters targets) conds |>
              List.fold_left (fun acc ((iter, target), conds) ->
                  (target, iter,
                   match skind conds with
                   | S_block (l,_) -> List.map
                                    (fun x -> match skind x with
                                       | S_expression e -> e
                                       | _ -> assert false) l
                   | _ -> assert false
                  ) :: acc
                ) []
            in
            begin
              match ekind exp with
              | E_py_list_comprehension _ -> {exp with ekind = E_py_list_comprehension(e, comprhs)}
              | E_py_set_comprehension _ -> {exp with ekind = E_py_set_comprehension(e, comprhs)}
              | E_py_generator_comprehension _ -> {exp with ekind = E_py_generator_comprehension(e, comprhs)}
              | _ -> assert false
            end
          | _ -> assert false
        )

      | E_py_dict_comprehension(k, v, comprhs) ->
        let iters, targets = comprhs |> List.fold_left (fun acc (target, iter, conds) ->
            match conds with
            | [] ->
              iter :: fst acc, target :: snd acc
            | _ -> assert false
          ) ([], [])
        in
        {exprs = k :: v :: iters; stmts = []},
        (function
          | {exprs = k :: v :: iters} ->
            let comprhs =
              List.combine iters targets |>
              List.fold_left (fun acc (iter, target) ->
                  (target, iter, []) :: acc
                ) []
            in
            {exp with ekind = E_py_dict_comprehension(k, v, comprhs)}
          | _ -> assert false
        )


      | E_py_call(f, args, keywords) ->
        {exprs = f :: args @ (List.map snd keywords); stmts = [];},
        (fun parts ->
           let f = List.hd parts.exprs in
           let args, kwvals = Utils.partition_list_by_length (List.length args) (List.tl parts.exprs) in
           let keywords = List.combine keywords kwvals |>
                          List.map (fun ((k, _), v) -> (k, v))
           in
           {exp with ekind = E_py_call(f, args, keywords)})

      | E_py_bytes _ -> leaf exp

      | E_py_lambda(l) ->
        let defaults = l.py_lambda_defaults |>
                       List.fold_left (fun acc -> function
                           | None -> acc
                           | Some e -> e :: acc
                         ) [] |>
                       List.rev
        in
        {exprs = l.py_lambda_body :: defaults; stmts = [];},
        (fun parts ->
           let body = List.hd parts.exprs and defaults = List.tl parts.exprs in
           let defaults, _ = l.py_lambda_defaults |>
                          List.fold_left (fun (acc, defaults) -> function
                              | None -> (None :: acc, defaults)
                              | Some e ->
                                let e = List.hd defaults in
                                (Some e :: acc, List.tl defaults)
                            ) ([], defaults)
           in
           let l = { l with py_lambda_body = body; py_lambda_defaults = List.rev defaults} in
           {exp with ekind = E_py_lambda(l)}
        )


      | E_py_multi_compare(left, ops, rights) ->
        {exprs = left :: rights; stmts = [];},
        (function
          | {exprs = left :: rights} -> {exp with ekind = E_py_multi_compare(left, ops, rights)}
          | _ -> assert false
        )

      | _ -> default exp
    );

  register_stmt_visitor (fun default stmt ->
      match skind stmt with
      | S_py_class(cls) ->
        {exprs = cls.py_cls_bases; stmts = [cls.py_cls_body];},
        (function {exprs = bases; stmts = [body]} -> {stmt with skind = S_py_class({cls with py_cls_body = body; py_cls_bases = bases})} | _ -> assert false)
      | S_py_function(func) ->
        (* FIXME: filter_map in 4.08 *)
        let filter_map f l =
          List.fold_left (fun acc el ->
              match f el with
              | None -> acc
              | Some v -> v :: acc
            ) [] l |> List.rev in
        let defaults = filter_map (fun x -> x) func.py_func_defaults in
        let decors = func.py_func_decors in
        let types_in = filter_map (fun x -> x) func.py_func_types_in in
        let type_out = match func.py_func_type_out with | None -> [] | Some x -> [x] in
        let all = [defaults; decors; types_in; type_out] in
        let allf = List.flatten all in
        {exprs = allf; stmts = [func.py_func_body];},
        (function
          | {exprs; stmts = [body]} ->
            let nall = recompose all exprs in
            begin match nall with
              | [def; dec; tyin; tyout] ->
                let ndefaults = fill_some func.py_func_defaults def in
                let ndecors = dec in
                let ntypes_in = fill_some func.py_func_types_in tyin in
                let ntype_out = List.hd @@ fill_some [func.py_func_type_out] tyout in
                {stmt with skind = S_py_function({func with py_func_defaults = ndefaults;
                                                            py_func_decors = ndecors;
                                                            py_func_types_in = ntypes_in;
                                                            py_func_type_out = ntype_out;
                                                            py_func_body = body})}
              | _ -> assert false end
          | _ -> assert false
        )
      | S_py_raise(None) -> leaf stmt
      | S_py_raise(Some e) ->
        {exprs = [e]; stmts = [];},
        (fun parts -> {stmt with skind = S_py_raise(Some (List.hd parts.exprs))})
      | S_py_try(body, excepts, orelse, finally) ->
        let py_excs, py_bodies = List.fold_left (fun (acce, accb) el ->
            match el.py_excpt_type with
            | None -> (acce, el.py_excpt_body::accb)
            | Some e -> (e::acce, el.py_excpt_body::accb)) ([], []) excepts
        in
        let py_excs, py_bodies = List.rev py_excs, List.rev py_bodies in
        {exprs = py_excs; stmts = body::orelse::finally::py_bodies;},
        (function
          | {exprs; stmts = body' :: orelse' :: finally' :: bodies} ->
            let opy_excs = fill_some (List.map (fun x -> x.py_excpt_type) excepts) exprs in
            let excepts' = List.rev @@ List.fold_left2 (fun acc (oty, stmt) except ->
                {
                  py_excpt_type = oty;
                  py_excpt_name = except.py_excpt_name;
                  py_excpt_body = stmt
                } :: acc
              ) [] (List.combine opy_excs py_bodies) excepts in
            {stmt with skind = S_py_try(body', excepts', orelse', finally')}
          | _ -> assert false)



      | S_py_while(test, body, orelse) ->
        {exprs = [test]; stmts = [body; orelse];},
        (function
          | {exprs = [test']; stmts = [body'; orelse']} -> {stmt with skind = S_py_while(test', body',orelse')}
          | _ -> assert false)
      | S_py_if(test, sthen, selse) ->
        {exprs = [test]; stmts = [sthen; selse];},
        (function
          | {exprs = [test']; stmts = [sthen'; selse']} -> {stmt with skind = S_py_if(test', sthen', selse')}
          | _ -> assert false)

      | S_py_for(target, iter, body, orelse) ->
        {exprs = iter::target::[]; stmts = [body; orelse]},
        (function
          | {exprs = iter::target::[]; stmts = [body; orelse]} -> {stmt with skind = S_py_for(target, iter, body, orelse)}
          | _ -> assert false)

      | S_py_multi_assign(targets, e) ->
        {exprs = [e]; stmts = []},
        (function {exprs = [e]} -> {stmt with skind = S_py_multi_assign(targets, e)} | _ -> assert false)

      | S_py_aug_assign(x, op, e) ->
        {exprs = [x; e]; stmts = []},
        (function
          | {exprs = [x; e]} -> {stmt with skind = S_py_aug_assign(x, op, e)}
          | _ -> assert false
        )

      | S_py_annot(x, typ) ->
        {exprs = [x; typ]; stmts = []},
        (function
          | {exprs = [x; typ]} -> {stmt with skind = S_py_annot(x, typ)}
          | _ -> assert false
        )
      | S_py_check_annot(x, typ) ->
        {exprs = [x; typ]; stmts = []},
        (function
          | {exprs = [x; typ]} -> {stmt with skind = S_py_check_annot(x, typ)}
          | _ -> assert false
        )

      | S_py_import _ -> leaf stmt
      | S_py_import_from _ -> leaf stmt

      | S_py_delete(e) ->
        {exprs = [e]; stmts = [];},
        (fun parts -> {stmt with skind = S_py_delete(List.hd parts.exprs)})

      | S_py_assert(test, None) ->
        {exprs = [test]; stmts = [];},
        (function
          | {exprs = [test]} -> {stmt with skind = S_py_assert(test, None)}
          | _ -> assert false
        )

      | S_py_assert(test, Some msg) ->
        {exprs = [test; msg]; stmts = [];},
        (function
          | {exprs = [test; msg]} -> {stmt with skind = S_py_assert(test, Some msg)}
          | _ -> assert false
        )

      | S_py_with(ctx, None, body) ->
        {exprs = [ctx]; stmts = [body];},
        (function
          | {exprs = [ctx]; stmts = [body]} -> {stmt with skind = S_py_with(ctx, None, body)}
          | _ -> assert false
        )

      | S_py_with(ctx, Some target, body) ->
        {exprs = [ctx]; stmts = [body]},
        (function
          | {exprs = [ctx]; stmts = [body]} -> {stmt with skind = S_py_with(ctx, Some target, body)}
          | _ -> assert false
        )

      | _ -> default stmt
    );
  ()

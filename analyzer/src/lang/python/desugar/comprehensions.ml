(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(** Inliner of list comprehensions. This translates
   comprehensions into for loops. While this is not the best in terms
   of precision, due to the widenings we may have to do afterwards,
   it's a generic, rewriting-based approach that may be helpful *)


open Framework.Essentials
open Framework.Ast
open Universal.Ast
open Ast

module Domain =
  struct

    type _ domain += D_python_desugar_comprehensions : unit domain

    let id = D_python_desugar_comprehensions
    let name = "python.desugar.comprehensions"
    let identify : type a. a domain -> (unit, a) eq option = function
      | D_python_desugar_comprehensions -> Some Eq
      | _ -> None

    let debug fmt = Debug.debug ~channel:name fmt

    let exec_interface = {export = []; import = []}
    let eval_interface = {export = [Framework.Zone.Z_any, Framework.Zone.Z_any]; import = []}

    let init _ _ flow = Some flow
    let eval zs exp man flow =
      let range = erange exp in
      match ekind exp with
      | E_py_list_comprehension (expr, comprehensions) ->
         let tmp_acc = mk_tmp () in
         let acc_var = mk_var tmp_acc range in
         let rec unfold_lc aux_compr = match aux_compr with
           | [] ->
              let list = Addr.find_builtin "list" in
              let listappend = mk_py_object (Addr.find_builtin_attribute list "append") range in
              mk_stmt (S_expression (mk_py_call listappend [acc_var; expr] range)) range
           | (target, iter, conds)::tl ->
              (* todo: mk_remove target in the end *)
              let i_conds = List.rev conds in
              let empty_stmt = mk_stmt (Universal.Ast.S_block []) range in
              let if_stmt = List.fold_left (fun acc cond ->
                                mk_stmt (Universal.Ast.S_if (cond, acc, empty_stmt)) range
                              ) (unfold_lc tl) i_conds in
              mk_stmt (S_py_for(target, iter,
                                if_stmt,
                                empty_stmt)) range in
         let clean_targets = List.fold_left (fun acc (target, _, _) -> match ekind target with
                                                                       | E_var (v, _) -> (mk_remove_var v range)::acc
                                                                       | _ -> Exceptions.panic "Comprehension: target %a is not a variable...@\n" pp_expr exp) [] comprehensions in
         let stmt = mk_block ((mk_assign acc_var (mk_expr (E_py_list []) range) range) :: (unfold_lc comprehensions) :: clean_targets) range in
         debug "Rewriting %a into %a@\n" pp_expr exp pp_stmt stmt;
         man.exec stmt flow |>
           man.eval acc_var |>
           Eval.add_cleaners [mk_remove_var tmp_acc range] |>
           OptionExt.return

      | _ -> None

    let exec _ _ _ _ = None

    let ask _ _ _ = None

  end

let () =
  Framework.Domains.Stateless.register_domain (module Domain)
(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(** Unittest library. *)

open Framework.Domains.Stateless
open Framework.Domains
open Framework.Manager
open Framework.Lattice
open Framework.Eval
open Framework.Flow
open Framework.Ast
open Universal.Ast
open Ast
open Addr

let name = "python.libs.unittest"
let debug fmt = Debug.debug ~channel:name fmt


(*==========================================================================*)
(**                               {2 Domain }                               *)
(*==========================================================================*)


module Domain =
struct

  let get_name addr =
    match addr.addr_kind with
    | A_py_class(C_user cls, _) -> cls.py_cls_var.vname
    | A_py_function (F_user f) -> f.py_func_var.vname
    | _ -> assert false

  (*==========================================================================*)
  (**                       {2 Transfer functions }                           *)
  (*==========================================================================*)

  let eval man ctx exp flow =
    let range = exp.erange in
    match ekind exp with
    | E_py_call({ekind = E_addr ({addr_kind = A_py_function (F_builtin "unittest.main")})}, [], []) ->
      (* Search for all classes that inherit from TestCase *)
      let test_cases = man.ask ctx Universal.Heap.Query.QAllocatedAddresses flow |>
                       Option.none_to_exn |>
                       List.filter (fun addr ->
                           match addr.addr_kind with
                           | A_py_class(cls, {addr_kind = A_py_class (C_builtin "unittest.TestCase", _)} :: _) -> true
                           | _ -> false
                         ) |>
                       List.map (fun addr ->
                           match addr.addr_kind with
                           | A_py_class(C_user cls, _) -> addr, cls
                           | _ -> assert false
                         )
      in
      (* Instantiate the test classes *)
      let selfs, flow =
        List.fold_left (fun (selfs, flow) (addr, cls) ->
            (* Allocate an instance of the test class *)
            Addr.eval_alloc_instance man ctx addr None range flow |>
            oeval_fold (fun (selfs, _) (addr, flow, _) ->
                match addr with
                | Some self -> (self, cls) :: selfs, flow
                | None -> assert false
              ) (selfs, flow)
          ) ([], flow) test_cases
      in

      (* Fold over the class methods and bind them to self *)
      let tests =
        List.fold_left (fun tests (self, cls) ->
            List.fold_left (fun tests v ->
                let stmt = mk_stmt (S_expression (mk_py_call (mk_py_addr_attr self v.vname range) [] range)) range in
                (v.vname, stmt) :: tests
              ) tests cls.py_cls_static_attributes
          ) [] selfs
      in

      let flow = man.exec ctx (mk_stmt (Universal.Ast.S_unit_tests ("file", tests)) range) flow in
      oeval_singleton (Some (mk_py_none range), flow, [])


    | E_py_call({ekind = E_addr ({addr_kind = A_py_function (F_builtin "unittest.TestCase.assertEqual")})}, [test; arg1; arg2], []) ->
      Mopsa.check man ctx (mk_binop arg1 O_eq arg2 range) range flow

    | E_py_call({ekind = E_addr ({addr_kind = A_py_function (F_builtin "unittest.TestCase.assertTrue")})}, [test; cond], []) ->
      Mopsa.check man ctx cond range flow

    | E_py_call({ekind = E_addr ({addr_kind = A_py_function (F_builtin "unittest.TestCase.assertFalse")})}, [test; cond], []) ->
      Mopsa.check man ctx (mk_not cond range) range flow

    | E_py_call({ekind = E_addr ({addr_kind = A_py_function (F_builtin "unittest.TestCase.assertIs")})}, [test; arg1; arg2], []) ->
      Mopsa.check man ctx (mk_binop arg1 O_py_is arg2 range) range flow

    | E_py_call({ekind = E_addr ({addr_kind = A_py_function (F_builtin "unittest.TestCase.assertIsNot")})}, [test; arg1; arg2], []) ->
      Mopsa.check man ctx (mk_binop arg1 O_py_is_not arg2 range) range flow

    | E_py_call({ekind = E_addr ({addr_kind = A_py_function (F_builtin "unittest.TestCase.assertIn")})}, [test; arg1; arg2], []) ->
      Mopsa.check man ctx (mk_binop arg1 O_py_in arg2 range) range flow

    | E_py_call({ekind = E_addr ({addr_kind = A_py_function (F_builtin "unittest.TestCase.assertNotIn")})}, [test; arg1; arg2], []) ->
      Mopsa.check man ctx (mk_binop arg1 O_py_not_in arg2 range) range flow

    | E_py_call({ekind = E_addr ({addr_kind = A_py_function (F_builtin "unittest.TestCase.assertIsInstance")})}, [test; arg1; arg2], []) ->
      Mopsa.check man ctx (Utils.mk_builtin_call "isinstance" [arg1; arg2] range) range flow

    | E_py_call({ekind = E_addr ({addr_kind = A_py_function (F_builtin "unittest.TestCase.assertNotIsInstance")})}, [test; arg1; arg2], []) ->
      Mopsa.check man ctx (mk_not (Utils.mk_builtin_call "isinstance" [arg1; arg2] range) range) range flow

    | E_py_call({ekind = E_addr ({addr_kind = A_py_function (F_builtin f)})}, _, _)
      when Addr.is_builtin_class_function "unittest.TestCase" f ->
      Framework.Exceptions.panic "unittest.TestCase function %s not implemented" f

    | _ -> None

  let init _ ctx _ flow = ctx, flow
  let exec man ctx stmt flow = None
  let ask _ _ _ _ = None

end




(*==========================================================================*)
(**                             {2 Setup }                                  *)
(*==========================================================================*)


let setup () =
  Stateless.register_domain name (module Domain)
(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(** MOPSA Python library. *)

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

let name = "python.libs.mopsa"
let debug fmt = Debug.debug ~channel:name fmt


let check man ctx cond range flow =
  let flow = man.exec ctx (mk_stmt (Universal.Ast.S_assert cond) range) flow in
  oeval_singleton (Some (mk_py_none range), flow, [])


(*==========================================================================*)
(**                               {2 Domain }                               *)
(*==========================================================================*)


module Domain =
struct


  (*==========================================================================*)
  (**                       {2 Transfer functions }                           *)
  (*==========================================================================*)


  let exec man ctx stmt flow = None

  let init _ ctx _ flow = ctx, flow

  let eval man ctx exp flow =
    let range = erange exp in
    match ekind exp with
    | E_py_call ({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "mopsa.random_int")}, _)}, [
        {ekind = E_constant (C_int l)}; {ekind = E_constant (C_int u)}
      ], []) ->
      oeval_singleton (Some (mk_py_z_interval l u range), flow, [])

    | E_py_call ({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "mopsa.random_int")}, _)}, [l; u], []) ->
      begin
        match ekind l, ekind u with
        | E_constant (C_int l), E_constant (C_int u) -> oeval_singleton (Some (mk_py_z_interval l u range), flow, [])
        | _ ->
          let tmp = mktmp () in
          let l = Utils.mk_builtin_call "int" [l] range in
          let u = Utils.mk_builtin_call "int" [u] range in
          let flow = man.exec ctx (mk_assign (mk_var tmp range) (mk_top T_int range) range) flow |>
                     man.exec ctx (mk_assume (mk_in (mk_var tmp range) l u range) range)
          in
          oeval_singleton (Some (mk_var tmp range), flow, [mk_remove_var tmp range])
      end

    | E_py_call ({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "mopsa.random_int")}, _)}, [], []) ->
      oeval_singleton (Some (mk_py_top T_int range), flow, [])

    | E_py_call ({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "mopsa.random_float")}, _)}, [l; u], []) ->
      begin
        match ekind l, ekind u with
        | E_constant (C_float l), E_constant (C_float u) -> oeval_singleton (Some (mk_py_float_interval l u range), flow, [])
        | E_constant (C_float l), E_constant (C_int u) -> oeval_singleton (Some (mk_py_float_interval l (Z.to_float u) range), flow, [])
        | E_constant (C_int l), E_constant (C_float u) -> oeval_singleton (Some (mk_py_float_interval (Z.to_float l) u range), flow, [])
        | E_constant (C_int l), E_constant (C_int u) -> oeval_singleton (Some (mk_py_float_interval (Z.to_float l) (Z.to_float u) range), flow, [])
        | _ ->
          let tmp = mktmp () in
          let l = Utils.mk_builtin_call "float" [l] range in
          let u = Utils.mk_builtin_call "float" [u] range in
          let flow = man.exec ctx (mk_assign (mk_var tmp range) (mk_top T_float range) range) flow |>
                     man.exec ctx (mk_assume (mk_in (mk_var tmp range) l u range) range)
          in
          oeval_singleton (Some (mk_var tmp range), flow, [mk_remove_var tmp range])
      end

    | E_py_call ({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "mopsa.random_float")}, _)}, [], []) ->
      oeval_singleton (Some (mk_py_top T_float range), flow, [])

    | E_py_call ({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "mopsa.random_bool")}, _)}, [], []) ->
      oeval_singleton (Some (mk_py_top T_bool range), flow, [])

    | E_py_call ({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "mopsa.random_string")}, _)}, [], []) ->
      oeval_singleton (Some (mk_py_top T_string range), flow, [])

    (* Calls to mopsa.assert_equal function *)
    | E_py_call(
        {ekind = E_py_object ({addr_kind = A_py_function (F_builtin "mopsa.assert_equal")}, _)},
        [x; y], []
      ) ->
      let range = erange exp in
      check man ctx (mk_binop x O_eq y (tag_range range "eq")) range flow

    (* Calls to mopsa.assert_true function *)
    | E_py_call(
        {ekind = E_py_object ({addr_kind = A_py_function (F_builtin "mopsa.assert_true")}, _)},
        [x], []
      ) ->
      let range = erange exp in
      check man ctx x range  flow

    (* Calls to mopsa.assert_false function *)
    | E_py_call(
        {ekind = E_py_object ({addr_kind = A_py_function (F_builtin "mopsa.assert_false")}, _)},
        [x], []
      )  ->
      let range = erange exp in
      check man ctx (mk_not x (tag_range range "not")) range flow

    | E_py_call(
        {ekind = E_py_object ({addr_kind = A_py_function (F_builtin "mopsa.assert_exists")}, _)},
        [cond], []
      )  ->
      let stmt = {skind = S_simple_assert(cond,false,true); srange = exp.erange} in
      let flow = man.exec ctx stmt flow in
      oeval_singleton (Some (mk_py_int 0 exp.erange), flow, [])

    | E_py_call(
        {ekind = E_py_object ({addr_kind = A_py_function (F_builtin "mopsa.assert_safe")}, _)},
        [], []
      )  ->
      begin
        let error_env = man.flow.fold (fun acc env -> function
            | Flows.Exceptions.TExn _ -> man.env.join acc env
            | _ -> acc
          ) man.env.bottom flow in
        let exception BottomFound in
        try
          let cond =
            match man.flow.is_cur_bottom flow, man.env.is_bottom error_env with
            | false, true -> mk_one
            | true, false -> mk_zero
            | false, false -> mk_int_interval 0 1
            | true, true -> raise BottomFound
          in
          let stmt = mk_assert (cond exp.erange) exp.erange in
          let cur = man.flow.get TCur flow in
          let flow = man.flow.set TCur man.env.top flow |>
                     man.exec ctx stmt |>
                     man.flow.set TCur cur
          in
          oeval_singleton (Some (mk_py_int 0 exp.erange), flow, [])
        with BottomFound ->
          oeval_singleton (None, flow, [])
      end

    | E_py_call(
        {ekind = E_py_object ({addr_kind = A_py_function (F_builtin "mopsa.assert_unsafe")}, _)},
        [], []
      )  ->
      begin
        let error_env = man.flow.fold (fun acc env -> function
            | Flows.Exceptions.TExn _ -> man.env.join acc env
            | _ -> acc
          ) man.env.bottom flow in
        let cond =
          match man.flow.is_cur_bottom flow, man.env.is_bottom error_env with
          | false, true -> mk_zero
          | true, false -> mk_one
          | false, false -> mk_int_interval 0 1
          | true, true -> mk_zero
        in
        let stmt = mk_assert (cond exp.erange) exp.erange in
        let cur = man.flow.get TCur flow in
        let flow = man.flow.set TCur man.env.top flow in
        let flow = man.exec ctx stmt flow |>
                   man.flow.filter (fun _ -> function Flows.Exceptions.TExn _ -> false | _ -> true) |>
                   man.flow.set TCur cur
        in
        oeval_singleton (Some (mk_py_int 0 exp.erange), flow, [])
      end

    | E_py_call(
        {ekind = E_py_object ({addr_kind = A_py_function (F_builtin "mopsa.assert_exception")}, _)},
        [{ekind = E_py_object cls}], []
      )  ->
      begin
        debug "begin assert_exception";
        let this_error_env = man.flow.fold (fun acc env -> function
            | Flows.Exceptions.TExn exn when Addr.isinstance exn cls -> man.env.join acc env
            | _ -> acc
          ) man.env.bottom flow in
        let cond =
          match man.flow.is_cur_bottom flow, man.env.is_bottom this_error_env with
          | true, false -> mk_one
          | _, true -> mk_zero
          | false, false ->  mk_int_interval 0 1
        in
        let stmt = mk_assert (cond exp.erange) exp.erange in
        let cur = man.flow.get TCur flow in
        let flow = man.flow.set TCur man.env.top flow in
        let flow = man.exec ctx stmt flow |>
                   man.flow.filter (fun _ -> function Flows.Exceptions.TExn exn when Addr.isinstance exn cls -> false | _ -> true) |>
                   man.flow.set TCur cur
        in
        oeval_singleton (Some (mk_py_int 0 exp.erange), flow, [])
      end


    | E_py_call(
        {ekind = E_py_object ({addr_kind = A_py_function (F_builtin "mopsa.assert_exception_exists")}, _)},
        [{ekind = E_py_object cls}], []
      )  ->
      begin
        let error_env = man.flow.fold (fun acc env -> function
            | Flows.Exceptions.TExn exn when Addr.isinstance exn cls -> man.env.join acc env
            | _ -> acc
          ) man.env.bottom flow in
        let cur = man.flow.get TCur flow in
        let cur' = if man.env.is_bottom cur then man.env.top else cur in
        let cond = if man.env.is_bottom error_env then mk_zero exp.erange else mk_one exp.erange in
        let stmt = mk_assert cond exp.erange in
        let flow' = man.flow.set TCur cur' flow |>
                   man.exec ctx stmt |>
                   man.flow.filter (fun _ -> function Flows.Exceptions.TExn exn when Addr.isinstance exn cls -> false | _ -> true) |>
                   man.flow.set TCur cur
        in
        oeval_singleton (Some (mk_py_int 0 exp.erange), flow', [])
      end


    | _ ->
      None

  let ask _ _ _ _ = None

end



(*==========================================================================*)
(**                          {2 Decorators}                                 *)
(*==========================================================================*)


let is_stub_fundec = function
  | {py_func_decors = [{ekind = E_py_attribute({ekind = E_var {vname = "mopsa"}}, "stub")}]} -> true
  | _ -> false

let is_builtin_fundec = function
  | {py_func_decors = [{ekind = E_py_call({ekind = E_py_attribute({ekind = E_var {vname = "mopsa"}}, "builtin")}, _, [])}]} -> true
  | _ -> false

let is_builtin_clsdec = function
  | {py_cls_decors = [{ekind = E_py_call({ekind = E_py_attribute({ekind = E_var {vname = "mopsa"}}, "builtin")}, _, [])}]} -> true
  | _ -> false

let is_unsupported_fundec = function
  | {py_func_decors = [{ekind = E_py_attribute({ekind = E_var {vname = "mopsa"}}, "unsupported")}]} -> true
  | _ -> false

let is_unsupported_clsdec = function
  | {py_cls_decors = [{ekind = E_py_attribute({ekind = E_var {vname = "mopsa"}}, "unsupported")}]} -> true
  | _ -> false


let builtin_fundec_name = function
  | {py_func_decors = [{ekind = E_py_call({ekind = E_py_attribute({ekind = E_var {vname = "mopsa"}}, "builtin")}, [{ekind = E_constant (C_string name)}], [])}]} -> name
  | _ -> raise Not_found

let builtin_clsdec_name = function
  | {py_cls_decors = [{ekind = E_py_call({ekind = E_py_attribute({ekind = E_var {vname = "mopsa"}}, "builtin")}, [{ekind = E_constant (C_string name)}], [])}]} -> name
  | _ -> raise Not_found


(*==========================================================================*)
(**                             {2 Setup }                                  *)
(*==========================================================================*)


let setup () =
  Stateless.register_domain name (module Domain)

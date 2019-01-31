(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(** Handling of assert statements. *)

open Mopsa
open Framework.Ast
open Universal.Ast
open Ast
open Zone

module Domain =
  struct

    type _ domain += D_python_desugar_assert : unit domain

    let id = D_python_desugar_assert
    let name = "python.desugar.assert"
    let identify : type a. a domain -> (unit, a) eq option = function
      | D_python_desugar_assert -> Some Eq
      | _ -> None

    let debug fmt = Debug.debug ~channel:name fmt

    let exec_interface = {export = [Zone.Z_py]; import = []}
    let eval_interface = {export = []; import = []}

    let init _ _ flow = OptionExt.return flow

    let exec zone stmt man flow =
      let range = srange stmt in
      match skind stmt with
      (* S⟦ assert(e, msg) ⟧ *)
      | S_py_assert ({ekind = E_constant (C_bool true)}, msg)->
         Post.of_flow flow |> OptionExt.return

      | S_py_assert ({ekind = E_constant (C_bool false)}, msg)->
         man.exec (Utils.mk_builtin_raise "AssertionError" range) flow |> Post.of_flow |> OptionExt.return

      | S_py_assert (e, msg)->
         man.eval e flow |>
           Post.bind man @@
             (fun e flow ->
               let ok_case = man.exec (mk_assume e (tag_range range "safe case assume")) flow in

               let fail_case =
                 debug "checking fail";
                 let flow = man.exec (mk_assume (mk_not e e.erange) (tag_range range "fail case assume")) flow in
                 if Flow.is_bottom man flow then
                   let _ = debug "no fail" in
                   Flow.bottom (Flow.get_all_annot flow)
                 else
                   man.exec (
                       Utils.mk_builtin_raise "AssertionError" (tag_range range "fail case raise")
                     ) flow
               in
               Flow.join man ok_case fail_case
               |> Post.of_flow
             )
         |> OptionExt.return

      | _ -> None

    let eval _ _ _ _ = None


    let ask _ _ _ = None

end

let () =
  Framework.Domains.Stateless.register_domain (module Domain)

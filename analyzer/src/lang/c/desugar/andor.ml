(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(** And and Or lazy evaluations *)

open Framework.Essentials
open Ast

module Domain : Framework.Domains.Stateless.S =
struct


  (** Domain identification *)
  (** ===================== *)

  type _ domain += D_c_desugar_andor : unit domain
  let id = D_c_desugar_andor

  let identify : type a. a domain -> (unit, a) eq option =
    function
    | D_c_desugar_andor -> Some Eq
    | _ -> None

  let name = "c.desugar.andor"
  let debug fmt = Debug.debug ~channel:name fmt

  let exec_interface = {
    import = [];
    export = [Zone.Z_c];
  }

  let eval_interface = {
    import = [Framework.Zone.Z_top, Framework.Zone.Z_top];
    export = [Framework.Zone.Z_top, Framework.Zone.Z_top]
  }

  let exec _ _ _ = None

  let eval exp man flow =
    match ekind exp with
    | E_binop(O_c_and, e1, e2) ->
      begin
        man.eval e1 flow |> Eval.bind @@ fun e1 flow ->
        Eval.assume
          e1
          ~fthen:(fun true_flow -> man.eval e2 true_flow)
          ~felse:(fun false_flow -> Eval.singleton (Universal.Ast.mk_z Z.zero exp.erange) false_flow)
          man flow
      end |> Option.return

    | E_binop(O_c_or, e1, e2) ->
      begin
        man.eval e1 flow |> Eval.bind @@ fun e1 flow ->
        Eval.assume
          e1
          ~fthen:(fun true_flow -> Eval.singleton (Universal.Ast.mk_z Z.one exp.erange) true_flow)
          ~felse:(fun false_flow -> man.eval e2 false_flow)
          man flow
      end |> Option.return

    | _ -> None

  let ask _ _ _ = None
  let init _ _ _ = None

end

let () =
  Framework.Domains.Stateless.register_domain (module Domain)

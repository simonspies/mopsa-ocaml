(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(** Intra-procedural iterator handles blocks, assignments and tests *)

open Framework.Essentials
open Ast


module Domain : Framework.Domains.Stateless.S =
struct

  type _ domain += D_universal_intraproc : unit domain

  let id = D_universal_intraproc
  let name = "universal.iterators.intraproc"
  let identify : type a. a domain -> (unit, a) eq option =
    function
    | D_universal_intraproc -> Some Eq
    | _ -> None

  let debug fmt = Debug.debug ~channel:name fmt

  let zone = Zone.Z_universal
  let import_exec = []
  let import_eval = []

  let init prog man flow = None

  let exec stmt man flow =
    match skind stmt with
    | S_expression(e) ->
      Some (
        man.eval e flow |>
        Post.bind man @@ fun e flow ->
        Post.singleton flow
      )

    | S_block(block) ->
      Some (
        List.fold_left (fun acc stmt -> man.exec stmt acc) flow block |>
        Post.singleton
      )

    | S_if(cond, s1, s2) ->
      let range = srange stmt in
      let flow1 = man.exec (mk_assume cond range) flow |>
                  man.exec s1
      in
      let flow2 = man.exec (mk_assume (mk_not cond range) range) flow |>
                  man.exec s2
      in
      (* FIXME: propagate annotations in flow insensitive way *)
      let flow' = Flow.join man flow1 flow2 in
      Some (Post.singleton flow')

    | _ -> None
      
  let eval exp man flow = None

  let ask query man flow = None

end

let () =
  Framework.Domains.Stateless.register_domain (module Domain)

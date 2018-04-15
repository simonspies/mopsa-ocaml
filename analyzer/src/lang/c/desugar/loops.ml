(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(** Interpreter of for and do-while loops. *)

open Framework.Flow
open Framework.Domains
open Framework.Manager
open Framework.Domains.Stateless
open Framework.Ast
open Ast

let name = "c.desugar.loops"
let debug fmt = Debug.debug ~channel:name fmt

module Domain =
struct

  (*==========================================================================*)
                        (** {2 Transfer functions} *)
  (*==========================================================================*)

  let init prog man ctx flow = ctx, flow

  let exec stmt man ctx flow =
    match skind stmt with
    | S_c_for(init, cond, incr, body) ->
      let range = stmt.srange in
      let stmt = Universal.Ast.(
          mk_block [
            init;
            mk_stmt (S_while (
                (match cond with None -> mk_one range | Some e -> e),
                (match incr with None -> body | Some e -> mk_block [body; mk_stmt (S_expression e) e.erange] body.srange)
              )) range
          ] range
        )
      in
      man.exec stmt ctx flow |>
      return

    | S_c_do_while(body, cond) -> assert false
    | _ -> None

  let eval exp man ctx flow = None

  let ask _ _ _ _  = None

  end

let setup () =
  register_domain name (module Domain)
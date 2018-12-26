(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(** array access and structure member access transformation to pointer
   arithmetic*)

open Mopsa
open Ast
open Zone


(** {2 Domain definition} *)
(** ===================== *)

let name = "universal.heap.recency"
let debug fmt = Debug.debug ~channel:name fmt

module Domain =
struct

  (** Lattice definition *)
  (** ================== *)

  include Pool

  let is_bottom _ = false

  let print fmt pool =
    Format.fprintf fmt "heap: @[%a@]@\n"
      Pool.print pool

  (** Domain identification *)
  (** ===================== *)

  type _ domain += D_u_heap_recency : t domain
  let id = D_u_heap_recency
  let name = "universal.heap.recency"
  let identify : type a. a domain -> (t, a) eq option =
    function
    | D_u_heap_recency -> Some Eq
    | _ -> None

  let debug fmt = Debug.debug ~channel:name fmt

  (** Zoning definition *)
  (** ================= *)

  let exec_interface = {export = [Z_u_heap]; import = []}
  let eval_interface = {export = [Z_u_heap, Z_any]; import = []}

  (** Initialization *)
  (** ============== *)

  let init prog man flow =
    Some (
      Flow.set_domain_cur empty man flow |>
      Flow.set_annot KAddr Equiv.empty
    )


  (** Post-conditions *)
  (** *************** *)

  let exec zone stmt man flow =
    match skind stmt with
    (* 𝕊⟦ free(addr); ⟧ *)
    | S_free_addr addr ->
      let flow', mode =
        if is_old addr flow then flow, WEAK
        else Flow.map_domain_env T_cur (remove addr) man flow, STRONG
      in
      let stmt' = mk_remove (mk_addr addr ~mode stmt.srange) stmt.srange in
      man.exec stmt' flow' |>
      Post.return

    | _ -> None


  (** Evaluations *)
  (** *********** *)

  let eval zone expr man flow =
    match ekind expr with
    | E_alloc_addr(addr_kind) ->
      begin
        let pool = Flow.get_domain_cur man flow in

        let cs = Callstack.get flow in
        let range = erange expr in
        let recent_uid, flow = get_id_flow (cs, range, recent_flag) flow in
        let old_uid, flow = get_id_flow (cs, range, old_flag) flow in

        let recent_addr = {addr_kind; addr_uid = recent_uid} in
        let old_addr = {addr_kind; addr_uid = old_uid} in

        (match Pool.mem recent_addr pool, Pool.mem old_addr pool with
        | false, _ ->
          (* First time we allocate at this site, so no change to the sub-domain. *)
          flow

        | true, false ->
          (* Only a previous strong address exists =>
             Rebase the previous strong address with strong updates. *)
          Flow.map_domain_cur (add old_addr) man flow |>
          man.exec (mk_rename (mk_addr recent_addr range) (mk_addr old_addr range) range)

        | true, true ->
          (* Both strong and weak addresses exist =>
             Rebase the previous strong address with weak updates. *)
          man.exec ((mk_rename (mk_addr recent_addr range) (mk_addr old_addr ~mode:WEAK range) range)) flow

        )
        |> Flow.map_domain_cur (add recent_addr) man
        |> Eval.singleton (mk_addr recent_addr (tag_range range "mk_recent_addr"))
        |> OptionExt.return
      end
    | _ -> None

  (** Queries *)
  (** ******* *)

  let ask _ _ _ = None

end

let () =
  Framework.Domain.register_domain (module Domain)

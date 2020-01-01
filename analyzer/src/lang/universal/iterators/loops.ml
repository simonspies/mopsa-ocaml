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

(** Loops iterator with widening *)


open Mopsa
open Framework.Core.Sig.Domain.Stateless
open Ast
open Zone

let name = "universal.iterators.loops"


(*==========================================================================*)
(**                         {2 Loops flow token}                            *)
(*==========================================================================*)

type token +=
  | T_break
  (** Control flows reaching a break statement *)

  | T_continue
  (** Control flows reaching a continue statement *)

let () =
  register_token {
    compare = (fun next tk1 tk2 -> next tk1 tk2);
    print   = (fun next fmt tk ->
        match tk with
        | T_break -> Format.pp_print_string fmt "break"
        | T_continue -> Format.pp_print_string fmt "cont"
        | _ -> next fmt tk
      );
  }


(*==========================================================================*)
(**                       {2 Command line options}                          *)
(*==========================================================================*)

let opt_loop_widening_delay : int ref = ref 0
(** Number of iterations before applying a widening. *)

let opt_loop_unrolling : int ref = ref 1
(** Number of unrolling iterations before joining the environments. *)

let opt_loop_use_cache : bool ref = ref true

let () =
  register_domain_option name {
    key = "-widening-delay";
    category = "Loops";
    doc = " number of iterations before applying a widening";
    spec = ArgExt.Set_int opt_loop_widening_delay;
    default = "0";
  };
  register_domain_option name {
    key = "-loop-unrolling";
    category = "Loops";
    doc = " number of unrolling iterations before joining the environments";
    spec = ArgExt.Set_int opt_loop_unrolling;
    default = "1";
  };
  register_domain_option name {
    key = "-loop-no-cache";
    category = "Loops";
    doc = " do not use cache for loops";
    spec = ArgExt.Clear opt_loop_use_cache;
    default = "use cache";
  }


(*==========================================================================*)
(**                            {2 Domain}                                   *)
(*==========================================================================*)

module Domain  =
struct

  (** {3 Domain header} *)
  (** ***************** *)

  include GenStatelessDomainId(struct
      let name = name
    end)


  let interface = {
    iexec = { provides = [Z_u]; uses = [] };
    ieval = { provides = []; uses = [] };
  }

  let alarms = []

  (** {3 Cache of last fixpoint} *)
  (** ************************** *)

  (** Fixpoints are attached to the callstack and the location of the loop head *)
  module LoopHeadMap = MapExt.Make(
    struct
      type t = (Callstack.cs * range)
      let compare (cs1, r1) (cs2, r2) =
        Compare.compose
          [(fun () -> compare_range r1 r2);
           (fun () -> Callstack.compare cs1 cs2);
          ]
      let print fmt (cs, r) = Format.fprintf fmt "[%a, %a]" pp_range r Callstack.pp_call_stack cs end)

  (** Cache of the last fixpoints at loop heads *)
  module LastFixpointCtx = Context.GenPolyKey(
    struct
        type 'a t = 'a flow LoopHeadMap.t
        let print (l: Format.formatter -> 'a -> unit) fmt ctx = Format.fprintf fmt "Lfp cache context: %a"
            (LoopHeadMap.fprint
               MapExt.printer_default
               (fun fmt (cs, r) -> Callstack.print fmt cs; pp_range fmt r)
               (fun fmt flow -> TokenMap.print l fmt (Flow.get_token_map flow))) ctx
      end
    )


  (** Search the last fixpoint attached to a loop *)
  let search_last_fixpoint (srange, scs) man flow =
    try
      let m = Context.find_poly LastFixpointCtx.key (Flow.get_ctx flow) in
      let mf = LoopHeadMap.filter (fun (cs, range) _ ->
          Callstack.compare cs scs = 0 &&
          let srange = untag_range srange and range = untag_range range in
          match srange, range with
          | R_orig (s1, e1), R_orig (s2, e2) ->
            s1.pos_file = s2.pos_file && 0 <= s2.pos_line - s1.pos_line && s2.pos_line - s1.pos_line <= 1
          | _ -> false
        ) m in
      Some (LoopHeadMap.choose mf |> snd |> Flow.join man.lattice flow)

    with Not_found ->
      (debug "no ctx found";
       None)


  (** Update the last fixpoint attached to a loop *)
  let store_fixpoint man flow (range, cs) =
    let old_lfp_ctx =
      try
        let r = Context.find_poly LastFixpointCtx.key (Flow.get_ctx flow) in
        if LoopHeadMap.cardinal r > 5 then
          LoopHeadMap.remove_min_binding r
        else r
      with Not_found -> LoopHeadMap.empty in
    let stripped_flow =
      Flow.bottom (Flow.get_ctx flow) (Flow.get_alarms flow) |>
      Flow.add T_cur (Flow.get T_cur man.lattice flow) man.lattice |>
      Flow.add T_continue (Flow.get T_continue man.lattice flow) man.lattice |>
      Flow.add T_break (Flow.get T_break man.lattice flow) man.lattice
    in
    let lfp_ctx = LoopHeadMap.add (cs, range) stripped_flow old_lfp_ctx in
    Flow.set_ctx (Context.add_poly LastFixpointCtx.key lfp_ctx (Flow.get_ctx flow)) flow

  let join_w_old_lfp man flow range =
    debug "searching in cache";
    match search_last_fixpoint range man flow with
    | None -> None
    | Some old_lfp ->
      let res = Flow.join man.lattice old_lfp flow in
      debug "cache: %a join %a = %a@\n" (Flow.print man.lattice.print) old_lfp (Flow.print man.lattice.print) flow (Flow.print man.lattice.print) res;
      Some res
    (* flow *)


  (** Merge tokens T_cur and T_continue into T_cur *)
  let merge_cur_and_continue man flow =
    let cur = Flow.get T_cur man.lattice flow in
    let cont = Flow.get T_continue man.lattice flow in
    let ctx = Flow.get_unit_ctx flow in
    Flow.set T_cur (man.lattice.join ctx cur cont) man.lattice flow |>
    Flow.remove T_continue


  let init prog man flow =
    Flow.map_ctx (Context.init_poly LastFixpointCtx.init) flow


  let rec lfp count delay cond body man flow_init flow =
    debug "lfp called, range = %a, count = %d" (* @\n flow = %a@\n*) pp_range body.srange count (* (Flow.print man.lattice) flow *);
    let flow' = Flow.remove T_continue flow |>
                Flow.remove T_break |>
                man.exec (mk_assume cond cond.erange) |>
                man.exec body |>
                merge_cur_and_continue man |>
                Flow.join man.lattice flow_init
    in
    let cur = Flow.get T_cur man.lattice flow in
    let cur' = Flow.get T_cur man.lattice flow' in
    let is_sub = man.lattice.subset (Flow.get_unit_ctx flow') cur' cur in
    debug "lfp range %a is_sub: %b" pp_range body.srange is_sub;
    if is_sub then flow'
    else if delay = 0 then
      let wcur = man.lattice.widen (Flow.get_unit_ctx flow') cur cur' in
      let wflow = Flow.set T_cur wcur man.lattice flow' in
      let () = debug
          "widening: %a@\n abs =@\n@[  %a@]@\n abs' =@\n@[  %a@]@\n res =@\n@[  %a@]"
          pp_range body.srange
          (Flow.print man.lattice.print) flow
          (Flow.print man.lattice.print) flow'
          (Flow.print man.lattice.print) wflow
      in
      lfp (count+1) !opt_loop_widening_delay cond body man flow_init wflow
    else
      lfp (count+1) (delay - 1) cond body man flow_init flow'


  let rec unroll i cond body man flow =
    debug "unrolling iteration %d in %a" i pp_range (srange body);
    if i = 0 then (false, flow, Flow.bottom (Flow.get_ctx flow) (Flow.get_alarms flow))
    else
      let flow1 =
        man.exec {skind = S_assume cond; srange = cond.erange} flow |>
        man.exec body |>
        merge_cur_and_continue man
      in

      let flow2 =
        man.exec (mk_assume (mk_not cond cond.erange) cond.erange) (Flow.copy_ctx flow1 flow)
      in
      if Flow.subset man.lattice flow1 flow then
        let () = debug "stabilisation reached in unrolling!" in
        true, flow1, flow2
      else
        let flag, flow1', flow2' = unroll (i - 1) cond body man (Flow.copy_ctx flow2 flow1) in
        flag, flow1', Flow.join man.lattice flow2 flow2'


  let rec exec zone stmt (man:('a,unit) man) flow =
    match skind stmt with
    | S_while(cond, body) ->
      debug "while %a:" (* @\nflow = @[%a@] *) pp_range stmt.srange (* (Flow.print man.lattice) flow *);

      let flow0 = Flow.remove T_continue flow |>
                  Flow.remove T_break
      in

      let is_fp, flow_init, flow_out =
        if !opt_loop_use_cache then
          match join_w_old_lfp man flow0 (stmt.srange, Flow.get_callstack flow0) with
          | Some flow0 -> false, flow0, Flow.bottom (Flow.get_ctx flow0) (Flow.get_alarms flow0)
          | None -> unroll !opt_loop_unrolling cond body man flow0
        else
          unroll !opt_loop_unrolling cond body man flow0 in

      debug "post unroll %a (is_fp=%b):@\n flow_init = @[%a@]@\n flow_out = @[%a@]"
        pp_range stmt.srange
        is_fp
        (Flow.print man.lattice.print) flow_init
        (Flow.print man.lattice.print) flow_out
      ;

      let flow_lfp =
        if is_fp then
          flow_init
        else
          let flow_lfp = lfp 0 !opt_loop_widening_delay cond body man flow_init flow_init in
          let flow_lfp = if !opt_loop_use_cache then store_fixpoint man flow_lfp (stmt.srange, Flow.get_callstack flow_lfp) else flow_lfp in
          flow_lfp in

      let res0 =
        man.exec (mk_assume (mk_not cond cond.erange) cond.erange) flow_lfp |>
        Flow.join man.lattice flow_out
      in

      debug "while post abs %a:" (* @\nres0 = @[%a@] *) pp_range stmt.srange (* (Flow.print man.lattice) res0 *);

      let res1 = Flow.add T_cur (Flow.get T_break man.lattice res0) man.lattice res0 |>
                 Flow.set T_break (Flow.get T_break man.lattice flow) man.lattice |>
                 Flow.set T_continue (Flow.get T_continue man.lattice flow) man.lattice
      in


      Some (Post.return res1)

    | S_break ->
      let cur = Flow.get T_cur man.lattice flow in
      let flow' = Flow.add T_break cur man.lattice flow |>
                  Flow.remove T_cur
      in
      Some (Post.return flow')

    | S_continue ->
      let cur = Flow.get T_cur man.lattice flow in
      let flow' = Flow.add T_continue cur man.lattice flow |>
                  Flow.remove T_cur
      in
      Some (Post.return flow')

    | _ -> None

  let eval _ _ _ _ = None

  let ask _ _ _ = None

end

(*==========================================================================*)
(**                               {2 Setup}                                 *)
(*==========================================================================*)


let () =
  register_domain (module Domain)

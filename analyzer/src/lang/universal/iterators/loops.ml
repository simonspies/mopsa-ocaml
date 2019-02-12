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
open Framework.Domains.Stateless
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

let () =
  register_domain_option name {
    key = "-widening-delay";
    doc = " number of iterations before applying a widening";
    spec = Arg.Set_int opt_loop_widening_delay;
    default = "0";
  };
  register_domain_option name {
    key = "-loop-unrolling";
    doc = " number of unrolling iterations before joining the environments";
    spec = Arg.Set_int opt_loop_unrolling;
    default = "1";
  }

(*==========================================================================*)
(**                            {2 Domain}                                   *)
(*==========================================================================*)

module Domain : Framework.Domains.Stateless.S =
struct

  type _ domain += D_universal_loops : unit domain

  let id = D_universal_loops
  let name = name
  let identify : type a. a domain -> (unit, a) eq option =
    function
    | D_universal_loops -> Some Eq
    | _ -> None


  let debug fmt = Debug.debug ~channel:name fmt


  let exec_interface = {export = [Z_u]; import = []}
  let eval_interface = {export = []; import = []}

  let init prog man flow = None

  let rec exec zone stmt man flow =
    match skind stmt with
    | S_while(cond, body) ->
      debug "while:@\n abs = @[%a@]" (Flow.print man) flow;

      let flow0 = Flow.remove T_continue man flow |>
                  Flow.remove T_break man
      in

      let flow_init, flow_out = unroll cond body man flow0 in

      debug "post unroll:@\n abs0 = @[%a@]@\n abs out = @[%a@]"
        (Flow.print man) flow_init
        (Flow.print man) flow_out
      ;

      let res0 =
        lfp !opt_loop_widening_delay cond body man flow_init flow_init |>
        man.exec (mk_assume (mk_not cond cond.erange) cond.erange) |>
        Flow.join man flow_out
      in

      let res1 = Flow.add T_cur (Flow.get T_break man res0) man res0 |>
                 Flow.set T_break (Flow.get T_break man flow) man |>
                 Flow.set T_continue (Flow.get T_continue man flow) man
      in

      debug "while post abs:@\n abs = @[%a@]" (Flow.print man) res1;

      Some (Post.of_flow res1)

    | S_break ->
      let cur = Flow.get T_cur man flow in
      let flow' = Flow.add T_break cur man flow |>
                  Flow.remove T_cur man
      in
      Some (Post.of_flow flow')

    | S_continue ->
      let cur = Flow.get T_cur man flow in
      let flow' = Flow.add T_continue cur man flow |>
                  Flow.remove T_cur man
      in
      Some (Post.of_flow flow')

    | _ -> None

  and lfp delay cond body man flow_init flow =
    let flow0 = Flow.remove T_continue man flow |>
                Flow.remove T_break man
    in

    debug "lfp:@\n delay = %d@\n abs = @[%a@]"
      delay (Flow.print man) flow0
    ;

    let flow1 = man.exec (mk_assume cond cond.erange) flow0 |>
                man.exec body
    in

    let flow2 = merge_cur_and_continue man flow1 in

    debug "lfp post:@\n res = @[%a@]" (Flow.print man) flow1;

    let flow3 = Flow.join man flow_init flow2 in

    debug "lfp join:@\n res = @[%a@]" (Flow.print man) flow3;

    if Flow.subset man flow3 flow then flow3
    else
    if delay = 0 then
      let wflow = Flow.widen man flow flow3 in
      debug
        "widening:@\n abs =@\n@[  %a@]@\n abs' =@\n@[  %a@]@\n res =@\n@[  %a@]"
        (Flow.print man) flow
        (Flow.print man) flow3
        (Flow.print man) wflow;
      lfp !opt_loop_widening_delay cond body man flow_init wflow
    else
      lfp (delay - 1) cond body man flow_init flow3

  and unroll cond body man flow =
    let rec loop i flow =
      debug "unrolling iteration %d" i;
      let annot = Flow.get_all_annot flow in
      if i = 0 then (flow, Flow.bottom annot)
      else
        let flow1 =
          man.exec {skind = S_assume cond; srange = cond.erange} flow |>
          man.exec body |>
          merge_cur_and_continue man
        in
        let flow2 =
          man.exec (mk_assume (mk_not cond cond.erange) cond.erange) (Flow.copy_annot flow1 flow)
        in
        let flow1', flow2' = loop (i - 1) (Flow.copy_annot flow2 flow1) in
        flow1', Flow.join man flow2 flow2'
    in
    loop !opt_loop_unrolling flow

  and merge_cur_and_continue man flow =
    let annot = Flow.get_all_annot flow in
    Flow.map (fun tk eabs ->
        match tk with
        | T_cur ->
          let cont = Flow.get T_continue man flow in
          man.join annot eabs cont
        | T_continue -> man.bottom
        | _ -> eabs
      ) man flow

  let eval _ _ _ _ = None

  let ask _ _ _ = None

end

(*==========================================================================*)
(**                               {2 Setup}                                 *)
(*==========================================================================*)


let () =
  Framework.Domains.Stateless.register_domain (module Domain);

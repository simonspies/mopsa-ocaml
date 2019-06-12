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

(** Inter-procedural iterator by inlining, caching the last analysis
   results for each flow *)

open Mopsa
open Ast
open Zone
open Callstack
open Context
open Inlining
open MapExt

let name = "universal.iterators.interproc.join_based_cache"

module Domain =
struct

  include GenStatelessDomainId(struct
      let name = name
    end)

  (** Zoning definition *)
  let interface = {
    iexec = { provides = [Z_u]; uses = [] };
    ieval = { provides = [Z_u, Z_any]; uses = [Z_u, Z_any] };
  }

  let debug fmt = Debug.debug ~channel:name fmt

  module Fctx = Context.GenPolyKey(
    struct
      type 'a t = ('a flow * 'a flow) StringMap.t
      let print p fmt ctx = Format.fprintf fmt "Function cache context (py): %a@\n"
          (StringMap.fprint
             MapExt.printer_default
             (fun fmt s -> Format.fprintf fmt "%s" s)
             (fun fmt (in_flow, out_flow) ->
                Format.fprintf fmt "in_flow=%a@\nout_flow=%a@\n"
                  (Flow.print_w_lprint p) in_flow
                  (Flow.print_w_lprint p) out_flow
             )
          )
          ctx
    end)

  let find_signature man funname in_flow =
    try
      let cache = Context.find_poly Fctx.key (Flow.get_ctx in_flow) in
      let flow_in, flow_out = StringMap.find funname cache in
      if Flow.subset man.lattice in_flow flow_in then Some (flow_in, flow_out) else None
      with Not_found -> None


  let store_signature lattice funname in_flow out_flow =
    let old_ctx = try Context.find_poly Fctx.key (Flow.get_ctx out_flow) with Not_found -> StringMap.empty in
    let new_sig =
      try
        let old_in, old_out = StringMap.find funname old_ctx in
        Flow.join lattice old_in in_flow,
        Flow.join lattice old_out out_flow
      with Not_found -> (in_flow, out_flow) in
    let new_ctx = StringMap.add funname new_sig old_ctx in
    Flow.set_ctx (Context.add_poly Fctx.key new_ctx (Flow.get_ctx out_flow)) out_flow


  let init prog flow =
    Flow.map_ctx (Context.init_poly Fctx.init)

  let eval zs exp man flow =
    let range = erange exp in
    match ekind exp with
    | E_call({ekind = E_function (User_defined func)}, args) ->
      let in_flow = flow in
      let in_flow_cur = Flow.set T_cur (Flow.get T_cur man.lattice in_flow) man.lattice (Flow.bottom (Flow.get_ctx in_flow)) in
      let new_vars, in_flow_cur = Inlining.Domain.inline_function_assign_args man func args range in_flow_cur in
      let in_flow_other = Flow.remove T_cur in_flow in
      begin match find_signature man func.fun_name in_flow_cur with
        | None ->
          Inlining.Domain.inline_function_exec_body man func args range new_vars in_flow_cur func.fun_return_var |>
          Eval.bind (fun var_res out_flow  ->
              let flow = store_signature man.lattice func.fun_name in_flow_cur out_flow in
              man.eval var_res (Flow.join man.lattice in_flow_other flow)
            )

        | Some (_,  out_flow) ->
          Debug.debug ~channel:"profiling" "reusing %s at range %a" func.fun_name pp_range func.fun_range;
          man.eval (mk_var func.fun_return_var range) (Flow.join man.lattice in_flow_other out_flow)
      end
      |> Option.return




    | _ -> None

  let exec _ _ _ _ = None
  let ask _ _ _ = None

end


let () = Framework.Core.Sig.Domain.Stateless.register_domain (module Domain)
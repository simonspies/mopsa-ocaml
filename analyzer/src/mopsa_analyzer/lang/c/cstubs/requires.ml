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

(** Validator of stub requirements *)


open Mopsa
open Sig.Abstraction.Stateless
open Universal.Ast
open Stubs.Ast
open Common.Points_to
open Ast
open Common.Alarms
open Aux_vars



module Domain =
struct


  (** Domain identification *)
  (** ===================== *)

  include GenStatelessDomainId(struct
      let name = "c.cstubs.requires"
    end)

  let checks = [ CHK_C_INVALID_MEMORY_ACCESS;
                 Stubs.Alarms.CHK_STUB_INVALID_REQUIRES ]

  (** Initialization of environments *)
  (** ============================== *)

  let init _ _ flow =  flow


  (** Computation of post-conditions *)
  (** ============================== *)

  let eval_base_offset ptr range man flow =
    resolve_pointer ptr man flow >>$ fun pt flow ->
    match pt with
    | P_null ->
      raise_c_null_deref_alarm ptr ~range man flow |>
      Cases.empty

    | P_invalid ->
      raise_c_invalid_deref_alarm ptr ~range man flow |>
      Cases.empty

    | P_block ({ base_kind = Addr _; base_valid = false; base_invalidation_range = Some r }, offset, _) ->
      raise_c_use_after_free_alarm ptr r ~range man flow |>
      Cases.empty

    | P_block ({ base_kind = Var v; base_valid = false; base_invalidation_range = Some r }, offset, _) ->
      raise_c_dangling_deref_alarm ptr v r ~range man flow |>
      Cases.empty

    | P_top ->
      let cond = mk_stub_builtin_call VALID_PTR ptr ~etyp:u8 range in
      let flow = Stubs.Alarms.raise_stub_invalid_requires ~bottom:false cond range man flow in
      Cases.singleton None flow

    | P_block (base, offset, _) ->
      Cases.singleton (Some (base,offset)) flow

    | P_fun _ -> assert false


  let exec_stub_requires_valid_ptr ptr range man flow =
    eval_base_offset ptr range man flow >>$ fun bo flow ->
    match bo with
    | None ->
      (* Top pointer found *)
      Post.return flow

    | Some (base,offset) ->
      Common.Base.eval_base_size base range man flow >>$ fun size flow ->
      man.eval size flow >>$ fun size flow ->
      man.eval offset flow >>$ fun offset flow ->
      let elm = under_type ptr.etyp |> void_to_char |> (fun t -> mk_z (sizeof_type t) range) in
      let limit = sub size elm range in
      let cond = mk_in offset (mk_zero range) limit range in
      assume cond
        ~fthen:(fun flow -> Post.return flow)
        ~felse:(fun eflow ->
            raise_c_out_bound_alarm base size offset (under_type ptr.etyp) range man flow eflow |>
            Post.return
          )
        man flow

  let exec_stub_requires_valid_ptr_quant i lo hi ptr range man flow =
    eval_base_offset ptr range man flow >>$ fun bo flow ->
    match bo with
    | None ->
      (* Top pointer found *)
      Post.return flow

    | Some (base,offset) ->
      Common.Base.eval_base_size base range man flow >>$ fun size flow ->
      man.eval size flow >>$ fun size flow ->
      let min, max = Common.Quantified_offset.bound offset [FORALL,i,S_interval(lo,hi)] in
      man.eval min flow >>$ fun min flow ->
      man.eval max flow >>$ fun max flow ->
      let elm = under_type ptr.etyp |> void_to_char |> (fun t -> mk_z (sizeof_type t) range) in
      let limit = sub size elm range in
      let cond = mk_binop
          (mk_in min (mk_zero range) limit range)
          O_log_and
          (mk_in max (mk_zero range) limit range)
          range
      in
      assume cond
        ~fthen:(fun flow -> Post.return flow)
        ~felse:(fun eflow ->
            raise_c_out_bound_alarm base size offset (under_type ptr.etyp) range man flow eflow |>
            Post.return
          )
        man flow


  let exec_stub_requires_float_class flt cls msg range man flow =
    man.eval flt flow ~translate:"Universal" >>$ fun flt flow ->
    let cond = mk_float_class cls flt range in
    assume cond
      ~fthen:(fun flow -> Post.return flow)
      ~felse:(fun eflow ->
          raise_c_invalid_float_class_alarm flt msg range man flow eflow |>
          Post.return
        ) man flow


  let exec stmt man flow  =
    match skind stmt with
    | S_stub_requires { ekind = E_stub_builtin_call(VALID_PTR, ptr) } ->
      exec_stub_requires_valid_ptr ptr stmt.srange man flow |>
      OptionExt.return

    | S_stub_requires { ekind = E_stub_quantified_formula([FORALL,i,S_interval(a,b)], { ekind = E_stub_builtin_call(VALID_PTR, ptr) }) }  ->
      exec_stub_requires_valid_ptr_quant i a b ptr stmt.srange man flow |>
      OptionExt.return

    | S_stub_requires { ekind = E_stub_builtin_call((VALID_FLOAT | FLOAT_INF | FLOAT_NAN) as op, flt) } ->
      let cls, msg = match op with
        | VALID_FLOAT -> float_valid, "valid"
        | FLOAT_INF -> float_inf, "infinity"
        | FLOAT_NAN -> float_nan, "NaN"
        | _ -> assert false
      in
      exec_stub_requires_float_class flt cls msg stmt.srange man flow |>
      OptionExt.return

    | _ -> None



  (** Evaluation of expressions *)
  (** ========================= *)


  let eval exp man flow = None

  let ask _ _ _ = None

  let print_expr _ _ _ _ = ()

end

let () =
  register_stateless_domain (module Domain)
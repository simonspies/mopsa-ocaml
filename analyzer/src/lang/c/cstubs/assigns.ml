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

(** Generic handler of assigns clauses and primed variables. *)


open Mopsa
open Framework.Core.Sig.Domain.Stateless
open Universal.Ast
open Stubs.Ast
open Common.Points_to
open Ast
open Zone
open Universal.Zone
open Common.Base
open Common.Alarms
open Common.Points_to



module Domain =
struct


  (** Domain identification *)
  (** ===================== *)

  include GenStatelessDomainId(struct
      let name = "c.cstubs.assigns"
    end)

  let interface= {
    iexec = {
      provides = [Z_c];
      uses     = [Z_c_low_level];
    };

    ieval = {
      provides = [Z_c,Z_c_low_level; Z_c_low_level, Z_c_scalar];
      uses     = [Z_c,Z_c_low_level];
    }
  }

  let alarms = []



  (** Initialization of environments *)
  (** ============================== *)

  let init prog man flow = flow


  (** Auxiliary variables of primed bases *)
  (** =================================== *)

  type var_kind +=
    | V_c_primed_base of base

  let () = register_var {
      print = (fun next fmt v ->
          match v.vkind with
          | V_c_primed_base base -> Format.fprintf fmt "%a'" pp_base base
          | _ -> next fmt v
        );
      compare = (fun next v1 v2 ->
          match v1.vkind, v2.vkind with
          | V_c_primed_base b1, V_c_primed_base b2 -> compare_base b1 b2
          | _ -> next v1 v2
        );
    }

  let mk_primed_base_var base =
    let vkind = V_c_primed_base base in
    let vname = base_uniq_name base ^ "'" in
    let vtyp = match base.base_kind with
      | Var v  -> v.vtyp
      | Addr a -> T_c_array(s8,C_array_no_length)
      | _      -> assert false
    in
    mkv vname vkind vtyp ~mode:STRONG


  let mk_primed_base_expr base range =
    mk_var (mk_primed_base_var base) range


  let mk_base_expr base range =
    match base.base_kind with
    | Var v  -> mk_var v range
    | Addr a -> mk_addr a range
    | _      -> assert false


  (** Create the expression ( typ* )( ( char* )&base' + offset ) *)
  let mk_primed_address base offset typ range =
    let primed = mk_primed_base_expr base range in
    mk_c_cast
      ( add
          (mk_c_cast (mk_c_address_of primed range) (T_c_pointer s8) range)
          offset
          ~typ:(T_c_pointer s8)
          range )
      (T_c_pointer typ)
      range



  (** Computation of post-conditions *)
  (** ============================== *)


  (* Collect assigned bases *)
  let assigned_bases assigns range man flow =
    List.fold_left (fun acc assign ->
        let ptr = match assign.assign_offset with
          | [] -> mk_c_address_of assign.assign_target range
          | _ -> assign.assign_target
        in
        let pp = man.eval ptr ~zone:(Z_c,Z_c_points_to) flow in
        Cases.fold_some (fun p flow acc ->
            match ekind p with
            | E_c_points_to(P_block ({ base_valid = true } as base, _, _)) ->
              BaseSet.add base acc
            | _ -> acc
          ) pp acc
      ) BaseSet.empty assigns

  (** Expand base to a primed copy *)
  let expand_primed_base base range man flow =
    let primed = mk_primed_base_expr base range in
    man.post (mk_expand (mk_base_expr base range) [primed] range) ~zone:Z_c_low_level flow


  (** Prepare primed copies of assigned bases *)
  let exec_stub_prepare_all_assigns assigns range man flow =
    (* Expand assigned bases to primed copies *)
    let bases = assigned_bases assigns range man flow in
    BaseSet.fold (fun base acc ->
        Post.bind (expand_primed_base base range man) acc
      ) bases (Post.return flow)


  (** Declare an assigned base *)
  let exec_assign_base base offset mode typ assigned_indices range man flow =
    match assigned_indices with
    | [] ->
      (* Prime the target *)
      let primed_target = mk_primed_address base offset typ range in
      let lval = mk_c_deref primed_target range in
      man.post (mk_forget lval range) ~zone:Z_c flow

    | _ ->

      (* Convert the assigned indices to temporary quantified variables *)
      let quant_indices_with_tmps = List.map (fun (a,b) ->
          let tmp = mktmp ~typ:s32 () in
          mk_stub_quantified FORALL tmp (S_interval(a,b)) range, tmp
        ) assigned_indices
      in

      (* Prime the target *)
      let primed_target = mk_primed_address base offset (under_type typ) range in

      (* Create the assigned lval and cleaners for temporary quantified variables *)
      let lval, cleaners = List.fold_left (fun (acc,cleaners) (i,tmp) ->
          mk_c_subscript_access acc i range,
          mk_remove_var tmp range :: cleaners
        ) (primed_target,[]) quant_indices_with_tmps
      in

      (* Execute `forget lval` *)
      man.post (mk_forget lval range) ~zone:Z_c flow >>$ fun () flow ->
      man.post (mk_block cleaners range) ~zone:Z_c flow



  (** Execute `assigns: target[a1..b1]..[an..bn];` *)
  let exec_stub_assigns target assigned_indices range man flow =
    let ptr = match assigned_indices with
      | [] -> mk_c_address_of target range
      | _ -> target
    in
    man.eval ptr ~zone:(Z_c,Z_c_points_to) flow >>$ fun p flow ->
    let man' = Core.Sig.Stacked.Manager.of_domain_man man in
    match ekind p with
    | E_c_points_to P_null ->
      raise_c_null_deref_alarm ptr range man' flow |>
      Cases.empty_singleton

    | E_c_points_to P_invalid ->
      raise_c_invalid_deref_alarm ptr range man' flow |>
      Cases.empty_singleton

    | E_c_points_to (P_block ({ base_kind = Addr _; base_valid = false; base_invalidation_range = Some r }, offset, _)) ->
      raise_c_use_after_free_alarm ptr r range man' flow |>
      Cases.empty_singleton

    | E_c_points_to (P_block ({ base_kind = Var v; base_valid = false; base_invalidation_range = Some r }, offset, _)) ->
      raise_c_dangling_deref_alarm ptr v r range man' flow |>
      Cases.empty_singleton

    | E_c_points_to (P_block (base, offset, _)) when is_base_readonly base ->
      raise_c_read_only_modification_alarm base range man' flow |>
      Cases.empty_singleton

    | E_c_points_to (P_block (base, offset, mode))  ->
      exec_assign_base base offset mode target.etyp assigned_indices range man flow

    | E_c_points_to P_top ->
      Soundness.warn_at range "ignoring ⊤ pointer %a" pp_expr (get_orig_expr ptr);
      Cases.empty_singleton flow

    | _ -> assert false



  (** Rename primed bases to original names *)
  let rename_primed_base base range man flow =
    let unprimed = mk_base_expr base range in
    let primed = mk_primed_base_expr base range in
    let stmt = mk_rename primed unprimed range in
    let post1 = man.post stmt ~zone:Z_c_low_level flow in
    (* If this is a weak base, we need to restore the old values. *)
    (* To do that, we remove the primed base from the flow and we join with post1 *)
    if base_mode base = STRONG then
      post1
    else
      let post2 = man.post (mk_remove primed range) ~zone:Z_c_scalar flow in
      Post.join post1 post2


  (** Clean state from primed bases *)
  let exec_stub_clean_all_assigns assigns range man flow =
    (* Rename primed copies to original version *)
    let bases = assigned_bases assigns range man flow in
    BaseSet.fold (fun base acc ->
        Post.bind (rename_primed_base base range man) acc
      ) bases (Post.return flow)



  let exec zone stmt man flow  =
    match skind stmt with
    | S_stub_prepare_all_assigns al ->
      exec_stub_prepare_all_assigns al stmt.srange man flow |>
      OptionExt.return

    | S_stub_assigns a ->
      exec_stub_assigns a.assign_target a.assign_offset stmt.srange man flow |>
      OptionExt.return

    | S_stub_clean_all_assigns al ->
      exec_stub_clean_all_assigns al stmt.srange man flow |>
      OptionExt.return

    | _ -> None



  (** Evaluation of expressions *)
  (** ========================= *)


  let eval_primed_base base offset mode typ range man flow =
    let p = mk_primed_address base offset typ range in
    Eval.singleton (mk_c_deref p range) flow


  let eval_stub_primed e range man flow =
    let ptr = mk_c_address_of e range in
    man.eval ptr ~zone:(Z_c,Z_c_points_to) flow >>$ fun p flow ->
    let man' = Core.Sig.Stacked.Manager.of_domain_man man in
    match ekind p with
    | E_c_points_to P_null ->
      raise_c_null_deref_alarm ptr range man' flow |>
      Cases.empty_singleton

    | E_c_points_to P_invalid ->
      raise_c_invalid_deref_alarm ptr range man' flow |>
      Cases.empty_singleton

    | E_c_points_to (P_block ({ base_kind = Addr _; base_valid = false; base_invalidation_range = Some r }, offset, _)) ->
      raise_c_use_after_free_alarm ptr r range man' flow |>
      Cases.empty_singleton

    | E_c_points_to (P_block ({ base_kind = Var v; base_valid = false; base_invalidation_range = Some r }, offset, _)) ->
      raise_c_dangling_deref_alarm ptr v r range man' flow |>
      Cases.empty_singleton

    | E_c_points_to (P_block (base, offset, _)) when is_base_readonly base ->
      raise_c_read_only_modification_alarm base range man' flow |>
      Cases.empty_singleton

    | E_c_points_to (P_block (base, offset, mode))  ->
      eval_primed_base base offset mode e.etyp range man flow

    | E_c_points_to P_top ->
      Soundness.warn_at range "ignoring ⊤ pointer %a" pp_expr (get_orig_expr ptr);
      Cases.empty_singleton flow

    | _ -> assert false


  let eval zone exp man flow =
    match ekind exp with
    | E_stub_primed e ->
      eval_stub_primed e exp.erange man flow |>
      OptionExt.return

    | E_stub_builtin_call(BYTES, { ekind = E_var({ vkind = V_c_primed_base base },_) }) ->
      eval_base_size base exp.erange (Sig.Stacked.Manager.of_domain_man man) flow |>
      OptionExt.return


    | _ -> None

  let ask _ _ _ = None

  let refine _ _ _ = assert false

end

let () =
  Framework.Core.Sig.Domain.Stateless.register_domain (module Domain)

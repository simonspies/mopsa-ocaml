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

(** Evaluation of fscanf-derived functions *)

open Mopsa
open Framework.Core.Sig.Domain.Stateless
open Universal.Ast
open Ast
open Zone
open Common.Points_to
open Placeholder
open Format_string
open Common.Alarms

module Domain =
struct

  (** Domain identification *)
  (** ===================== *)

  include GenStatelessDomainId(struct
      let name = "c.libs.clib.formatted_io.fscanf"
    end)


  (** Zoning definition *)
  (** ================= *)

  let interface = {
    iexec = {
      provides = [];
      uses = [Z_c]
    };
    ieval = {
      provides = [
        Z_c, Z_c_low_level;
        Z_c, Z_c_points_to
      ];
      uses = []
    }
  }

  let alarms = [
    A_c_insufficient_format_args_cls;
    A_c_null_deref_cls;
    A_c_invalid_deref_cls;
    A_c_use_after_free_cls;
    A_c_incorrect_format_arg_cls
  ]

  (** {2 Transfer functions} *)
  (** ====================== *)

  let init _ _ flow =  flow

  let exec zone stmt man flow = None


  (** {2 Evaluation entry point} *)
  (** ========================== *)


  let assign_arg arg placeholder range man flow =
    match placeholder.ip_typ with
    | Int t ->
      let typ = T_c_integer t in
      let ptr = T_c_pointer typ in
      let flow =
        if not (is_c_pointer_type arg.etyp) || not (is_c_int_type @@ under_type arg.etyp) then
          raise_c_incorrect_format_arg_alarm ptr arg arg.erange (Sig.Stacked.Manager.of_domain_man man) flow
        else
          flow
      in
      assert_valid_ptr arg range man flow >>$ fun () flow ->
      man.post (mk_assign (mk_c_deref (mk_c_cast arg ptr range) range) (mk_top typ range) range) flow

    | Float t ->
      let typ = T_c_float t in
      let ptr = T_c_pointer typ in
      let flow =
        if not (is_c_pointer_type arg.etyp) || not (is_c_float_type @@ under_type arg.etyp) then
          raise_c_incorrect_format_arg_alarm ptr arg arg.erange (Sig.Stacked.Manager.of_domain_man man) flow
        else
          flow
      in
      assert_valid_ptr arg range man flow >>$ fun () flow ->
      man.post (mk_assign (mk_c_deref (mk_c_cast arg ptr range) range) (mk_top typ range) range) flow

    | Pointer ->
      assert false

    | String ->
      let flow =
        if not (is_c_pointer_type arg.etyp) then
          raise_c_incorrect_format_arg_alarm (T_c_pointer s8) arg arg.erange (Sig.Stacked.Manager.of_domain_man man) flow
        else
          flow
      in
      let w = match placeholder.ip_width with
        | None -> mk_top ul range
        | Some n -> mk_int (n-1) ~typ:ul range
      in
      memrand arg (mk_zero range) w range man flow


  (** Assign arbitrary values to arguments *)
  let assign_args format args range man flow =
    parse_input_format format range man flow >>$ fun placeholders flow ->
    let nb_required = List.length placeholders in
    let nb_given = List.length args in
    if nb_required > nb_given then
      let man' = Sig.Stacked.Manager.of_domain_man man in
      raise_c_insufficient_format_args_alarm nb_required nb_given range man' flow |>
      Post.return
    else
      let rec iter placeholders args flow =
        match placeholders, args with
        | ph :: tlp, arg :: tla ->
          assign_arg arg ph range man flow >>$ fun () flow ->
          iter tlp tla flow
        | _ -> Post.return flow
      in
      iter placeholders args flow



  (** Evaluation entry point *)
  let eval zone exp man flow =
    match ekind exp with

    (* 𝔼⟦ scanf ⟧ *)
    | E_c_builtin_call("scanf", format :: args) ->
      assign_args format args exp.erange man flow >>$? fun () flow ->
      Eval.singleton (mk_top s32 exp.erange) flow |>
      OptionExt.return

    (* 𝔼⟦ fscanf ⟧ *)
    | E_c_builtin_call("fscanf", stream :: format :: args) ->
      assert_valid_stream stream exp.erange man flow >>$? fun () flow ->
      assign_args format args exp.erange man flow >>$? fun () flow ->
      Eval.singleton (mk_top s32 exp.erange) flow |>
      OptionExt.return

      (* 𝔼⟦ sscanf ⟧ *)
    | E_c_builtin_call("sscanf", src :: format :: args) ->
      assign_args format args exp.erange man flow >>$? fun () flow ->
      assert_valid_string src exp.erange man flow >>$? fun () flow ->
      Eval.singleton (mk_top s32 exp.erange) flow |>
      OptionExt.return


    | _ -> None

  let ask _ _ _  = None

end

let () =
  Framework.Core.Sig.Domain.Stateless.register_domain (module Domain)

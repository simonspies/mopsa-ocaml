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

(** Abstraction of pointer arrays by smashing. *)


open Mopsa
open Core.Sig.Stacked.Stateless
open Universal.Ast
open Stubs.Ast
open Ast
open Universal.Zone
open Zone
open Common.Base
open Common.Points_to
open Common.Alarms


module Domain =
struct

  (** {2 Domain header} *)
  (** ***************** *)

  include GenStatelessDomainId(struct
      let name = "c.memory.lowlevel.pointer_smashing"
    end)

  let interface = {
    iexec = {
      provides = [Z_c_low_level];
      uses = [
        Z_c_scalar;
        Z_u_num
      ];
    };
    ieval = {
      provides = [Z_c_low_level, Z_c_scalar];
      uses = [
        Z_c, Z_u_num;
        Z_c_low_level, Z_u_num;
        Z_c_scalar, Z_u_num;
        Z_c_low_level, Z_c_scalar;
        Z_c_low_level, Z_c_points_to;
      ];
    }
  }

  let alarms = []

  (** {2 Auxiliary variables} *)
  (** *********************** *)

  (** Registration of the smash auxiliary variable *)
  type var_kind += V_c_pointer_smash   of base * bool


  let () =
    register_var {
      print = (fun next fmt v ->
          match v.vkind with
          | V_c_pointer_smash (base,primed) ->
            Format.fprintf fmt "smash(%a)%s" pp_base base (if primed then "'" else "")

          | _ -> next fmt v
        );

      compare = (fun next v1 v2 ->
          match v1.vkind, v2.vkind with
          | V_c_pointer_smash(b1,p1), V_c_pointer_smash(b2,p2) ->
            Compare.compose [
              (fun () -> compare_base b1 b2);
              (fun () -> compare p1 p2);
            ]

          | _ -> next v1 v2
        );
    }


  (** void* type *)
  let void_ptr = T_c_pointer T_c_void


  (** Size of a pointer cell *)
  let ptr_size = sizeof_type void_ptr


  (** Create the auxiliary variable smash(base). *)
  let mk_smash_var base ?(primed=false) range : expr =
    let name = "smash(" ^ (base_uniq_name base) ^ ")" ^ (if primed then "'" else "") in
    let v = mkv name (V_c_pointer_smash (base,primed)) (T_c_pointer T_c_void) in
    mk_var v range


  (** Create a weak copy of a smash variable *)
  let weaken v =
    match ekind v with
    | E_var (vv,WEAK) -> v
    | E_var (vv, STRONG) -> { v with ekind = E_var (vv,WEAK) }
    | _ -> assert false

  (** Create a strong copy of a smash variable *)
  let strongify v =
    match ekind v with
    | E_var (vv,STRONG) -> v
    | E_var (vv, WEAK) -> { v with ekind = E_var (vv,STRONG) }
    | _ -> assert false



  (** {2 Initialization procedure} *)
  (** **************************** *)

  let init prog man flow = flow



  (** {2 Abstract transformers} *)
  (** ************************* *)


  (** Get the base and offset pointed by ptr. Since we do not track invalid
      dereferences, we ignore invalid pointers.
  *)
  let eval_pointed_base_offset ptr range man flow =
    man.eval ptr ~zone:(Zone.Z_c_low_level, Z_c_points_to) flow >>$ fun pt flow ->
    match ekind pt with
    | E_c_points_to P_null
    | E_c_points_to P_invalid
    | E_c_points_to (P_block (InvalidAddr _, _))
    | E_c_points_to P_top ->
      Result.empty_singleton flow

    | E_c_points_to (P_block (base, offset)) ->
      Result.singleton (base, offset) flow

    | _ -> assert false


  (** Predicate defining interesting bases for which the domain will
      track the sentinel position.
  *)
  let is_interesting_base base =
    match base with
    | ValidVar v when is_c_type v.vtyp && is_c_array_type v.vtyp ->
      (* Accept only arrays with pointers or records of pointers *)
      let rec aux t =
        match remove_typedef_qual t with
        | T_c_pointer _ -> true
        | T_c_array(tt,_) -> aux tt
        | T_c_record { c_record_fields } ->
          List.for_all (fun field -> aux field.c_field_type) c_record_fields
        | _ -> false
      in
      aux v.vtyp

    | _ -> false


  (** Add a base to the domain's dimensions *)
  let add_base base range man flow =
    if is_interesting_base base then
      let smash = mk_smash_var base range in
      man.post ~zone:Z_c_scalar (mk_add smash range) flow
    else
      Post.return flow


  (** Declaration of a C variable *)
  let declare_variable v scope range man flow =
    add_base (ValidVar v) range man flow



  (** Assignment abstract transformer for 𝕊⟦ *p = rval; ⟧ *)
  let assign_deref p rval range man flow =
    eval_pointed_base_offset p range man flow >>$ fun (base,offset) flow ->
    eval_base_size base range man flow >>$ fun size flow ->
    man.eval ~zone:(Z_c_scalar,Z_u_num) size flow >>$ fun size flow ->
    man.eval ~zone:(Z_c_scalar,Z_u_num) offset flow >>$ fun offset flow ->
    assume
      (mk_in offset (mk_zero range) (sub size (mk_z ptr_size range) range) range)
      ~fthen:(fun flow ->
          if is_interesting_base base then
            man.eval ~zone:(Z_c_low_level,Z_c_scalar) rval flow >>$ fun rval flow ->
            let smash_weak = mk_smash_var base range |> weaken in
            man.post ~zone:Z_c_scalar (mk_assign smash_weak rval range) flow
          else
            Post.return flow
        )
      ~felse:(fun flow ->
          Flow.set_bottom T_cur flow |>
          Post.return
        )
      ~zone:Z_u_num man flow




  (** Declare a block as assigned by adding the primed auxiliary variables *)
  let stub_assigns target offsets range man flow =
    let p = match offsets with
      | [] -> mk_c_address_of target range
      | _  -> target
    in
    man.eval p ~zone:(Z_c_low_level,Z_c_points_to) flow >>$ fun pt flow ->
    match ekind pt with
    | E_c_points_to (P_block (base, _)) when is_interesting_base base ->
      let smash' = mk_smash_var base ~primed:true range in
      man.post ~zone:Z_c_scalar (mk_add smash' range) flow

    | _ -> Post.return flow



  (** Rename primed variables introduced by a stub *)
  (* FIXME: not yet implemented *)
  let rename_primed target offsets range man flow : 'a post =
    let p = match offsets with
      | [] -> mk_c_address_of target range
      | _  -> target
    in
    man.eval p ~zone:(Z_c_low_level,Z_c_points_to) flow >>$ fun pt flow ->
    match ekind pt with
    | E_c_points_to (P_block (base, _)) when is_interesting_base base ->
      let smash = mk_smash_var base range ~primed:false |> weaken in
      let smash' = mk_smash_var base range ~primed:true in
      man.post ~zone:Z_c_scalar (mk_assign smash smash' range) flow >>= fun _ flow ->
      man.post ~zone:Z_c_scalar (mk_remove smash' range) flow

    | _ ->
      Post.return flow


  (** Rename the auxiliary variables associated to a base *)
  let rename_base base1 base2 range man flow =
    let smash1 = mk_smash_var base1 range in
    let smash2 = mk_smash_var base2 range in
    man.post ~zone:Z_c_scalar (mk_rename smash1 smash2 range) flow


  (** Remove the auxiliary variables of a base *)
  let remove_base base range man flow =
    let smash = mk_smash_var base range in
    man.post ~zone:Z_c_scalar (mk_remove smash range) flow


  (** Transformers entry point *)
  let exec zone stmt man flow =
    match skind stmt with
    | S_c_declaration (v,init,scope) when is_interesting_base (ValidVar v) ->
      declare_variable v scope stmt.srange man flow |>
      Option.return

    | S_add { ekind = E_var (v, _) } when is_interesting_base (ValidVar v) ->
      add_base (ValidVar v) stmt.srange man flow |>
      Option.return

    | S_add { ekind = E_addr addr } when is_interesting_base (ValidAddr addr) ->
      add_base (ValidAddr addr) stmt.srange man flow |>
      Option.return

    | S_rename ({ ekind = E_var (v1,_) }, { ekind = E_var (v2,_) })
      when is_interesting_base (ValidVar v1) &&
           is_interesting_base (ValidVar v2)
      ->
      rename_base (ValidVar v1) (ValidVar v2) stmt.srange man flow |>
      Option.return


    | S_rename ({ ekind = E_addr addr1 }, { ekind = E_addr addr2 })
      when is_interesting_base (ValidAddr addr1) &&
           is_interesting_base (ValidAddr addr2)
      ->
      rename_base (ValidAddr addr1) (ValidAddr addr2) stmt.srange man flow |>
      Option.return

    | S_assign({ ekind = E_c_deref p} as lval, rval) when is_c_pointer_type lval.etyp ->
      assign_deref p rval stmt.srange man flow |>
      Option.return


    | S_remove { ekind = E_var (v, _) } when is_interesting_base (ValidVar v) ->
      remove_base (ValidVar v) stmt.srange man flow |>
      Option.return


    | S_stub_assigns(target, offsets) ->
      stub_assigns target offsets stmt.srange man flow |>
      Option.return


    | S_stub_rename_primed (target, offsets) when is_c_type target.etyp &&
                                                  not (is_c_num_type target.etyp) &&
                                                  (not (is_c_pointer_type target.etyp) || List.length offsets > 0)
      ->
      rename_primed target offsets stmt.srange man flow |>
      Option.return

    | _ -> None


  (** {2 Abstract evaluations} *)
  (** ************************ *)


  (** Abstract evaluation of a dereference *)
  let eval_deref exp primed range man flow =
    let p = match ekind exp with E_c_deref p -> p | _ -> assert false in
    let t = exp.etyp in
    eval_pointed_base_offset p range man flow >>$ fun (base,offset) flow ->

    if is_interesting_base base then
      let smash_weak = mk_smash_var base ~primed range |> weaken in
      Eval.singleton smash_weak flow
    else
      Eval.singleton (mk_top t range) flow



  (** Evaluations entry point *)
  let eval zone exp man flow =
    match ekind exp with
    | E_c_deref p
      when is_c_pointer_type exp.etyp &&
           under_type p.etyp |> void_to_char |> is_c_scalar_type
      ->
      eval_deref exp false exp.erange man flow |>
      Option.return

    | E_stub_primed ({ ekind = E_c_deref p } as e)
      when is_c_pointer_type exp.etyp &&
           under_type p.etyp |> void_to_char |> is_c_scalar_type
      ->
      eval_deref e true exp.erange man flow |>
      Option.return


    | _ -> None


  (** {2 Query handler} *)
  (** ***************** *)

  let ask query man flow = None


end

let () =
  Core.Sig.Stacked.Stateless.register_stack (module Domain)

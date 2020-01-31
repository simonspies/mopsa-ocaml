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

(** String length abstraction.

    This abstract domain implements the technique presented in [1]. It
    abstracts C strings by the position of the first `\0` character within the
    base memory block.

    The length is kept in an underlying numeric domain. Therefore, the domain
    is implemented as a stack domain, to allow sharing the underlying domain
    with others.

    The domain is stateless, because abstraction is performed by rewriting
    statements/expressions in C into equivalent ones in Universal over
    the length variable. Not internal state is required.

    [1] M. Journault, A. Miné, A. Ouadjaout. Modular static analysis
    of string manipulations in C programs. SAS 2018. LNCS, vol. 11002.
*)


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
      let name = "c.memory.lowlevel.string_length"
    end)

  let interface = {
    iexec = {
      provides = [Z_c_low_level];
      uses = [
        Z_u_num;
        Z_c_scalar
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

  (** {2 Variable of string lengths} *)
  (** ****************************** *)

  (** Registration of a new var kind for length variables *)
  type var_kind +=
    | V_c_string_length of base

  let () =
    register_var {
      print = (fun next fmt v ->
          match v.vkind with
          | V_c_string_length (base) ->
            Format.fprintf fmt "length(%a)" pp_base base

          | _ -> next fmt v
        );

      compare = (fun next v1 v2 ->
          match v1.vkind, v2.vkind with
          | V_c_string_length(b1), V_c_string_length(b2) ->
            compare_base b1 b2

          | _ -> next v1 v2
        );
    }

  (** Create a length variable. The returned variable is a
      mathematical integer, not a C variable.
  *)
  let mk_length_var base ?(mode=None) range =
    let name =
      let () =
        Format.fprintf Format.str_formatter "length(%s)"
          (base_uniq_name base)
      in
      Format.flush_str_formatter ()
    in
    let v = mkv name (V_c_string_length (base)) T_int ~mode:(base_mode base) in
    mk_var v ~mode range


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
    | E_c_points_to (P_block ({ base_valid = false }, _, _))
    | E_c_points_to P_top ->
      Cases.empty_singleton flow

    | E_c_points_to (P_block (base, offset, mode)) ->
      Cases.singleton (base, offset, mode) flow

    | _ -> assert false


  let is_interesting_base base =
    match base with
    (* Accept only arrays of chars *)
    | { base_kind = Var v; base_valid = true }
      when is_c_type v.vtyp &&
           is_c_array_type v.vtyp &&
           under_array_type v.vtyp |> remove_typedef_qual |> sizeof_type |> Z.equal Z.one
      ->
      true

    | { base_kind = String _ } -> true

    | { base_kind = Addr { addr_kind = A_stub_resource "Memory" }; base_valid = true }
    | { base_kind = Addr { addr_kind = A_stub_resource "ReadOnlyMemory" }; base_valid = true }
    | { base_kind = Addr { addr_kind = A_stub_resource "String"}; base_valid = true }
    | { base_kind = Addr { addr_kind = A_stub_resource "ReadOnlyString" }; base_valid = true }
    | { base_kind = Addr { addr_kind = A_stub_resource "arg" }; base_valid = true }
      -> true

    | _ -> false


  (** Add a base to the domain's dimensions *)
  let add_base base range man flow =
    if not (is_interesting_base base) then Post.return flow
    else match base.base_kind with
      | String _ ->
        Post.return flow

      | _ ->
        (* Add the length of the base to the numeric domain and
           initialize it with the interval [0, size(@)]
        *)
        eval_base_size base range man flow >>$ fun size flow ->
        man.eval ~zone:(Z_c_scalar, Z_u_num) size flow >>$ fun size flow ->

        let length = mk_length_var base range in

        man.post ~zone:Z_u_num (mk_add length range) flow >>= fun _ flow ->
        man.post ~zone:Z_u_num (mk_assume (mk_in length (mk_zero range) size range) range) flow


  let remove_base base range man flow =
    if not (is_interesting_base base) then Post.return flow
    else match base.base_kind with
      | String _ ->
        Post.return flow

      | _ ->
        let length = mk_length_var base range in
        man.post ~zone:Z_u_num (mk_remove length range) flow


  (** Rename the length variable associated to a base *)
  let rename_base base1 base2 range man flow =
    if not (is_interesting_base base1) then Post.return flow else
    if not (is_interesting_base base2) then remove_base base1 range man flow
    else
      let length1 = mk_length_var base1 range in
      let length2 = mk_length_var base2 range in
      man.post ~zone:Z_u_num (mk_rename length1 length2 range) flow


  (** Expand the length variable of a base *)
  let expand_base base1 bases range man flow =
    if not (is_interesting_base base1) then Post.return flow else
    if List.exists (fun b -> not (is_interesting_base b)) bases then panic_at range "expand %a not supported" pp_base base1
    else
      let length1 = mk_length_var base1 range in
      let lengths = List.map (fun b -> mk_length_var b range) bases in
      man.post ~zone:Z_u_num (mk_expand length1 lengths range) flow


  (** Forget the value of the length variable of a base *)
  let forget e range man flow =
    (* Get the pointed base *)
    let ptr = match ekind e with
      | E_var _   -> mk_c_address_of e range
      | E_c_deref(p) -> p
      | _ -> assert false
    in
    man.eval ptr ~zone:(Z_c_low_level,Z_c_points_to) flow >>$ fun p flow ->
    match ekind p with
    | E_c_points_to(P_block({ base_kind = String _ },offset,mode)) ->
      Post.return flow

    | E_c_points_to(P_block(base,offset,mode)) when is_interesting_base base ->
      (* FIXME: we can do better by checking if the offset affect the length of the string *)
      let length = mk_length_var base range in
      eval_base_size base range man flow >>$ fun size flow ->
      man.eval ~zone:(Z_c_scalar, Z_u_num) size flow >>$ fun size flow ->
      man.post ~zone:Z_u_num (mk_forget length range) flow >>$ fun () flow ->
      man.post ~zone:Z_u_num (mk_assume (mk_in length (mk_zero range) size range) range) flow


    | _ -> Post.return flow


  let rec is_deref_expr e =
    match ekind e with
    | E_c_deref _ -> true
    | E_c_cast (ee, _) -> is_deref_expr ee
    | _ -> false



  (** Declaration of a C variable *)
  let declare_variable v scope range man flow =
    let base = mk_var_base v in
    if not (is_interesting_base base)
    then Post.return flow
    else add_base base range man flow



  (** Cases of the assignment abstract transformer *)
  let assign_cases base offset rhs mode typ range man flow =
    eval_base_size base range man flow >>$ fun size flow ->
    man.eval ~zone:(Z_c_scalar, Z_u_num) size flow >>$ fun size flow ->

    let length = mk_length_var base ~mode range in

    (* Compute the offset in bytes *)
    let elm_size = sizeof_type typ in

    (* Utility function to assign an interval *)
    let assign_interval l u flow =
      man.post ~zone:Z_u_num (mk_forget length range) flow |>
      Post.bind (
        man.post ~zone:Z_u_num (mk_assume ((mk_in length l u range)) range)
      )
    in

    (* Check that offset ∈ [0, size - elm_size] *)
    assume (mk_in offset (mk_zero range) (sub size (mk_z elm_size range) range) range)
      ~fthen:(fun flow ->
          if not (is_interesting_base base)
          then
            Post.return flow

          else if Z.gt elm_size Z.one
          then
            (* FIXME: assignments of multi-bytes not supported for the moment *)
            assign_interval (mk_zero range) size flow
          else
            switch [
              (* set0 case *)
              (* Offset condition: offset ∈ [0, length] *)
              (* RHS condition: rhs = 0 *)
              (* Transformation: length := offset; *)
              [
                mk_in offset (mk_zero range) length range;
                mk_binop rhs O_eq (mk_zero range) range;
              ],
              (fun flow -> man.post ~zone:Z_u_num (mk_assign length offset range) flow)
              ;

              (* setnon0 case *)
              (* Offset condition: offset = length *)
              (* RHS condition: rhs ≠ 0 *)
              (* Transformation: length := [offset + 1, size]; *)
              [
                mk_binop offset O_eq length range;
                mk_binop rhs O_ne (mk_zero range) range;
              ],
              (fun flow -> assign_interval (add offset (one range) range) size flow)
              ;

              (* First unchanged case *)
              (* Offset condition: offset ∈ [0, length[ *)
              (* RHS condition: rhs ≠ 0 *)
              (* Transformation: nop; *)
              [
                mk_in ~right_strict:true offset (mk_zero range) length range;
                mk_binop rhs O_ne (mk_zero range) range;
              ],
              (fun flow -> Post.return flow)
              ;

              (* Second unchanged case *)
              (* Offset condition: offset > length *)
              (* RHS condition: ⊤ *)
              (* Transformation: nop; *)
              [
                mk_binop offset O_gt length range;
              ],
              (fun flow -> Post.return flow)


            ] ~zone:Z_u_num man flow
        )
      ~felse:(fun flow ->
          (* Unsafe case *)
          Flow.set_bottom T_cur flow |>
          Post.return
        )
      ~zone:Z_u_num man flow


  (** Assignment abstract transformer for 𝕊⟦ *p = rval; ⟧ *)
  let assign_deref p rval range man flow =
    eval_pointed_base_offset p range man flow >>$ fun (base,offset,mode) flow ->
    man.eval ~zone:(Z_c_low_level,Z_u_num) rval flow >>$ fun rval flow ->
    man.eval ~zone:(Z_c_scalar, Z_u_num) offset flow >>$ fun offset flow ->
    assign_cases base offset rval mode (under_type p.etyp |> void_to_char) range man flow



  (** Cases of the abstract transformer for tests *(p + i) == 0 *)
  let assume_zero_cases base offset mode range man flow =
    eval_base_size base range man flow >>$ fun size flow ->
    man.eval ~zone:(Z_c_scalar, Z_u_num) size flow >>$ fun size flow ->
    man.eval ~zone:(Z_c_scalar, Z_u_num) offset flow >>$ fun offset flow ->

    let length =
      match base.base_kind with
      | String str -> mk_z (Z.of_int @@ String.length str) range
      | _ -> mk_length_var base ~mode range
    in

    (* Safety condition: offset ⊆ [0, size[ *)
    assume
      (mk_in offset (mk_zero range) size ~right_strict:true range)
      ~fthen:(fun flow ->
          (* Safe case *)
          man.post ~zone:Z_u_num (mk_assume (mk_binop offset O_ge length range) range) flow
        )
      ~felse:(fun flow ->
          (* Unsafe case *)
          Flow.set_bottom T_cur flow |>
          Post.return
        )
      ~zone:Z_u_num man flow


  (** Cases of the abstract transformer for tests *(p + ∀i) != 0 *)
  let assume_quantified_non_zero_cases base offset mode range man flow =
    (** Get symbolic bounds of the offset *)
    let min, max = Common.Quantified_offset.bound offset in

    eval_base_size base range man flow >>$ fun size flow ->
    man.eval ~zone:(Z_c_scalar, Z_u_num) size flow >>$ fun size flow ->
    man.eval ~zone:(Z_c, Z_u_num) min flow >>$ fun min flow ->
    man.eval ~zone:(Z_c, Z_u_num) max flow >>$ fun max flow ->

    let length =
      match base.base_kind with
      | String str -> mk_z (Z.of_int @@ String.length str) range
      | _ -> mk_length_var base ~mode range
    in
    let mk_bottom flow = Flow.set T_cur man.lattice.bottom man.lattice flow in

    (* Safety condition: [min, max] ⊆ [0, size[ *)
    assume (
      mk_binop
        (mk_in min (mk_zero range) size ~right_strict:true range)
        O_log_and
        (mk_in max (mk_zero range) size ~right_strict:true range)
        range
    )
      ~fthen:(fun flow ->
          switch [
            (* nonzero case *)
            (* Range condition: max < length

               |--------|***********|---------|--------|->
               0       min         max     length     size

                     ∀ i ∈ [min, max] : s[i] != 0
            *)
            (* Transformation: nop *)
            [
              mk_binop max O_lt length range;
            ],
            (fun flow -> Post.return flow)
            ;

            (* zero case *)
            (* Range condition: length ≤ max

               |--------|***********|********|-------|->
               0       min        length    max     size

                      ∃ i ∈ [min, max] : s[i] == 0
            *)
            (* Transformation: ⊥ *)
            [
              mk_in max length size range;
            ],
            (fun flow -> Post.return (mk_bottom flow))
            ;
          ] ~zone:Z_u_num man flow
        )
      ~felse:(fun flow ->
          (* FIXME: remove qunatifiers from offset *)
          Flow.set_bottom T_cur flow |>
          Post.return
        )
      ~zone:Z_u_num man flow




  (** Cases of the abstract transformer for tests *(p + ∀i) == 0 *)
  let assume_quantified_zero_cases base offset mode range man flow =
    (** Get symbolic bounds of the offset *)
    let min, max = Common.Quantified_offset.bound offset in

    eval_base_size base range man flow >>$ fun size flow ->
    man.eval ~zone:(Z_c_scalar, Z_u_num) size flow >>$ fun size flow ->
    man.eval ~zone:(Z_c, Z_u_num) min flow >>$ fun min flow ->
    man.eval ~zone:(Z_c, Z_u_num) max flow >>$ fun max flow ->

    let length =
      match base.base_kind with
      | String str -> mk_z (Z.of_int @@ String.length str) range
      | _ -> mk_length_var base ~mode range
    in
    let mk_bottom flow = Flow.bottom_from flow in

    (* Safety condition: [min, max] ⊆ [0, size[ *)
    assume (
      mk_binop
        (mk_in min (mk_zero range) size ~right_strict:true range)
        O_log_and
        (mk_in max (mk_zero range) size ~right_strict:true range)
        range
    )
      ~fthen:(fun flow ->
          switch [
            (* Range condition: min < length

               |--------|***********|********|-------|->
               0       min        length    max     size

                      ∃ i ∈ [min, max] : s[i] != 0
            *)
            (* Transformation: ⊥ *)
            [
              mk_binop min O_lt length range;
            ],
            (fun flow -> Post.return (mk_bottom flow))
            ;

            (* Range condition: min >= length

               |--------|----------|************|-------|->
               0       length     min          max     size
            *)
            (* Transformation: nop *)
            [
              mk_binop min O_ge length range;
            ],
            (fun flow -> Post.return flow)
            ;


          ] ~zone:Z_u_num man flow
        )
      ~felse:(fun flow ->
          (* FIXME: remove qunatifiers from offset *)
          Flow.set_bottom T_cur flow |>
          Post.return
        )
      ~zone:Z_u_num man flow


  (** Abstract transformer for tests *p op 0 *)
  let assume_zero op lval range man flow =
    let p =
      let rec doit e =
        match ekind e with
        | E_c_deref p -> p
        | E_c_cast(ee, _) -> doit ee
        | _ -> panic_at range "assume_zero: invalid argument %a" pp_expr lval;
      in
      doit lval
    in

    eval_pointed_base_offset p range man flow >>$ fun (base,offset,mode) flow ->
    if not (is_interesting_base base)
    then Post.return flow

    else if op = O_ne && is_expr_forall_quantified offset
    then assume_quantified_non_zero_cases base offset mode range man flow

    else if op = O_eq && is_expr_forall_quantified offset
    then assume_quantified_zero_cases base offset mode range man flow

    else if op = O_eq && not (is_expr_forall_quantified offset)
    then assume_zero_cases base offset mode range man flow

    else Post.return flow


  (** Test first if n == 0, and then call assume_zero to do the work *)
  let assume_not_sure_zero op lval n range man flow =
    assume (mk_binop n O_eq (mk_zero range) range)
      ~fthen:(fun flow -> assume_zero op lval range man flow)
      ~felse:(fun flow -> Post.return flow)
      ~zone:Z_c_low_level man flow


  let rec is_zero_expr e =
    match c_expr_to_z e with
    | None -> false
    | Some z -> Z.equal z Z.zero


  (** Transformers entry point *)
  let exec zone stmt man flow =
    match skind stmt with
    | S_c_declaration (v,init,scope) when not (is_c_scalar_type v.vtyp) ->
      declare_variable v scope stmt.srange man flow |>
      OptionExt.return

    | S_add e when is_base_expr e ->
      add_base (expr_to_base e) stmt.srange man flow |>
      OptionExt.return


    | S_rename (e1,e2) when is_base_expr e1 && is_base_expr e2 ->
      rename_base (expr_to_base e1) (expr_to_base e2) stmt.srange man flow |>
      OptionExt.return

    | S_expand(e,el) when is_base_expr e && List.for_all is_base_expr el ->
      expand_base (expr_to_base e) (List.map expr_to_base el) stmt.srange man flow |>
      OptionExt.return

    | S_forget(e) ->
      forget e stmt.srange man flow |>
      OptionExt.return

    | S_remove(e) when is_base_expr e ->
      remove_base (expr_to_base e) stmt.srange man flow |>
      OptionExt.return

    | S_assign({ ekind = E_c_deref p}, rval)
      when under_type p.etyp |> void_to_char |> is_c_num_type
      ->
      assign_deref p rval stmt.srange man flow |>
      OptionExt.return

    (* 𝕊⟦ *(p + i) == 0 ⟧ *)
    | S_assume({ ekind = E_binop(O_eq, lval, n)})
    | S_assume({ ekind = E_unop(O_log_not, { ekind = E_binop(O_ne, lval, n)} )})
      when is_c_int_type lval.etyp &&
           is_deref_expr lval &&
           not (is_expr_forall_quantified n)
      ->
      assume_not_sure_zero O_eq lval n stmt.srange man flow |>
      OptionExt.return

    (* 𝕊⟦ !*(p + i) ⟧ *)
    | S_assume({ ekind = E_unop(O_log_not,lval)})
      when is_c_int_type lval.etyp &&
           is_deref_expr lval
      ->
      assume_zero O_eq lval stmt.srange man flow |>
      OptionExt.return

    (* 𝕊⟦ *(p + i) != 0 ⟧ *)
    | S_assume({ ekind = E_binop(O_ne, lval, n)})
    | S_assume({ ekind = E_unop(O_log_not, { ekind = E_binop(O_eq, lval, n)} )})
      when is_c_int_type lval.etyp &&
           is_deref_expr lval &&
           not (is_expr_forall_quantified n)
      ->
      assume_not_sure_zero O_ne lval n stmt.srange man flow |>
      OptionExt.return

    (* 𝕊⟦ *(p + i) ⟧ *)
    | S_assume(lval)
      when is_c_int_type lval.etyp &&
           is_deref_expr lval
      ->
      assume_zero O_ne lval stmt.srange man flow |>
      OptionExt.return



    | _ -> None


  (** {2 Abstract evaluations} *)
  (** ************************ *)

  let eval zone exp man flow = None


  (** {2 Query handler} *)
  (** ***************** *)

  let ask query man flow = None


end

let () =
  Core.Sig.Stacked.Stateless.register_stack (module Domain)

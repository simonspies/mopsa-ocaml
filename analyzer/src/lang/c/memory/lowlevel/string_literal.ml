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

(** Domain for handling string literals. *)


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
open Universal.Numeric.Common


module Domain =
struct

  (** {2 Domain header} *)
  (** ***************** *)

  include GenStatelessDomainId(struct
      let name = "c.memory.lowlevel.string_literal"
    end)

  let interface = {
    iexec = {
      provides = [Z_c_low_level];
      uses = [
        Z_u_num;
        Z_c_low_level
      ];
    };
    ieval = {
      provides = [Z_c_low_level, Z_c_scalar];
      uses = [
        Z_c_scalar, Z_u_num;
        Z_c_low_level, Z_c_points_to;
      ];
    }
  }

  let alarms = []


  (** {2 Initialization procedure} *)
  (** **************************** *)

  let init prog man flow = flow


  (** {2 Utility functions} *)
  (** ********************* *)

  (** [is_char_deref lval] checks whether [lval] is a dereference of a char pointer *)
  let is_char_deref lval =
    match remove_casts lval |> ekind with
    | E_c_deref p ->
      begin match under_type p.etyp |> remove_qual with
        | T_c_void -> true
        | T_c_integer (C_signed_char | C_unsigned_char) -> true
        | _ -> false
      end
    | _ -> false

  let is_int_deref lval =
    match remove_casts lval |> ekind with
    | E_c_deref p -> is_c_int_type (under_type p.etyp)
    | _ -> false


  (** {2 Abstract transformers} *)
  (** ************************* *)


  (** Cases of the abstract transformer for tests *(str + ∀i) != 0 *)
  let assume_quantified_non_zero_cases str t boffset range man flow =
    (** Get symbolic bounds of the offset *)
    let char_size = sizeof_type t in
    match Common.Quantified_offset.bound_div boffset char_size man flow with
    | Top.TOP -> Post.return flow
    | Top.Nt (min,max) ->
    man.eval ~zone:(Z_c_scalar, Z_u_num) min flow >>$ fun min flow ->
    man.eval ~zone:(Z_c_scalar, Z_u_num) max flow >>$ fun max flow ->

    let length = mk_z (Z.(div (of_int @@ String.length str) (sizeof_type t))) range in

    let mk_bottom flow = Flow.set T_cur man.lattice.bottom man.lattice flow in

    (* Safety condition: [min, max] ⊆ [0, length] *)
    assume (
      mk_binop
        (mk_in min (mk_zero range) length range)
        O_log_and
        (mk_in max (mk_zero range) length range)
        range
    )
      ~fthen:(fun flow ->
          switch [
            (* nonzero case *)
            (* Range condition: max < length

               |--------|***********|---------|--------->
               0       min         max     length

                     ∀ i ∈ [min, max] : s[i] != 0
            *)
            (* Transformation: nop *)
            [
              mk_binop max O_lt length range;
            ],
            (fun flow -> Post.return flow)
            ;

            (* zero case *)
            (* Range condition: length = max

                                          length
               |--------|*******************|--------->
               0       min                 max

                      ∃ i ∈ [min, max] : s[i] == 0
            *)
            (* Transformation: ⊥ *)
            [
              mk_binop max O_eq length range;
            ],
            (fun flow -> Post.return (mk_bottom flow))
            ;
          ] ~zone:Z_u_num man flow
        )
      ~felse:(fun flow ->
          Flow.set_bottom T_cur flow |>
          Post.return
        )
      ~zone:Z_u_num man flow




  (** Cases of the abstract transformer for tests *(str + ∀i) == 0 *)
  let assume_quantified_zero_cases str t boffset range man flow =
    (** Get symbolic bounds of the offset *)
    let char_size = sizeof_type t in
    match Common.Quantified_offset.bound_div boffset char_size man flow with
    | Top.TOP -> Post.return flow
    | Top.Nt (min,max) ->
    man.eval ~zone:(Z_c_scalar, Z_u_num) min flow >>$ fun min flow ->
    man.eval ~zone:(Z_c_scalar, Z_u_num) max flow >>$ fun max flow ->

    let length = mk_z (Z.(div (of_int @@ String.length str) (sizeof_type t))) range in
    let mk_bottom flow = Flow.bottom_from flow in

    (* Safety condition: [min, max] ⊆ [0, length] *)
    assume (
      mk_binop
        (mk_in min (mk_zero range) length range)
        O_log_and
        (mk_in max (mk_zero range) length range)
        range
    )
      ~fthen:(fun flow ->
          switch [
            (* Range condition: min < length

               |--------|*************|-----|----->
               0       min           max  length

                      ∃ i ∈ [min, max] : s[i] != 0
            *)
            (* Transformation: ⊥ *)
            [
              mk_binop min O_lt length range;
            ],
            (fun flow -> Post.return (mk_bottom flow))
            ;

            (* Range condition: min = length

                      length
               |--------|--------------->
               0      min,max
            *)
            (* Transformation: nop *)
            [
              mk_binop min O_eq length range;
            ],
            (fun flow -> Post.return flow)
            ;


          ] ~zone:Z_u_num man flow
        )
      ~felse:(fun flow ->
          Flow.set_bottom T_cur flow |>
          Post.return
        )
      ~zone:Z_u_num man flow

  (** Get the string and offset pointed by lval. Ignore flows where lval is not a string *)
  let extract_string_base lval range man flow =
    let p =
      let rec doit e =
        match ekind e with
        | E_c_deref p -> p
        | E_c_cast(ee, _) -> doit ee
        | _ -> panic_at range "assume_zero: invalid argument %a" pp_expr lval;
      in
      doit lval
    in
    man.eval p ~zone:(Z_c_low_level, Z_c_points_to) flow >>$ fun pt flow ->
    match ekind pt with
    | E_c_points_to (P_block ({ base_kind = String (str,_,t) }, boffset, mode)) when sizeof_type t = sizeof_type (under_type p.etyp) ->
      Cases.singleton (str,t,boffset) flow

    | _ ->
      Cases.empty_singleton flow

  (** Abstract transformer for tests *(str + ∀offset) op 0 *)
  let assume_quantified_op_zero op str t boffset range man flow =
    if op = O_ne
    then assume_quantified_non_zero_cases str t boffset range man flow

    else if op = O_eq
    then assume_quantified_zero_cases str t boffset range man flow

    else Post.return flow

  (** Abstract transformer for tests *(lval + ∀offset) op 0 *)
  let assume_quantified_zero op lval range man flow =
    extract_string_base lval range man flow >>$ fun (str,t,boffset) flow ->
    assume_quantified_op_zero op str t boffset range man flow


  (** Abstract transformer for tests *(lval + ∀offset) op n *)
  let assume_quantified op lval n range man flow =
    extract_string_base lval range man flow >>$ fun (str,t,boffset) flow ->
    match c_expr_to_z boffset with
    | Some n when Z.(n != zero) -> Post.return flow
    | Some n -> assume_quantified_op_zero op str t boffset range man flow
    | None ->
      assume (mk_binop n O_eq (mk_zero range) range)
        ~fthen:(fun flow -> assume_quantified_op_zero op str t boffset range man flow)
        ~felse:(fun flow -> Post.return flow)
        ~zone:Z_c_low_level man flow


  (** Abstract transformer for tests *(p + i) == n *)
  let assume_eq_const (lval:expr) (n:Z.t) range man flow =
    extract_string_base lval range man flow >>$ fun (str,t,boffset) flow ->
    let char_size = Z.to_int (sizeof_type t) in
    let blen = String.length str in
    (* When n = 0, require that offset = len(str) *)
    if Z.(n = zero) then
      man.post (mk_assume (mk_binop boffset O_eq (mk_int blen range) range) range) ~zone:Z_c_scalar flow
    else if char_size = 1 then
      (* Search for the first and last positions of `n` in `str` *)
      let c = Z.to_int n |> Char.chr in
      if not (String.contains str c) then
        Post.return (Flow.bottom_from flow)
      else
        let l = String.index str c in
        let u = String.rindex str c in
        let pos =
          if l = u then mk_int l range
          else mk_int_interval l u range
        in
        (* Require that offset is equal to pos *)
        man.post (mk_assume (mk_binop boffset O_eq pos range) range) ~zone:Z_c_scalar flow
    else
      man.post (mk_assume (mk_binop boffset O_le (mk_int (blen-char_size) range) range) range) ~zone:Z_c_scalar flow


  (** Transformers entry point *)
  let exec zone stmt man flow =
    match skind stmt with
    (* 𝕊⟦ *(p + ∀i) == 0 ⟧ *)
    | S_assume({ ekind = E_binop(O_eq, lval, n)})
    | S_assume({ ekind = E_unop(O_log_not, { ekind = E_binop(O_ne, lval, n)} )})
      when is_int_deref lval &&
           is_lval_offset_forall_quantified lval &&
           not (is_expr_forall_quantified n)
      ->
      assume_quantified O_eq lval n stmt.srange man flow |>
      OptionExt.return

    (* 𝕊⟦ !*(p + ∀i) ⟧ *)
    | S_assume({ ekind = E_unop(O_log_not,lval)})
      when is_int_deref lval &&
           is_lval_offset_forall_quantified lval
      ->
      assume_quantified_zero O_eq lval stmt.srange man flow |>
      OptionExt.return

    (* 𝕊⟦ *(p + ∀i) != 0 ⟧ *)
    | S_assume({ ekind = E_binop(O_ne, lval, n)})
    | S_assume({ ekind = E_unop(O_log_not, { ekind = E_binop(O_eq, lval, n)} )})
      when is_int_deref lval &&
           is_lval_offset_forall_quantified lval &&
           not (is_expr_forall_quantified n)
      ->
      assume_quantified O_ne lval n stmt.srange man flow |>
      OptionExt.return

    (* 𝕊⟦ *(p + ∀i) ⟧ *)
    | S_assume(lval)
      when is_int_deref lval &&
           is_lval_offset_forall_quantified lval
      ->
      assume_quantified_zero O_ne lval stmt.srange man flow |>
      OptionExt.return

    (* 𝕊⟦ *(p + i) == n ⟧ *)
    | S_assume({ ekind = E_binop(O_eq, lval, n)})
    | S_assume({ ekind = E_unop(O_log_not, { ekind = E_binop(O_ne, lval, n)} )})
      when is_int_deref lval &&
           not (is_expr_forall_quantified lval) &&
           not (is_expr_forall_quantified n) &&
           is_c_constant n
      ->
      assume_eq_const lval (c_expr_to_z n |> Option.get) stmt.srange man flow |>
      OptionExt.return

    | _ -> None


  (** {2 Abstract evaluations} *)
  (** ************************ *)

  (** Evaluate a dereference *p *)
  let eval_deref p range man flow =
    man.eval p ~zone:(Z_c_low_level, Z_c_points_to) flow >>$ fun pt flow ->
    match ekind pt with
    | E_c_points_to (P_block ({ base_kind = String (str,_,t) }, boffset, mode))
        when sizeof_type t = sizeof_type (under_type p.etyp) ->
      let char_size = sizeof_type t in
      let offset =
        if char_size = Z.one then boffset
        else div boffset (mk_z char_size range) range
      in
      let length = Z.(div (of_int (String.length str)) char_size) in
      man.eval offset ~zone:(Z_c_scalar,Z_u_num) flow >>$ fun offset flow ->
      switch [
        [mk_binop offset O_eq (mk_z length range) range],
        (fun flow -> Eval.singleton (mk_zero ~typ:(under_type p.etyp) range) flow);

        [mk_in offset (mk_zero range) (mk_z (Z.pred length) range) range],
        (fun flow ->
           (* Get the interval of the offset *)
           let itv = man.ask (mk_int_interval_query offset) flow in
           (* itv should be included in [0,length-1] *)
           let max = I.of_z Z.zero (Z.pred length) in
           begin match I.meet_bot itv (Bot.Nb max) with
             | Bot.BOT -> Eval.empty_singleton flow
             | Bot.Nb itv' ->
               (* Get the interval of possible chars *)
               let indexes = I.to_list itv' in
               let char_at i =
                 I.cst (extract_multibyte_integer str (Z.to_int (Z.mul char_size i)) t)
               in
               let chars =
                 List.fold_left (fun acc i -> char_at i :: acc)
                   [char_at (List.hd indexes)] (List.tl indexes)
               in
               let l,u =
                 match I.join_list chars |> Bot.bot_to_exn with
                 | I.B.Finite l, I.B.Finite u -> l,u
                 | _ -> assert false
               in
               if Z.equal l u
               then Eval.singleton (mk_z l ~typ:(under_type p.etyp) range) flow
               else Eval.singleton (mk_z_interval l u ~typ:(under_type p.etyp) range) flow
           end
        )
      ] ~zone:Z_u_num man flow

    | _ ->
      Eval.singleton (mk_top (under_type p.etyp) range) flow


  let eval zone exp man flow =
    match ekind exp with
    | E_c_deref(p) when is_int_deref exp &&
                        not (is_pointer_offset_forall_quantified p)
      ->
      eval_deref p exp.erange man flow |>
      OptionExt.return

    | _ -> None


  (** {2 Query handler} *)
  (** ***************** *)

  let ask query man flow = None


end

let () =
  Core.Sig.Stacked.Stateless.register_stack (module Domain)
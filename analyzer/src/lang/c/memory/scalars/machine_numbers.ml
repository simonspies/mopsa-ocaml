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

(** Machine representation of C integers and floats *)

open Mopsa
open Framework.Core.Sig.Stacked.Stateless
open Universal.Ast
open Ast
open Zone
open Universal.Zone
open Common.Alarms
open Common.Points_to
module Itv = Universal.Numeric.Values.Intervals.Integer.Value



module Domain =
struct

  (** Domain identification *)
  (** ===================== *)

  include GenStatelessDomainId(struct
      let name = "c.memory.scalars.machine_numbers"
    end)

  (** Zoning definition *)
  (** ================= *)

  let interface = {
    iexec = {
      provides = [Z_c_scalar];
      uses = [
        Z_c_scalar;
        Z_u_num
      ];
    };
    ieval = {
      provides = [Z_c_scalar, Z_u_num];
      uses = [
        Z_c_scalar, Z_u_num;
        Z_c_scalar, Z_c_points_to
      ];
    }
  }


  (** Command-line options *)
  (** ==================== *)

  let opt_ignore_cast_alarm = ref false

  let () =
    register_domain_option name {
      key = "-ignore-cast-overflow";
      category = "C";
      doc = " do not raise integer overflow alarms in explicit casts";
      spec = ArgExt.Set opt_ignore_cast_alarm;
      default = "false";
    }


  let opt_detect_unsigned_wrap = ref false

  let () =
    register_domain_option name {
      key = "-detect-unsigned-wrap";
      category = "C";
      doc = " raise integer overflow alarms when an unsigned integer wraps around";
      spec = ArgExt.Set opt_detect_unsigned_wrap;
      default = "false";
    }


  (** Numeric variables *)
  (** ================= *)

  (** Kind of mathematical numeric variables encoding the value of C numeric
      variables (integers and floats)
  *)
  type var_kind += V_c_num of var

  let () =
    register_var {
      print = (fun next fmt v ->
          match v.vkind with
          | V_c_num vv -> pp_var fmt vv
          | _ -> next fmt v
        );
      compare = (fun next v1 v2 ->
          match v1.vkind, v2.vkind with
          | V_c_num vv1, V_c_num vv2 -> compare_var vv1 vv2
          | _ -> next v1 v2
        );
    }

  let to_num_type t =
    match t with
    | T_bool | T_int | T_float _ | T_any -> t
    | _ ->
      match remove_typedef_qual t with
      | T_c_bool -> T_bool
      | T_c_integer _ -> T_int
      | T_c_enum _ -> T_int
      | T_c_float C_float -> T_float F_SINGLE
      | T_c_float C_double -> T_float F_DOUBLE
      | T_c_float C_long_double -> T_float F_LONG_DOUBLE
      | _ -> panic ~loc:__LOC__ "non integer type %a" pp_typ t

  let mk_num_var v =
    mkv v.vname (V_c_num v) (to_num_type v.vtyp)

  let mk_num_var_expr e =
    match ekind e with
    | E_var (v,mode) -> mk_var (mk_num_var v) ~mode e.erange
    | _ -> assert false


  (** Utility functions *)
  (** ================= *)

  let range_leq (a,b) (c,d) =
    Z.leq c a && Z.leq b d

  let wrap_z (z : Z.t) ((l,h) : Z.t * Z.t) : Z.t =
    Z.( l + ((z - l) mod (h-l+one)) )

  let is_c_int_op = function
    | O_div | O_mod | O_mult | O_plus | O_minus -> true
    | _ -> false

  let is_c_div = function
    | O_div | O_mod -> true
    | _ -> false

  let is_c_shift = function
    | O_bit_lshift | O_bit_rshift -> true
    | _ -> false

  let check_overflow typ man range f1 f2 exp flow =
    let rmin, rmax = rangeof typ in

    let rec const_check e flow =
      match ekind e with
      | E_constant (C_int n) ->
        if Z.leq rmin n && Z.leq n rmax
        then f1 e flow
        else f2 e flow

      | E_constant (C_int_interval (a,b)) ->
        let case1 =
          let a' = Z.max a rmin and b' = Z.min b rmax in
          if Z.leq a' b'
          then
            let e' = mk_z_interval a' b' range in
            [f1 e' flow]
          else
            []
        in
        let case2 =
          if Z.gt rmin a || Z.lt rmax b
          then
            [f2 e flow]
          else
            []
        in
        Eval.join_list (case1 @ case2) ~empty:(Eval.empty_singleton flow)

      | _ -> fast_check e flow

    and fast_check e flow =
      let itv = man.ask (Universal.Numeric.Common.mk_int_interval_query e) flow in
      if Itv.is_bottom itv then Eval.empty_singleton flow
      else
      if Itv.is_bounded itv then
        let l, u = Itv.bounds itv in
        if Z.geq l rmin && Z.leq u rmax then f1 e flow
        else if Z.lt u rmin || Z.gt l rmax then f2 e flow
        else full_check e flow
      else
        full_check e flow

    and full_check e flow =
      let cond = range_cond e rmin rmax (erange e) in
      assume
        ~zone:Z_u_num
        cond
        ~fthen:(fun tflow -> f1 e tflow)
        ~felse:(fun fflow -> f2 e fflow)
        man flow
    in
    const_check exp flow

  let check_division man range f1 f2 e e' flow =
    let rec fast_check () =
      let itv = man.ask (Universal.Numeric.Common.mk_int_interval_query e') flow in
      if Itv.is_bottom itv then Eval.empty_singleton flow
      else
      if Itv.is_bounded itv then
        let l, u = Itv.bounds itv in
        if Z.gt l Z.zero || Z.lt u Z.zero then f1 flow
        else if Z.equal u Z.zero && Z.equal l Z.zero then f2 flow
        else full_check ()
      else
        full_check ()

    and full_check () =
      let cond = mk_binop e' O_eq (mk_zero range) ~etyp:T_bool range in
      assume
        ~zone:Z_u_num
        cond
        ~fthen:(fun tflow -> f2 tflow)
        ~felse:(fun fflow -> f1 fflow)
        man flow
    in
    fast_check ()


  (** Check that bit-shifts are safe. Two conditions are verified: (i)
      the shift position is positive and (ii) does not exceed the size
      of the shifted value 
  *)
  let check_shift n t range fsafe funsafe man flow =
    (* Condition: n ∈ [0, bits(t) - 1] *)
    let bits = sizeof_type t |> Z.mul (Z.of_int 8) in
    let cond = mk_in n (mk_zero range) (mk_z (Z.pred bits) range) range in
    assume cond
      ~fthen:(fun flow -> fsafe flow)
      ~felse:(fun flow -> funsafe flow)
      ~zone:Z_u_num man flow
      

  
  let rec is_compare_expr e =
    match ekind e with
    | E_binop(op, e1, e2) when is_comparison_op op -> true
    | E_binop(op, e1, e2) when is_logic_op op -> true
    | E_unop(O_log_not, ee) -> is_compare_expr ee
    | E_c_cast(ee,_) -> is_compare_expr ee
    | _ -> false


  let rec to_compare_expr e =
    match ekind e with
    | E_binop(op, e1, e2) when is_comparison_op op ->
      e

    | E_binop(op, e1, e2) when is_logic_op op ->
      { e with ekind = E_binop(op, to_compare_expr e1, to_compare_expr e2) }

    | E_unop(O_log_not, ee) -> 
      { e with ekind = E_unop(O_log_not, to_compare_expr ee) }

    | _ ->
      mk_binop e O_ne (mk_zero e.erange) e.erange


  (** Transfer functions *)
  (** ================== *)

  let eval_binop op e e' exp man flow =
    man.eval ~zone:(Z_c_scalar, Z_u_num) e flow >>$ fun e flow ->
    man.eval ~zone:(Z_c_scalar, Z_u_num) e' flow >>$ fun e' flow ->

    let exp' = {exp with
                ekind = E_binop(op, e, e');
                etyp = to_num_type exp.etyp
               }
    in
    Eval.singleton exp' flow


  let eval_unop op e exp man flow =
    man.eval ~zone:(Z_c_scalar, Z_u_num) e flow >>$ fun e flow ->
    let exp' = {exp with
                ekind = E_unop(op, e);
                etyp = to_num_type exp.etyp
               }
    in
    Eval.singleton exp' flow


  let eval zone exp man flow =
    let range = erange exp in
    match ekind exp with
    | E_binop(op, e, e') when op |> is_c_div &&
                              (e    |> etyp |> is_c_int_type &&
                               e'   |> etyp |> is_c_int_type)
      ->
      man.eval ~zone:(Z_c_scalar, Z_u_num) e flow >>$? fun e flow ->
      man.eval ~zone:(Z_c_scalar, Z_u_num) e' flow >>$? fun e' flow ->
      check_division man range
        (fun tflow ->
           let exp' = mk_binop e op e' ~etyp:(to_num_type exp.etyp) range in
           Eval.singleton exp' tflow
        )
        (fun fflow ->
           let flow' = raise_c_alarm ADivideByZero exp.erange ~bottom:true man.lattice fflow in
           Eval.empty_singleton flow'
        ) e e' flow |>
      Option.return

    | E_binop(op, e, e') when op |> is_c_shift &&
                              (e    |> etyp |> is_c_int_type &&
                               e'   |> etyp |> is_c_int_type)
      ->
      let t = e.etyp in
      man.eval ~zone:(Z_c_scalar, Z_u_num) e flow >>$? fun e flow ->
      man.eval ~zone:(Z_c_scalar, Z_u_num) e' flow >>$? fun e' flow ->
      check_shift e' t range
        (fun tflow ->
           let exp' = mk_binop e op e' ~etyp:(to_num_type exp.etyp) range in
           Eval.singleton exp' tflow
        )
        (fun fflow ->
           let flow' = raise_c_alarm AInvalidBitShift exp.erange ~bottom:true man.lattice fflow in
           Eval.empty_singleton flow'
        ) man flow |>
      Option.return

    | E_unop(op, e) when is_c_int_op op &&
                         e |> etyp |> is_c_int_type ->
      let typ = etyp exp in
      let rmin, rmax = rangeof typ in
      eval_unop op e exp man flow >>$? fun e flow ->
      check_overflow typ man range
        (fun e tflow -> Eval.singleton e tflow)
        (fun e fflow ->
           let flow1 = raise_c_integer_overflow_alarm e typ exp.erange man fflow in
           Eval.singleton (mk_unop (O_wrap(rmin, rmax)) e ~etyp:(to_num_type typ) range) flow1
        ) e flow |>
      Option.return

    | E_binop(op, e, e') when is_c_int_op op &&
                              (exp  |> etyp |> is_c_int_type &&
                               e    |> etyp |> is_c_int_type &&
                               e'   |> etyp |> is_c_int_type)
      ->
      let typ = etyp exp in
      let rmin, rmax = rangeof typ in
      eval_binop op e e' exp man flow >>$? fun e flow ->
      check_overflow typ man range
        (fun e tflow -> Eval.singleton e tflow)
        (fun e fflow ->
           let e' = mk_unop (O_wrap(rmin, rmax)) e ~etyp:(to_num_type typ) range in
           if not (is_signed typ) && not !opt_detect_unsigned_wrap
           then Eval.singleton e' fflow
           else
             let flow1 = raise_c_integer_overflow_alarm e typ exp.erange man fflow in
             Eval.singleton e' flow1
        ) e flow |>
      Option.return

    | E_c_cast(e, _) when exp |> etyp |> is_c_float_type &&
                          e   |> etyp |> is_c_int_type ->
      man.eval ~zone:(Z_c_scalar, Z_u_num) e flow >>$? fun e flow ->
      let exp' = mk_unop
          (O_cast (to_num_type e.etyp, to_num_type exp.etyp))
          e
          ~etyp:(to_num_type exp.etyp) exp.erange
      in
      Eval.singleton exp' flow |>
      Option.return

    | E_c_cast(p, _) when exp |> etyp |> is_c_int_type &&
                          p   |> etyp |> is_c_pointer_type ->
      man.eval ~zone:(Z_c_scalar, Z_c_points_to) p flow >>$? fun pt flow ->
      let exp' =
        match ekind pt with
        | E_c_points_to P_null -> mk_zero exp.erange
        | _ ->
          let l,u = rangeof exp.etyp in
          mk_z_interval l u exp.erange
      in
      Eval.singleton exp' flow |>
      Option.return


    | E_c_cast(e, _) when exp |> etyp |> is_c_int_type &&
                          e   |> etyp |> is_c_float_type ->
      man.eval ~zone:(Z_c_scalar, Z_u_num) e flow >>$? fun e flow ->
      let exp' = mk_unop
          (O_cast (to_num_type e.etyp, to_num_type exp.etyp))
          e
          ~etyp:(to_num_type exp.etyp) exp.erange
      in
      Eval.singleton exp' flow |>
      Option.return

    | E_c_cast(e, is_explicit_cast) when exp |> etyp |> is_c_int_type &&
                                         e   |> etyp |> is_c_int_type
      ->
      man.eval ~zone:(Z_c_scalar, Z_u_num) e flow >>$? fun e' flow ->
      let t  = etyp exp in
      let t' = etyp e in
      let r = rangeof t in
      let r' = rangeof t' in
      if range_leq r' r then
        Eval.singleton e' flow |>
        Option.return
      else
        let rmin, rmax = rangeof t in
        check_overflow t man range
          (fun e tflow -> Eval.singleton {e with etyp = to_num_type t} tflow)
          (fun e fflow ->
             if is_explicit_cast && !opt_ignore_cast_alarm then
                 Eval.singleton (mk_unop (O_wrap(rmin, rmax)) e ~etyp:(to_num_type t) range) fflow
             else
               let flow1 = raise_c_integer_overflow_alarm e' t exp.erange man fflow in
               Eval.singleton (mk_unop (O_wrap(rmin, rmax)) e ~etyp:(to_num_type t) range) flow1
          ) e' flow |>
        Option.return

    | E_unop(O_log_not, e) when exp |> etyp |> is_c_num_type &&
                                not (is_compare_expr e)
      ->
      man.eval ~zone:(Z_c_scalar,Z_u_num) e flow >>$? fun e flow ->
      let exp' = mk_binop e O_eq (mk_zero exp.erange) exp.erange ~etyp:T_bool in
      Eval.singleton exp' flow |>
      Option.return

    | E_binop(op, e, e') when (exp |> etyp |> is_c_num_type ||
                               e   |> etyp |> is_c_num_type ||
                               e'  |> etyp |> is_c_num_type)
      ->
      eval_binop op e e' exp man flow |>
      Option.return

    | E_unop(op, e) when exp |> etyp |> is_c_num_type ->
      eval_unop op e exp man flow |>
      Option.return

    | E_c_cast(e, b) when e |> etyp |> is_c_num_type->
      man.eval ~zone:(Z_c_scalar, Z_u_num) e flow |>
      Option.return

    | E_constant(C_c_character (c, _)) ->
      Eval.singleton {exp with ekind = E_constant (C_int c); etyp = to_num_type exp.etyp} flow
      |> Option.return

    | E_constant(C_int _ | C_int_interval _ | C_float _ | C_float_interval _) ->
      Eval.singleton {exp with etyp = to_num_type exp.etyp} flow
      |> Option.return

    | E_constant(C_top t) when is_c_int_type t ->
      let l, u = rangeof t in
      let exp' = mk_z_interval l u ~typ:(to_num_type t) exp.erange in
      Eval.singleton exp' flow |>
      Option.return

    | E_constant(C_top t) when is_c_float_type t ->
      let exp' = mk_top (to_num_type t) exp.erange in
      Eval.singleton exp' flow |>
      Option.return

    | E_var (v,_) when is_c_num_type v.vtyp ->
      Eval.singleton (mk_num_var_expr exp) flow |>
      Option.return

    | Stubs.Ast.E_stub_builtin_call(VALID_FLOAT, f) ->
      panic_at exp.erange "valid_float not supported"

    | _ ->
      None


  let add_var_bounds vv t flow =
    if is_c_int_type t then
      let l,u = rangeof t in
      let vv = match ekind vv with E_var (vv, _) -> vv | _ -> assert false in
      Framework.Common.Var_bounds.add_var_bounds_flow vv (C_int_interval (l,u)) flow |>
      Post.return
    else
      Post.return flow

  

  (* Declaration of a scalar numeric variable *)
  let declare_var v init scope range man flow =
    let vv = mk_var (mk_num_var v) range in

    let init' =
      match scope, init with
      (** Uninitialized global variable *)
      | Variable_global, None | Variable_file_static _, None ->
        (* The variable is initialized with 0 (C99 6.7.8.10) *)
        Eval.singleton (mk_zero range) flow

      (** Uninitialized local variable *)
      | Variable_local _, None | Variable_func_static _, None ->
        (* The value of the variable is undetermined (C99 6.7.8.10) *)
        if is_c_int_type v.vtyp then
          let l,u = rangeof v.vtyp in
          Eval.singleton (mk_z_interval l u range) flow
        else
          Eval.singleton (mk_top (to_num_type v.vtyp) range) flow

      | _, Some (C_init_expr e) ->
        if not (is_compare_expr e) then
          man.eval ~zone:(Z_c_scalar,Z_u_num) e flow
        else
          assume e ~zone:Z_c_scalar
            ~fthen:(fun flow ->
                Eval.singleton (mk_one range) flow
              )
            ~felse:(fun flow ->
                Eval.singleton (mk_zero range) flow
              )
            man flow

      | _ -> assert false
    in

    init' >>$ fun init' flow ->
    man.post ~zone:Z_u_num (mk_add vv range) flow >>= fun _ flow ->
    add_var_bounds vv v.vtyp flow >>= fun _ flow ->
    man.post ~zone:Z_u_num (mk_assign vv init' range) flow


  let exec zone stmt man flow =
    match skind stmt with
    | S_c_declaration (v,init,scope) when is_c_num_type v.vtyp ->
      declare_var v init scope stmt.srange man flow |>
      Option.return

    | S_assign(lval, rval) when etyp lval |> is_c_num_type &&
                                is_compare_expr rval ->
      let range = stmt.srange in
      assume rval ~zone:Z_c_scalar
        ~fthen:(fun flow ->
            man.post ~zone:Z_c_scalar (mk_assign lval (mk_one ~typ:rval.etyp range) range) flow
          )
        ~felse:(fun flow ->
            man.post ~zone:Z_c_scalar (mk_assign lval (mk_zero ~typ:rval.etyp range) range) flow
          )
        man flow |>
      Option.return

    | S_assign(lval, rval) when etyp lval |> is_c_num_type ->
      man.eval ~zone:(Z_c_scalar, Z_u_num) lval flow >>$? fun lval' flow ->
      man.eval ~zone:(Z_c_scalar, Z_u_num) rval flow >>$? fun rval' flow ->
      man.post ~zone:Z_u_num (mk_assign lval' rval' stmt.srange) flow |>
      Option.return

    | S_add v when is_c_num_type v.etyp ->
      let vv = mk_num_var_expr v in
      man.post ~zone:Z_u_num (mk_add vv stmt.srange) flow |>
      Post.bind (add_var_bounds vv v.etyp) |>
      Option.return

    | S_expand(v, vl) when is_c_num_type v.etyp ->
      let vv = mk_num_var_expr v in
      let vvl = List.map mk_num_var_expr vl in
      man.post ~zone:Z_u_num (mk_expand vv vvl stmt.srange) flow |>
      Option.return

    | S_remove v when is_c_num_type v.etyp ->
      let vv = mk_num_var_expr v in
      man.post ~zone:Z_u_num (mk_remove vv stmt.srange) flow |>
      Post.bind (fun flow ->
          if is_c_int_type v.etyp then
            let vv = match ekind vv with E_var (vv,_) -> vv | _ -> assert false in
            Framework.Common.Var_bounds.remove_var_bounds_flow vv flow |>
            Post.return
          else
            Post.return flow
        ) |>
      Option.return

    | S_rename(v1, v2) when is_c_num_type v1.etyp &&
                            is_c_num_type v2.etyp
      ->
      let vv1 = mk_num_var_expr v1 in
      let vv2 = mk_num_var_expr v2 in
      man.post ~zone:Z_u_num (mk_rename vv1 vv2 stmt.srange) flow |>
      Option.return


    | S_assume(e) when is_c_num_type e.etyp || is_numeric_type e.etyp || e.etyp = T_any ->
      man.eval ~zone:(Z_c_scalar, Z_u_num) e flow >>$? fun e' flow ->
      man.post ~zone:Z_u_num (mk_assume (to_compare_expr e') stmt.srange) flow |>
      Option.return

    | _ -> None


  let ask _ _ _ =
    None

  let init _ _ flow =  flow

end

let () =
  Framework.Core.Sig.Stacked.Stateless.register_stack (module Domain)

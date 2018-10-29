(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(** Inter-procedural iterator by inlining.  *)

open Framework.Essentials
open Ast
open Zone
open Callstack


(** {2 Return flow token} *)
(** ===================== *)

type token +=
  | T_return of range * expr option
  (** [T_return(l, Some e)] represents flows reaching a return
     statement at location [l] returning an expression [e]. The
     expression is [None] when the function returns nothing
      (i.e. case of a procedure). *)

let () =
  register_token {
    compare = (fun next tk1 tk2 ->
      match tk1, tk2 with
      | T_return(r1, _), T_return(r2, _) -> compare_range r1 r2
      | _ -> next tk1 tk2
    );
  print = (fun next fmt -> function
        | T_return(r, Some e) -> Format.fprintf fmt "return %a" pp_expr e
        | T_return(r, None) -> Format.fprintf fmt "return"
        | tk -> next fmt tk
      );
  }


(** {2 Domain definition} *)
(** ===================== *)

module Domain : Framework.Domains.Stateless.S =
struct

  (** Domain identification *)
  (** ===================== *)

  type _ domain += D_universal_intraproc_inlining : unit domain
  let id = D_universal_intraproc_inlining
  let name = "universal.iterators.interproc.inlining"
  let identify : type a. a domain -> (unit, a) eq option =
    function
    | D_universal_intraproc_inlining -> Some Eq
    | _ -> None

  let debug fmt = Debug.debug ~channel:name fmt


  (** Zoning definition *)
  (** ================= *)

  let exec_interface = {export = [Z_u]; import = []}
  let eval_interface = {export = [Z_u, Z_any]; import = []}

  (** Initialization *)
  (** ============== *)

  let init prog man (flow: 'a flow) =
    Some (
      Flow.set_annot A_call_stack [] flow
    )

  (** Computation of post-conditions *)
  (** ============================== *)

  let exec zone stmt man flow =
    match skind stmt with
    | S_return e ->
      Some (
        let cur = Flow.get T_cur man flow in
        Flow.add (T_return (stmt.srange, e)) cur man flow |>
        Flow.remove T_cur man |>
        Post.of_flow
      )

    | _ -> None


  (** Evaluation of expressions *)
  (** ========================= *)

  let eval zone exp man flow =
    let range = erange exp in
    match ekind exp with
    | E_call({ekind = E_function (User_defined f)}, args) ->
      (* Clear all return flows *)
      let flow0 = Flow.filter (fun tk env ->
          match tk with
          | T_return _ -> false
          | _ -> true
        ) man flow
      in

      (* Assign arguments to parameters *)
      let parameters_assign = List.mapi (fun i (param, arg) ->
          mk_assign (mk_var param range) arg range
        ) (List.combine f.fun_parameters args) in

      let init_block = mk_block parameters_assign range in

      (* Update call stack *)
      let cs = Flow.get_annot A_call_stack flow0 in
      let cs' = range :: cs in
      let flow1 = Flow.set_annot A_call_stack cs' flow0 in

      (* Execute body *)
      let flow2 = man.exec init_block flow1 |>
                  man.exec f.fun_body
      in

      (* Create a temporary variable to store return expressions *)
      let typ = OptionExt.option_dfl T_int f.fun_return_type in
      let tmp = mk_tmp ~vtyp:typ () in

      (* Iterate over return flows and assign the returned value to tmp *)
      let flow3 =
        Flow.fold (fun acc tk env ->
            match tk with
            | T_return(_, None) -> Flow.add T_cur env man acc

            | T_return(_, Some e) ->
              Flow.set T_cur env man acc |>
              man.exec (mk_assign (mk_var tmp range) e range) |>
              Flow.join man acc

            | _ -> Flow.add tk env man acc
          )
          (Flow.remove T_cur man flow)
          man flow2
      in

      (* Remove parameters and local variables from the environment *)
      let ignore_stmt_list =
        List.mapi (fun i v ->
            mk_remove_var v range
          ) (f.fun_parameters @ f.fun_locvars)
      in

      let ignore_block = mk_block ignore_stmt_list range in

      let flow4 = man.exec ignore_block flow3 in

      Eval.singleton (mk_var tmp range) flow4 ~cleaners:[mk_remove_var tmp range] |>
      OptionExt.return

    | _ -> None

  let ask _ _ _ = None

end


let () =
  Framework.Domains.Stateless.register_domain (module Domain)

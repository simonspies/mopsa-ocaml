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

(** Common transfer functions for handling function calls *)


open Mopsa
open Ast
open Soundness


let name = "universal.iterators.interproc.common"
let debug fmt = Debug.debug ~channel:name fmt

let opt_continue_on_recursive_call : bool ref = ref true

let () =
  register_shared_option name {
    key = "-stop-rec";
    category = "Interprocedural Analysis";
    doc = "";
    spec = ArgExt.Clear opt_continue_on_recursive_call;
    default = " continue with top during recursive calls"
  }

let opt_split_return_variables_by_range : bool ref = ref false

let () =
  register_domain_option name {
      key = "-split-returns";
      category = "Interprocedural Analysis";
      doc = "";
      spec = ArgExt.Set opt_split_return_variables_by_range;
      default = " split return variables by their location in the program"
    }

let opt_rename_local_variables_on_recursive_call : bool ref = ref true

let () =
  register_shared_option (name ^ ".renaming") {
    key = "-disable-var-renaming-recursive-call";
    category = "Interprocedural Analysis";
    doc = " disable renaming of local variables when detecting recursive calls";
    spec = ArgExt.Clear opt_rename_local_variables_on_recursive_call;
    default = ""
  }

(** {2 Return flow token} *)
(** ===================== *)

type token +=
  | T_return of range
  (** [T_return(l)] represents flows reaching a return statement at
      location [l] *)

let () =
  register_token {
    compare = (fun next tk1 tk2 ->
        match tk1, tk2 with
        | T_return(r1), T_return(r2) -> compare_range r1 r2
        | _ -> next tk1 tk2
      );
    print = (fun next fmt -> function
        | T_return(r) -> Format.fprintf fmt "return[%a]@" pp_range r
        | tk -> next fmt tk
      );
  }


(** {2 Return variable} *)
(** =================== *)


(** Return variable of a function call *)
type var_kind += V_return of expr (* call expression *)
                             * range option (* return range *)

(** Registration of the kind of return variables *)
let () =
  register_var {
    print = (fun next fmt v ->
        match v.vkind with
        | V_return (e, None) -> Format.fprintf fmt "ret(%a)" pp_expr e
        | V_return (e, Some r) -> Format.fprintf fmt "ret(%a)@%a)" pp_expr e pp_range r
        | _ -> next fmt v
      );
    compare = (fun next v1 v2 ->
        match v1.vkind, v2.vkind with
        | V_return (e1, ro1), V_return (e2, ro2) ->
          Compare.compose [
            (fun () -> compare_expr e1 e2);
            (fun () -> compare_range e1.erange e2.erange);
            (fun () -> (OptionExt.compare compare_range) ro1 ro2);
          ]
        | _ -> next v1 v2
      );
  }

(** Constructor of return variables *)
let mk_return call ro =
  let uniq_name, ro =
    match ro with
    | Some r when !opt_split_return_variables_by_range ->
       Format.asprintf "ret(%a)@@%a@@%a" pp_expr call pp_range call.erange pp_range r, ro
    | _ ->
       Format.asprintf "ret(%a)@@%a" pp_expr call pp_range call.erange, None in
  mkv uniq_name (V_return (call, ro)) call.etyp



(** {2 Contexts to keep return variable} *)
(** =================================== *)

module ReturnKey = GenContextKey(
  struct
    type 'a t = expr
    let print pp fmt expr =
      Format.fprintf fmt "Returning call: %a" pp_expr expr
  end
  )

let return_key = ReturnKey.key

let get_last_call_site flow =
  let cs = Flow.get_callstack flow in
  let hd, _ = pop_callstack cs in
  hd.call_range


(** {2 Recursion checks} *)
(** ==================== *)

(** Check that no recursion is happening *)
let check_recursion f_orig f_uniq range cs =
  if cs = [] then false
  else
    List.exists (fun cs -> compare_callsite cs {call_fun_orig_name=f_orig; call_fun_uniq_name=f_uniq; call_range=range} = 0) (List.tl cs)

let check_nested_calls f cs =
  if cs = [] then false
  else List.exists (fun call -> call.call_fun_uniq_name = f) (List.tl cs)


(** {2 Function inlining} *)
(** ===================== *)


(** Initialize function parameters *)
let init_fun_params f args range man flow =
  (* Update the call stack *)
  let flow = Flow.push_callstack f.fun_orig_name ~uniq:f.fun_uniq_name range flow in
  let init_range = tag_range f.fun_range "init" in

  if f.fun_parameters = [] then
    [], f.fun_locvars, f.fun_body, Post.return flow
  else
  if !opt_rename_local_variables_on_recursive_call &&
     check_nested_calls f.fun_uniq_name (Flow.get_callstack flow)
  then
    begin
      debug "nested calls detected on %s, performing parameters and locvar renaming" f.fun_orig_name;
      (* Add parameters and local variables to the environment *)
      let add_range = (fun p -> mk_attr_var p (Format.asprintf "%a" pp_range range) p.vtyp) in

      let function_vars = f.fun_parameters @ f.fun_locvars in
      let fun_parameters = List.map add_range f.fun_parameters in
      let fun_locvars = List.map add_range f.fun_locvars in

      (* TODO: do this transformation only if we detect f in the callstack? That could work? *)
      let new_body = Visitor.map_stmt (fun e -> match ekind e with
          | E_var (v, m) when List.exists (fun v' -> compare_var v v' = 0) function_vars ->
            Keep {e with ekind = E_var(add_range v, m)}
          | _ -> VisitParts e) (fun s -> VisitParts s) f.fun_body in
      debug "moved body from:%a@\nto %a@\n" pp_stmt f.fun_body pp_stmt new_body;

      (* Assign arguments to parameters *)
      (* FIXME: the sub-expressions of arg have a range in the caller
         body. Since we have updated the callstack, we should be now
         in the callee body. We need a way to rewrite the ranges in
         arg! *)
      let parameters_assign = List.rev @@ List.fold_left (fun acc (param, arg) ->
          mk_assign (mk_var param init_range) arg init_range ::
          mk_add_var param init_range :: acc
        ) [] (List.combine fun_parameters args) in

      let init_block = mk_block parameters_assign init_range in


      (* Execute body *)
      fun_parameters, fun_locvars, new_body, man.exec init_block flow

    end
  else
    begin
      (* Assign arguments to parameters *)
      (* FIXME: the sub-expressions of arg have a range in the caller
         body. Since we have updated the callstack, we should be now
         in the callee body. We need a way to rewrite the ranges in
         arg! *)
      let parameters_assign = List.rev @@ List.fold_left (fun acc (param, arg) ->
          mk_assign (mk_var param init_range) arg init_range ::
          mk_add_var param init_range :: acc
        ) [] (List.combine f.fun_parameters args) in

      let init_block = mk_block parameters_assign init_range in

      (* Execute body *)
      f.fun_parameters, f.fun_locvars, f.fun_body, man.exec init_block flow
    end


(** Execute function body and save the return value *)
let exec_fun_body f params locals body call_oexp range man flow =
  (* Save the return variable in the context and backup the old one *)
  let oldreturn, flow1 =
    match call_oexp with
    | None -> None, flow
    | Some call ->
      (try Some (find_ctx return_key (Flow.get_ctx flow)) with Not_found -> None),
      Flow.set_ctx (add_ctx return_key call (Flow.get_ctx flow)) flow in

  (* Clear all return flows *)
  let flow2 = Flow.filter (fun tk env ->
      match tk with
      | T_return _ -> false
      | _ -> true
    ) flow1
  in

  (* Execute the body of the function *)
  let post2 = man.exec body flow2 in

  (* Restore return and callstack contexts *)
  let post3 = match oldreturn with
    | None -> post2
    | Some ret ->
      Cases.set_ctx
        (add_ctx return_key ret (Cases.get_ctx post2)) post2 in

  post3 >>% fun flow3 ->

  (* Copy the new context and report from flow3 to original flow flow1 *)
  let flow4 = Flow.copy_ctx flow3 flow1 |> Flow.copy_report flow3 in

  (* Cut the T_cur flow *)
  let flow4 = Flow.remove T_cur flow4 in

  (* Retrieve non-cur/return flows in flow3 and put them in flow4 *)
  let flow5 =
    Flow.fold
      (fun acc tk env ->
         match tk with
         | T_cur | T_return _ -> acc
         | _                  -> Flow.add tk env man.lattice acc
      )
      flow4 flow3
  in

  let mk_return tk_orange range =
    match call_oexp with
    | None ->
      mk_unit range
    | Some call ->
      mk_var (mk_return call tk_orange) range in

  let remove_locals =
    man.exec
      (mk_block (List.map (fun v -> mk_remove_var v range) (locals @ params)) range) in

  let add_cleaners return cases =
    match call_oexp with
    | None -> cases
    | Some _ -> Cases.add_cleaners [mk_remove return range] cases in

  let evals =
    Flow.fold (fun acc tk env ->
        match tk with
        | T_cur | T_return _ ->
           let flow = Flow.set T_cur env man.lattice flow5 in
           let return = match tk with
             | T_cur -> mk_return None range
             | T_return tk_range -> mk_return (Some tk_range) range
             | _ -> assert false in
           (
             remove_locals flow >>%
             man.eval return |>
               add_cleaners return
           )
           :: acc

        | _ -> acc
      )
      [] flow3
  in

  let ret =
    Eval.join_list ~empty:(fun () ->
        let return = mk_return None range in
        Post.return flow5 >>% remove_locals >>% man.eval return |> add_cleaners return
      ) evals
  in

  (* Restore call stack *)
  let _,cs = Cases.get_callstack ret |>
             Callstack.pop_callstack in
  Cases.set_callstack cs ret

(** Inline a function call *)
let inline f params locals body call_oexp range man flow =
  match check_recursion f.fun_orig_name f.fun_uniq_name range (Flow.get_callstack flow) with
  | true ->
     begin
       let flow =
         Flow.add_local_assumption
           (A_ignore_recursion_side_effect f.fun_orig_name)
           range flow
       in
       let post = match call_oexp with
         | None -> Post.return flow
         | Some e ->
            if !opt_continue_on_recursive_call then
              let v = mk_return e None in
              man.exec (mk_add_var v range) flow >>%
                man.exec (mk_assign (mk_var v range) (mk_top v.vtyp range) range)
            else
              panic_at range "recursive call on function %s" f.fun_orig_name in
       post >>% fun flow ->
                match call_oexp with
                | None ->
                   Eval.singleton (mk_unit range) flow

                | Some e ->
                   let v = mk_return e None in
                   man.eval (mk_var v range) flow
     end

  | false ->
     exec_fun_body f params locals body call_oexp range man flow

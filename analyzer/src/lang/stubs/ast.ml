(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(** Abstract Syntax Tree for stubs specifications. *)

open Framework.Essentials
open Format


(** {2 Types} *)
(*  =-=-=-=-= *)

type typ +=
  | T_stub_forall_var of typ  (** universally quantified variables *)
  | T_stub_exists_var of typ  (** existentially quantified variables *)


(** {2 Operators} *)
(*  =-=-=-=-=-=-= *)

type operator +=
  | O_log_implies (** ⇒ *)


(** {2 Expressions} *)
(*  =-=-=-=-=-=-=-= *)

(** Built-in functions *)
type builtin =
  | SIZE
  | OFFSET
  | BASE
  | OLD

type expr_kind +=
  | E_stub_return  (* return value of the stub *)
  | E_stub_builtin_call of builtin with_range (* built-in function *) * expr


(** {2 Formulas} *)
(*  =-=-=-=-=-=- *)

type formula =
  | F_expr   of expr (** boolean expression *)
  | F_binop  of operator * formula with_range * formula with_range
  | F_not    of formula with_range
  | F_forall of var * set * formula with_range
  | F_exists of var * set * formula with_range
  | F_in     of var * set (* set membership predicate *)
  | F_free   of expr (* resource release *)

and set =
  | S_interval of expr * expr (* intervals of integers  *)
  | S_resource of resource    (* set of allocated instances of a resource *)

and resource = string (* FIXME: add a uid *)


(** {2 Stubs} *)
(*  =-=-=-=-= *)

(** A stub is composed of some requirements on the pre-condition and a
    body. *)
type stub = {
  stub_requires: requires with_range list;
  stub_body: body;
}

(** Body of a stub *)
and body =
  | B_post of post
  (** A simple stub body composed of only one post-condition *)

  | B_cases   of case with_range list
  (** A composed stub containing a number of cases *)

(** Post-conditions give the modified variables, the value of locals
    and the ensured conditions on the output state. *)
and post = {
  post_assigns  : assigns with_range list;
  post_local    : local with_range list;
  post_ensures  : ensures with_range list;
}

(** A stub case consists of a filtering on the pre-condition and a
   post-condition. The assumes section is equivalent to an if
   statement, while the requires section is equivalent to an assert
   statement. *)
and case = {
  case_label    : string;
  case_assumes  : assumes with_range list;
  case_requires : requires with_range list;
  case_post : post;
}


(* The sections requires, assumes and ensures are just logic formula *)
and requires = formula with_range
and ensures  = formula with_range
and assumes  = formula with_range

(* Local variables have values in the post-condition only. *)
and local = {
  lvar   : var;
  lval : local_value;
}

(* Values of local variables *)
and local_value =
  | L_new  of resource         (* allocation of a resource *)
  | L_call of expr * expr list (* call to a function *)


(* Assigned memory regions are declared in the assigns section *)
and assigns = {
  assign_target: expr;                 (* assigned memory block *)
  assign_offset: (expr * expr) option; (* range of modified indices *)
}


(** {2 Pretty printers} *)
(** =-=-=-=-=-=-=-=-=-= *)

let pp_list pp sep fmt l =
  pp_print_list ~pp_sep:(fun fmt () -> fprintf fmt sep) pp fmt l

let pp_opt pp fmt o =
  match o with
  | None -> ()
  | Some x -> pp fmt x

let pp_builtin fmt f =
  match f with
  | SIZE   -> pp_print_string fmt "size"
  | OFFSET -> pp_print_string fmt "offset"
  | BASE   -> pp_print_string fmt "base"
  | OLD    -> pp_print_string fmt "old"

let rec pp_formula fmt f =
  match f.content with
  | F_expr e -> pp_expr fmt e
  | F_binop (op, f1, f2) -> fprintf fmt "(%a) %a (%a)" pp_formula f1 pp_operator op pp_formula f2
  | F_not f -> fprintf fmt "not (%a)" pp_formula f
  | F_forall (x, set, f) -> fprintf fmt "∀ %a %a ∈ %a: @[%a@]" pp_typ x.vtyp pp_var x pp_set set pp_formula f
  | F_exists (x, set, f) -> fprintf fmt "∃ %a %a ∈ %a: @[%a@]" pp_typ x.vtyp pp_var x pp_set set pp_formula f
  | F_in (x, set) -> fprintf fmt "%a ∈ %a" pp_var x pp_set set
  | F_free e -> fprintf fmt "free(%a)" pp_expr e

and pp_set fmt =
  function
  | S_interval(e1, e2) -> fprintf fmt "[%a .. %a]" pp_expr e1 pp_expr e2
  | S_resource(r) -> pp_resource fmt r

and pp_resource fmt res = pp_print_string fmt res

let rec pp_local fmt local =
  fprintf fmt "local: %a %a = @[%a@];"
    pp_typ local.content.lvar.vtyp
    pp_var local.content.lvar
    pp_local_value local.content.lval

and pp_local_value fmt v =
  match v with
  | L_new resouce -> fprintf fmt "new %a" pp_resource resouce
  | L_call (f, args) -> fprintf fmt "%a(%a)" pp_expr f (pp_list pp_expr ", ") args


let pp_requires fmt requires =
  fprintf fmt "requires: @[%a@];"
    pp_formula requires.content

let pp_assigns fmt assigns =
  fprintf fmt "assigns: %a%a;"
    pp_expr assigns.content.assign_target
    (pp_opt (fun fmt (l, u) ->
         fprintf fmt "[%a .. %a]" pp_expr l pp_expr u
       )
    ) assigns.content.assign_offset


let pp_assumes fmt assumes =
  fprintf fmt "assumes: @[%a@];" pp_formula assumes.content

let pp_ensures fmt ensures =
  fprintf fmt "ensures: @[%a@];" pp_formula ensures.content

let pp_post fmt post =
  fprintf fmt "%a%a%a"
    (pp_list pp_assigns "@\n") post.post_assigns
    (pp_list pp_local "@\n") post.post_local
    (pp_list pp_ensures "@\n") post.post_ensures

let pp_case fmt case =
  fprintf fmt "case \"%s\":@\n  @[%a%a%a@]"
    case.content.case_label
    (pp_list pp_assumes "@\n") case.content.case_assumes
    (pp_list pp_requires "@\n") case.content.case_requires
    pp_post case.content.case_post

let pp_body fmt body =
  match body with
  | B_post post -> pp_post fmt post
  | B_cases cases  -> (pp_list pp_case "@\n") fmt cases

let pp_stub fmt stub =
  fprintf fmt "%a%a"
    (pp_list pp_requires "@\n") stub.stub_requires
    pp_body stub.stub_body


(** {2 AST registration} *)
(*  =-=-=-=-=-=-=-=-=-=- *)

let () =
  register_typ {
    compare = (fun next t1 t2 ->
        match t1, t2 with
        | T_stub_forall_var(t1), T_stub_forall_var(t2) -> compare_typ t1 t2
        | T_stub_exists_var(t1), T_stub_exists_var(t2) -> compare_typ t1 t2
        | _ -> next t1 t2
      );

    print = (fun next fmt t ->
        match t with
        | T_stub_forall_var(t') -> fprintf fmt "∀%a" pp_typ t'
        | T_stub_exists_var(t') -> fprintf fmt "∃%a" pp_typ t'
        | _ -> next fmt t
      );
  }

let () =
  register_operator {
    compare = (fun next -> next);
    print   = (fun next fmt o ->
        match o with
        | O_log_implies -> Format.fprintf fmt "⇒"
        | _ -> next fmt o
      );
  }

let () =
  register_expr {
    compare = (fun next e1 e2 ->
        match ekind e1, ekind e2 with
        | E_stub_builtin_call(f1, arg1), E_stub_builtin_call(f2, arg2) ->
          Compare.compose [
            (fun () -> compare f1 f2);
            (fun () -> compare_expr arg1 arg2)
          ]
        | _ -> next e1 e2
      );
    visit  = (fun next e ->
        match ekind e with
        | E_stub_return -> Framework.Visitor.leaf e
        | E_stub_builtin_call(f, arg) ->
          { exprs = [arg]; stmts = [] },
          (function {exprs = [args]} -> {e with ekind = E_stub_builtin_call(f, arg)} | _ -> assert false)
        | _ -> next e
      );
    print   = (fun next fmt e ->
        match ekind e with
        | E_stub_return -> pp_print_string fmt "return"
        | E_stub_builtin_call(f, arg) -> fprintf fmt "%a(%a)" pp_builtin f.content pp_expr arg
        | _ -> next fmt e
      );
  }

(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(** Generic domain for creating non-relational value abstractions. *)

open Value
open Ast
open Manager
open Domain
open Annotation

module Make(Value: VALUE) =
struct


  (*==========================================================================*)
                          (** {2 Lattice structure} *)
  (*==========================================================================*)

  (** Map with variables as keys. Absent bindings are assumed to point to ⊤. *)
  module VarMap =
    Lattices.Total_map.Make
      (PrimedVar)
      (Value)

  include VarMap

  type _ domain += D_nonrel : t domain

  let name = "framework.domains.nonrel"
  let id = D_nonrel
  let identify : type a. a domain -> (t, a) Domain.eq option =
    function
    | D_nonrel -> Some Eq
    | _ -> None


  let print fmt a =
    Format.fprintf fmt "%s: @[%a@]@\n" (snd @@ Value.name) VarMap.print a

  let debug fmt = Debug.debug ~channel:name fmt

  (*==========================================================================*)
  (**                    {2 Evaluation of expressions}                        *)
  (*==========================================================================*)

  (** Expressions annotated with abstract values; useful for assignment and compare. *)
  type aexpr =
    | A_var of var primed * Value.t
    | A_cst of Ast.typ * constant * Value.t
    | A_unop of Ast.typ * operator * aexpr * Value.t
    | A_binop of Ast.typ * operator * aexpr * Value.t * aexpr * Value.t
    | A_unsupported

  (** Forward evaluation returns the abstract value of the expression,
     but also a tree annotated by the intermediate abstract
     values for each sub-expression *)
  let rec eval (e:expr) (a:t) : (aexpr * Value.t) with_channel =
    match ekind e with

    | E_var(var, _) ->
      let v = VarMap.find (unprimed var) a in
      (A_var (unprimed var, v), v) |>
      Channel.return

    | E_primed { ekind = E_var(var, _) } ->
      let v = VarMap.find (primed var) a in
      (A_var (primed var, v), v) |>
      Channel.return

    | E_constant(c) ->
      let t = etyp e in
      let v = Value.of_constant t c in
      (A_cst (t, c, v), v) |>
      Channel.return

    | E_unop (op,e1) ->
      let t = etyp e in
      eval e1 a |> Channel.bind @@ fun (ae1, v1) ->
      Value.unop t op v1 |> Channel.bind @@ fun v ->
      Channel.return (A_unop (t, op, ae1, v1), v)

    | E_binop (op,e1,e2) ->
      let t = etyp e in
      eval e1 a |> Channel.bind @@ fun (ae1, v1) ->
      eval e2 a |> Channel.bind @@ fun (ae2, v2) ->
      Value.binop t op v1 v2 |> Channel.bind @@ fun v ->
      Channel.return (A_binop (t, op, ae1, v1, ae2, v2), v)

    | _ ->
      (* unsupported -> ⊤ *)
      Channel.return (A_unsupported, Value.top)


   (** Forward evaluation of boolean expressions *)
  let rec fwd_compare (e:expr) (a:t) : (aexpr * Value.t) with_channel =
    match ekind e with

    | E_var(var, _) ->
      let v = VarMap.find (unprimed var) a in
      Channel.return (A_var (unprimed var, v), v)

    | E_primed { ekind = E_var(var, _) } ->
      let v = VarMap.find (primed var) a in
      Channel.return (A_var (primed var, v), v)

    | E_constant(c) ->
      let t = etyp e in
      let v = Value.of_constant t c in
      Channel.return (A_cst (t, c, v), v)

    | E_unop (op,e1) ->
      let t = etyp e in
      eval e1 a |>
      Channel.bind @@ fun (ae1, v1) ->
      Value.unop t op v1 |>
      Channel.bind @@ fun v ->
      Channel.return (A_unop (t, op, ae1, v1), v)

    | E_binop (op,e1,e2) ->
      let t = etyp e in
      eval e1 a |>
      Channel.bind @@ fun (ae1, v1) ->
      eval e2 a |>
      Channel.bind @@ fun (ae2, v2) ->
      Value.binop t op v1 v2 |>
      Channel.bind @@ fun v ->
      Channel.return (A_binop (t, op, ae1, v1, ae2, v2), v)

    | _ ->
      (* unsupported -> ⊤ *)
      Channel.return (A_unsupported, Value.top)

  (** Backward refinement of expressions; given an annotated tree, and
     a target value, refine the environment using the variables in the
     expression *)
  let rec refine (ae:aexpr) (v:Value.t) (r:Value.t) (a:t) : t with_channel =
    let r' = Value.meet Annotation.empty v r in
    match ae with
    | A_var (var, _) ->
      if Value.is_bottom r'
      then Channel.return bottom
      else Channel.return (VarMap.add var r' a)

    | A_cst(_) ->
      if Value.is_bottom r'
      then Channel.return bottom
      else Channel.return a

    | A_unop (t, op, ae1, v1) ->
      Value.bwd_unop t op v1 r' |> Channel.bind @@ fun w ->
      refine ae1 v1 w a

    | A_binop (t, op, ae1, v1, ae2, v2) ->
      Value.bwd_binop t op v1 v2 r' |> Channel.bind @@ fun (w1, w2) ->
      refine ae1 v1 w1 a |> Channel.bind @@ fun a1 ->
      refine ae2 v2 w2 a1

    | A_unsupported ->
      Channel.return a

  (* utility function to reduce the complexity of testing boolean expressions;
     it handles the boolean operators &&, ||, ! internally, by induction
     on the syntax

     if r=true, keep the states that may satisfy the expression;
     if r=false, keep the states that may falsify the expression
  *)
  let filter (annot: 'a annot) (e:expr) (r:bool) (a:t) : t with_channel =
    (* recursive exploration of the expression *)
    let rec doit (e:expr) (r:bool) (a:t) : t with_channel =
      match ekind e with

      | E_unop (O_log_not, e) ->
        doit e (not r) a

      | E_binop (O_log_and, e1, e2) ->
        doit e1 r a |> Channel.bind @@ fun a1 ->
        doit e2 r a |> Channel.bind @@ fun a2 ->
        (if r then meet else join) annot a1 a2 |>
        Channel.return

      | E_binop (O_log_or, e1, e2) ->
        doit e1 r a |> Channel.bind @@ fun a1 ->
        doit e2 r a |> Channel.bind @@ fun a2 ->
        (if r then join else meet) annot a1 a2 |>
        Channel.return

      | E_constant c ->
        let t = etyp e in
        let v = Value.of_constant t c in
        Value.filter t v r |> Channel.bind @@ fun w ->
        (if Value.is_bottom w then bottom else a) |>
        Channel.return

      | E_var(var, _) ->
        let v = find (unprimed var) a in
        Value.filter (var.vtyp) v r |> Channel.bind @@ fun w ->
        (if Value.is_bottom w then bottom else add (unprimed var) w a) |>
        Channel.return

      | E_primed { ekind = E_var(var, _) } ->
        let v = find (primed var) a in
        Value.filter (var.vtyp) v r |> Channel.bind @@ fun w ->
        (if Value.is_bottom w then bottom else add (primed var) w a) |>
        Channel.return

      (* arithmetic comparison part, handled by Value *)
      | E_binop (op, e1, e2) ->
        let t = etyp e1 in
        (* evaluate forward each argument expression *)
        eval e1 a |> Channel.bind @@ fun (ae1,v1) ->
        eval e2 a |> Channel.bind @@ fun (ae2,v2) ->
        (* apply comparison *)
        Value.compare t op v1 v2 r |> Channel.bind @@ fun (r1, r2) ->
        (* propagate backward on both argument expressions *)
        refine ae1 v1 r1 a |> Channel.bind @@ fun a1 ->
        refine ae2 v2 r2 a1

      | _ -> assert false

    in
    doit e r a



  (*==========================================================================*)
                         (** {2 Transfer function} *)
  (*==========================================================================*)


  let init prog man flow =
    Some { flow = Flow.set_domain_env T_cur top man flow; callbacks = [] }

  let exec_interface = Domain.{
    import = [];
    export = [Value.zone];
  }

  let eval_interface = Domain.{
    import = [Zone.any_zone, Value.zone];
    export = [];
  }

  let rec exec zone stmt man flow =
    match skind stmt with
    | S_remove v when PrimedVar.match_expr v  ->
      Some (
        let flow' = Flow.map_domain_env T_cur (VarMap.remove (PrimedVar.from_expr v)) man flow in
        Post.of_flow flow'
      )

    | S_add v when PrimedVar.match_expr v ->
      Some (
        let flow' = Flow.map_domain_env T_cur (VarMap.add (PrimedVar.from_expr v) Value.top) man flow in
        Post.of_flow flow'
      )

    | S_project vars when List.for_all PrimedVar.match_expr vars ->
      Some (
        let vars = List.map PrimedVar.from_expr vars in
        let flow' = Flow.map_domain_env T_cur (fun a ->
            VarMap.fold (fun v _ acc ->
                if List.exists (fun v' -> PrimedVar.compare v v' = 0) vars then acc else VarMap.remove v acc
              ) a a
          ) man flow
        in
        Post.of_flow flow'
      )

    | S_rename (var1, var2) when PrimedVar.match_expr var1 && PrimedVar.match_expr var2 ->
      Some (
        let var1 = PrimedVar.from_expr var1 in
        let var2 = PrimedVar.from_expr var2 in

        let flow' = Flow.map_domain_env T_cur (fun a ->
            let v = VarMap.find var1 a in
            VarMap.remove var1 a |> VarMap.add var2 v
          ) man flow
        in
        Post.of_flow flow'
      )

    | S_forget var when PrimedVar.match_expr var ->
      Flow.map_domain_env T_cur (add (PrimedVar.from_expr var) Value.top) man flow |>
      Post.return

    | S_assign (var, e) when PrimedVar.match_expr var ->
      Some (
        man.eval ~zone:(Zone.any_zone, Value.zone) e flow |> Post.bind man @@ fun e flow ->
        let flow', channels = Channel.map_domain_env T_cur (fun a ->
            eval e a |> Channel.bind @@ fun (_,v) ->
            let a' = VarMap.add (PrimedVar.from_expr var) v a in
            let a'' =
              match PrimedVar.ext_from_expr var with
              | STRONG -> a'
              | WEAK -> join (Flow.get_all_annot flow) a a'
            in
            Channel.return a''
          ) man flow
        in
        Post.of_flow flow' |>
        Post.add_channels channels
      )

    | S_expand (var, vl)
      when PrimedVar.match_expr var &&
           List.for_all PrimedVar.match_expr vl
      ->
      let vl = List.map PrimedVar.from_expr vl in
      let a = Flow.get_domain_env T_cur man flow in
      let value = find (PrimedVar.from_expr var) a in
      let aa = List.fold_left (fun acc v' ->
          add v' value acc
        ) a vl
      in
      Flow.set_domain_env T_cur aa man flow |>
      Post.return

    (* FIXME: No check on weak variables in rhs *)
    | S_assume e ->
      Some (
        man.eval ~zone:(Zone.any_zone, Value.zone) e flow |> Post.bind man @@ fun e flow ->
        let flow', channels = Channel.map_domain_env T_cur (fun a ->
            filter (Flow.get_all_annot flow) e true a
          ) man flow
        in
        Post.of_flow flow' |>
        Post.add_channels channels
      )

    | _ -> None


  let ask : type r. r Query.query -> _ -> _ -> r option =
    fun query man flow ->
      let a = Flow.get_domain_env T_cur man flow in
      Value.ask query (fun exp -> let v = eval exp a in snd v.value)


  let eval zone exp man flow = None


end

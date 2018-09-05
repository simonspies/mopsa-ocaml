(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(** A stacked combination of D1 over D2 allows domain D1 to unify the
    state of D2 before lattice binary operators *)

open Essentials

module type S =
sig
  (* Unchanged from DOMAIN signature *)
  type t
  val bottom: t
  val top: t
  val is_bottom: t -> bool
  val subset: t -> t -> bool
  val print: Format.formatter -> t -> unit
  val id : t domain
  val name : string
  val identify : 'a domain -> (t, 'a) eq option
  val init : Ast.program -> ('a, t) man -> 'a flow -> 'a flow option
  val exec_interface : Zone.zone interface
  val eval_interface : (Zone.zone * Zone.zone) interface
  val exec : Zone.zone -> Ast.stmt -> ('a, t) man -> 'a flow -> 'a post option
  val eval : (Zone.zone * Zone.zone) -> Ast.expr -> ('a, t) man -> 'a flow -> ('a, Ast.expr) evl option
  val ask  : 'r Query.query -> ('a, t) man -> 'a flow -> 'r option

  (* Binary lattice operators can unify the state of the underneath domain *)
  val join: 'a annot -> ('b, 'b) man -> t * 'b -> t * 'b -> t * 'b * 'b
  val meet: 'a annot -> ('b, 'b) man -> t * 'b -> t * 'b -> t * 'b * 'b
  val widen: 'a annot -> ('b, 'b) man -> t * 'b -> t * 'b -> t * 'b * 'b

end

(** Combine two domains with a stack configuration. *)
module Make(D1: S)(D2: Domain.DOMAIN) : Domain.DOMAIN =
struct

  (* Lattice operators *)
  (* ================= *)

  type t = D1.t * D2.t

  let bottom = D1.bottom, D2.bottom

  let top = D1.top, D2.top

  let is_bottom (a,b) = D1.is_bottom a || D2.is_bottom b

  let subset (a1, b1) (a2, b2) = D1.subset a1 a2 && D2.subset b1 b2

  (* Local manager of D2, used in binary operators *)
  let rec man2_local : (D2.t, D2.t) man = {
    bottom = D2.bottom;
    top = D2.top;
    is_bottom = D2.is_bottom;
    subset = D2.subset;
    join = D2.join;
    meet = D2.meet;
    widen = D2.widen;
    print = D2.print;
    get = (fun a -> a);
    set = (fun a _ -> a);
    exec = (fun ?(zone=Zone.top) stmt flow ->
        match D2.exec zone stmt man2_local flow with
        | Some post -> post.Post.flow
        | None -> Debug.fail "stacked: sub-domain can not compute post-condition of %a" pp_stmt stmt;
      );
    eval = (fun ?(zone=(Zone.top, Zone.top)) exp flow ->
        match D2.eval zone exp man2_local flow with
        | Some evl -> evl
        | None -> Debug.fail "stacked: sub-domain can not evaluate %a" pp_expr exp;
      );
    ask = (fun query flow ->
        match D2.ask query man2_local flow with
        | Some repl -> repl
        | None -> Debug.fail "stacked: sub-domain can not answer query";
      );
  }

  let join annot (a1, b1) (a2, b2) =
    let a, b1', b2' = D1.join annot man2_local (a1, b1) (a2, b2) in
    a, D2.join annot b1' b2

  let meet annot (a1, b1) (a2, b2) =
    let a, b1', b2' = D1.meet annot man2_local (a1, b1) (a2, b2) in
    a, D2.meet annot b1' b2

  let widen annot (a1, b1) (a2, b2) =
    let a, b1', b2' = D1.widen annot man2_local (a1, b1) (a2, b2) in
    a, D2.widen annot b1' b2

  let print fmt (a, b) =
    Format.fprintf fmt "%a%a" D1.print a D2.print b


  (* Domain identification *)
  (* ===================== *)

  type _ domain += D_stacked : t domain
  let name = D1.name ^ "/" ^ D2.name
  let id = D_stacked
  let identify : type b. b domain -> (t, b) eq option =
    function
    | D_stacked -> Some Eq
    | _ -> None


  (* Managers definition *)
  (* =================== *)

  let man1 man = {
    man with
    get = (fun flow -> fst @@ man.get flow);
    set = (fun hd flow -> man.set (hd, snd @@ man.get flow) flow);
  }

  let man2 man = {
    man with
    get = (fun flow -> snd @@ man.get flow);
    set = (fun tl flow -> man.set (fst @@ man.get flow, tl) flow);
  }


  (* Initial states *)
  (* ============== *)

  let init prog man flow =
    let flow', b = match D1.init prog (man1 man) flow with
      | None -> flow, false
      | Some flow' -> flow', true
    in
    match D2.init prog (man2 man) flow', b with
    | None, false -> None
    | None, true -> Some flow'
    | x, _ -> x


  (* Computation of post-conditions *)
  (* ============================== *)

  let exec_interface = Domain.{
    import = List.sort_uniq compare (D1.exec_interface.import @ D2.exec_interface.import);
    export = List.sort_uniq compare (D1.exec_interface.export @ D2.exec_interface.export);
  }

  let exec zone =
    match List.find_all (fun z -> Zone.subset z zone) D1.exec_interface.Domain.export,
          List.find_all (fun z -> Zone.subset z zone) D2.exec_interface.Domain.export
    with
    | [], [] -> raise Not_found

    | l, [] ->
      let f = Analyzer.mk_exec_of_zone_list l D1.exec in
      (fun stmt man flow -> f stmt (man1 man) flow)

    | [], l ->
      let f = Analyzer.mk_exec_of_zone_list l D2.exec in
      (fun stmt man flow -> f stmt (man2 man) flow)

    | l1, l2 ->
      let f1 = Analyzer.mk_exec_of_zone_list l1 D1.exec in
      let f2 = Analyzer.mk_exec_of_zone_list l2 D2.exec in
      (fun stmt man flow ->
         match f1 stmt (man1 man) flow with
         | Some post -> Some post
         | None -> f2 stmt (man2 man) flow
      )


  (* Evaluation of expressions *)
  (* ========================= *)

  let eval_interface = Domain.{
      import = List.sort_uniq compare (D1.eval_interface.import @ D2.eval_interface.import);
      export = List.sort_uniq compare (D1.eval_interface.export @ D2.eval_interface.export);
    }

  let eval zpath =
    match List.find_all (fun p -> Zone.subset2 p zpath) D1.eval_interface.Domain.export,
          List.find_all (fun p -> Zone.subset2 p zpath) D2.eval_interface.Domain.export
    with
    | [], [] -> raise Not_found

    | l, [] ->
      let f = Analyzer.mk_eval_of_zone_list l D1.eval in
      (fun exp man flow -> f exp (man1 man) flow)

    | [], l ->
      let f = Analyzer.mk_eval_of_zone_list l D2.eval in
      (fun exp man flow -> f exp (man2 man) flow)

    | l1, l2 ->
      let f1 = Analyzer.mk_eval_of_zone_list l1 D1.eval in
      let f2 = Analyzer.mk_eval_of_zone_list l2 D2.eval in
      (fun exp man flow ->
         match f1 exp (man1 man)  flow with
         | Some evl -> Some evl
         | None -> f2 exp (man2 man) flow
      )


  (* Query handler *)
  (* ============= *)

  let ask query man flow =
    let reply1 = D1.ask query (man1 man) flow in
    let reply2 = D2.ask query (man2 man) flow in
    Option.option_neutral2 (Query.join query) reply1 reply2

end


(* Registration of a stacked domain *)
(* ================================ *)

let register_domain d1 d2 =
  let module D1 = (val d1 : S) in
  let module D2 = (val d2 : Domain.DOMAIN) in
  let module D = Make(D1)(D2) in
  Domain.register_domain (module D)

(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(** Analyzer - Central orchestrer of the analysis architecture. *)

open Ast
open Lattice
open Flow
open Manager
open Domain
open Eval
open Post
open Zone

let debug fmt = Debug.debug ~channel:"framework.analyzer" fmt


(**
   Functor to create an [Analyzer] module from an top-level abstract domain.
*)
module Make(Domain : DOMAIN) =
struct

  module Cache = Cache.Make(struct type t = Domain.t end)


  (** Map giving the [exec] transfer function of a zone *)
  module ExecMap = MapExt.Make(struct type t = Zone.zone let compare = compare_zone end)


  (** Map giving the [eval] evaluation function of a zone path *)
  module EvalMap = MapExt.Make(struct type t = Zone.zone * Zone.zone let compare = Compare.pair compare_zone compare_zone end)


  (*==========================================================================*)
  (**                        {2 Initialization}                               *)
  (*==========================================================================*)

  let rec init prog : Domain.t flow =
    let flow0 = Flow.bottom Annotation.empty  |>
                Flow.set T_cur man.top man
    in
    match Domain.init prog man flow0 with
    | None -> flow0
    | Some flow -> flow



  (*==========================================================================*)
  (**                     {2 Statements execution}                            *)
  (*==========================================================================*)

  (** Build the map of exec functions *)
  and exec_map =
    let required = List.sort_uniq compare_zone (any_zone :: Domain.exec_interface.import) in
    let map = ExecMap.empty in
    (* Iterate over the required zones of domain D *)
    let ret = List.fold_left (fun acc zone ->
        if ExecMap.mem zone acc then
          acc
        else
          begin
            debug "Searching for an exec function for the zone %a" pp_zone zone;
            if List.exists (fun z -> sat_zone z zone) Domain.exec_interface.export then
              begin
                debug "exec for %a found" pp_zone zone;
                ExecMap.add zone (Domain.exec zone) acc
              end
            else
              Exceptions.panic "exec for %a not found" pp_zone zone
          end
      ) map required
    in
    ret

  and exec ?(zone = any_zone) (stmt: Ast.stmt) (flow: Domain.t flow) : Domain.t flow =
    debug
      "exec stmt in %a:@\n @[%a@]@\n zone: %a@\n input:@\n  @[%a@]"
      Location.pp_range_verbose stmt.srange
      pp_stmt stmt
      pp_zone zone
      (Flow.print man) flow
    ;
    let timer = Timing.start () in

    let zone_exec = ExecMap.find zone exec_map in

    let flow' = Cache.exec (fun stmt flow ->
        match zone_exec stmt man flow with
        | None ->
          Exceptions.panic
            "Unable to analyze statement in %a:@\n @[%a@]"
            Location.pp_range_verbose stmt.srange
            pp_stmt stmt

        | Some post -> post.flow
      ) zone stmt flow
    in

    let t = Timing.stop timer in
    Debug.debug ~channel:"framework.analyzer.profiler"
      "exec done in %.6fs of:@\n@[<v>  %a@]"
      t pp_stmt stmt
    ;

    debug
      "exec stmt done:@\n @[%a@]@\n zone: %a@\n input:@\n@[  %a@]@\n output@\n@[  %a@]"
      pp_stmt stmt
      pp_zone zone
      (Flow.print man) flow
      (Flow.print man) flow'
    ;
    flow'



  (*==========================================================================*)
  (**                   {2 Evaluation of expressions}                         *)
  (*==========================================================================*)

  (** Build the map of [eval] functions *)
  and eval_map =
    (* Iterate over the required zone paths of domain Domain *)
    List.fold_left (fun acc zpath ->
        if EvalMap.mem zpath acc then acc
        else
          begin
            debug "Searching for eval function for the zone path %a" pp_zone2 zpath;
            if List.exists (fun p -> sat_zone2 p zpath) Domain.eval_interface.export then
              begin
                debug "eval for %a found" pp_zone2 zpath;
                EvalMap.add zpath (Domain.eval zpath) acc
              end
            else
              Exceptions.panic "eval for %a not found" pp_zone2 zpath
          end
      ) EvalMap.empty (List.sort_uniq (Compare.pair compare_zone compare_zone) ((any_zone, any_zone)  :: Domain.eval_interface.import))


  (** Evaluation of expressions. *)
  and eval_opt ?(zone = (any_zone, any_zone)) (exp: Ast.expr) (flow: Domain.t flow) : (Domain.t, Ast.expr) evl option =
    debug
      "eval_opt expr in %a:@\n @[%a@]@\n zone: %a@\n input:@\n  @[%a@]"
      Location.pp_range_verbose exp.erange
      pp_expr exp
      pp_zone2 zone
      (Flow.print man) flow
    ;
    let timer = Timing.start () in

    let ret =
      (* Try static evaluation using the template of the destination zone *)
      match Zone.eval exp (snd zone) with
      | Keep ->
        debug "%a already in zone %a" pp_expr exp pp_zone (snd zone);
        Some (Eval.singleton exp flow)

      | _ as action ->
        debug "%a not in zone %a" pp_expr exp pp_zone (snd zone);
        let feval = EvalMap.find zone eval_map in
        let evl = Cache.eval (fun exp flow ->
            feval exp man flow
          ) zone exp flow
        in

        match evl with
        | Some _ -> debug "domains evaluated %a in %a" pp_expr exp pp_zone2 zone; evl
        | None ->
          debug "domains did not evaluate %a in %a" pp_expr exp pp_zone2 zone;
          match action with
          | Keep -> assert false (* case already processed *)
          | Process -> None
          | Visit ->
            debug "Visiting sub-expressions of %a" pp_expr exp;
            let open Visitor in
            let parts, builder = split_expr exp in
            match parts with
            | {exprs = []; stmts = []} -> None
            | {exprs; stmts = []} ->
              Eval.eval_list_opt exprs (eval_opt ~zone) flow |>
              Option.option_lift1 @@
              Eval.bind @@ fun exprs flow ->
              let exp = builder {exprs; stmts = []} in
              Eval.singleton exp flow

            | _ -> None
    in

    let t = Timing.stop timer in
    Debug.debug
      ~channel:"framework.analyzer.profiler"
      "eval done in %.6fs of @[%a@]"
      t pp_expr exp
    ;
    debug
      "eval_opt expr done:@\n @[%a@]@\n zone: %a@\n input:@\n@[  %a@]@\n output@\n@[  %a@]"
      pp_expr exp
      pp_zone2 zone
      (Flow.print man) flow
      (Option.print (Eval.print ~pp:pp_expr)) ret
    ;
    ret

  and eval ?(zone = (any_zone, any_zone)) (exp: Ast.expr) (flow: Domain.t flow) : (Domain.t, Ast.expr) evl =
    let ret =
      match eval_opt ~zone exp flow with
      | Some evl -> evl
      | None -> Eval.singleton exp flow
    in
    debug
      "eval expr done:@\n @[%a@]@\n zone: %a@\n input:@\n@[  %a@]@\n output@\n@[  %a@]"
      pp_expr exp
      pp_zone2 zone
      (Flow.print man) flow
      (Eval.print ~pp:pp_expr) ret
    ;
    ret

  (** Query handler. *)
  and ask : type r. r Query.query -> _ -> r =
    fun query flow ->
      match Domain.ask query man flow with
      | None -> raise Not_found
      | Some r -> r


  (** Top level manager *)

  and man : (Domain.t, Domain.t) man = {
    bottom = Domain.bottom;
    top = Domain.top;
    is_bottom = Domain.is_bottom;
    subset = Domain.subset;
    join = Domain.join;
    meet = Domain.meet;
    widen = Domain.widen;
    print = Domain.print;
    get = (fun flow -> flow);
    set = (fun flow _ -> flow);
    exec = exec;
    eval = eval;
    eval_opt = eval_opt;
    ask = ask;
  }

end

(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(**
   Unification domain.

   Signature for domains ensuring unification of an underlying abstraction 
   before calls to binary operators (⊆, ∪ and ∩).
*)

open Lattice
open Flow
open Manager
open Context
open Eval
open Query


(** Abstract domain signature. *)
module type DOMAIN = functor(SubDomain: Stateful.DOMAIN) ->
sig

  include Stateful.DOMAIN

  val unify : context ->
    t * SubDomain.t  -> t * SubDomain.t ->
    (t * SubDomain.t) * (t * SubDomain.t)

  val exec:
    ('a, t) manager -> ('a, SubDomain.t) manager -> Context.context -> Ast.stmt -> 'a flow ->
    'a flow option

  val eval:
    ('a, t) manager -> ('a, SubDomain.t) manager -> Context.context -> Ast.expr -> 'a flow ->
    (Ast.expr, 'a) evals option

  val ask:
    ('a, t) manager -> ('a, SubDomain.t) manager -> Context.context -> 'r Query.query -> 'a flow ->
    'r option

end



let domains : (string * (module DOMAIN)) list ref = ref []
let register_domain name modl = domains := (name, modl) :: !domains
let find_domain name = List.assoc name !domains

let return x = Some x
let fail = None


exception Not_supported
  
let mk_local_manager (type a) (dom: (module Stateful.DOMAIN with type t = a)) : (a, a) manager =
  let module Domain = (val dom) in
  let env_manager = Stateful.(mk_lattice_manager (module Domain : DOMAIN with type t = Domain.t)) in
  let rec man =
    {
      env = env_manager;
      flow = Flow.lift_lattice_manager env_manager;
      exec = (fun ctx stmt flow -> match Domain.exec man ctx stmt flow with Some flow -> flow | None -> raise Not_supported);
      eval = (fun ctx exp flow -> match Domain.eval man ctx exp flow with Some evl -> evl | None -> Eval.eval_singleton (Some exp, flow, []) );
      ask = (fun ctx query flow -> assert false);
      ax = {
        get = (fun env -> env);
        set = (fun env' env -> env');
      }
    }
  in
  man
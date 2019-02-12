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

(** Cache of post-conditions and evaluations *)

open Manager
open Ast
open Zone

let debug fmt = Debug.debug ~channel:"framework.cache" fmt

let opt_cache = ref 10

module Make(Domain: sig type t end) =
struct
  let exec_cache : ((zone * stmt * Domain.t flow) * Domain.t flow) list ref = ref []

  let eval_cache : (((zone * zone) * expr * Domain.t flow) * (Domain.t, expr) evl option) list ref = ref []

  let add_to_cache : type a. a list ref -> a -> unit =
    fun cache x ->
      cache := x :: (
          if List.length !cache < !opt_cache then !cache
          else List.rev @@ List.tl @@ List.rev !cache
        )

  let exec f zone stmt man flow =
    let ff () =
      match f stmt man flow with
      | None ->
        Exceptions.panic
          "Unable to analyze statement in %a:@\n @[%a@]"
          Location.pp_range stmt.srange
          pp_stmt stmt

      | Some post -> post.Post.flow
    in
    if !opt_cache == 0 then
      ff ()
    else
      try List.assoc (zone, stmt, flow) !exec_cache
      with Not_found ->
        let flow' = ff () in
        add_to_cache exec_cache ((zone, stmt, flow), flow');
        flow'

  let eval f zone exp man flow =
    if !opt_cache == 0
    then f exp man flow
    else
      try List.assoc (zone, exp, flow) !eval_cache
      with Not_found ->
        let evals = f exp man flow in
        add_to_cache eval_cache ((zone, exp, flow), evals);
        (
          match evals with
          | None -> ()
          | Some evl ->
            Eval.iter (fun case ->
              match case.expr with
              | Some e -> add_to_cache eval_cache ((zone, e, flow), Some (Eval.singleton e flow));
              | None -> ()
            ) evl
        );
        evals

end

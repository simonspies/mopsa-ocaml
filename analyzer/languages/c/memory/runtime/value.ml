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


(** Non-relational abstraction of pointer values *)


open Mopsa
open Sig.Abstraction.Value
open Universal.Ast
open Ast
open Common.Points_to
open Common.Base
open Top

open Framework.Lattices.Partial_inversible_map


module Status =
struct
  type t = 
    Untracked | Alive | Collected

  let compare a b =
    match a, b with 
    | Untracked, Untracked -> 0
    | Alive, Alive -> 0
    | Collected, Collected -> 0
    | _, _ -> compare a b (* FIXME: this is the MOPSA standard, but does not seem great *)


  let to_string s = 
    match s with
    | Untracked -> "untracked"
    | Alive -> "alive"
    | Collected -> "collected"
    
  let print printer b = pp_string printer (to_string b)
end

module Roots =
struct
  type t = 
    Rooted | NotRooted

  let compare a b =
    match a, b with 
    | NotRooted, NotRooted -> 0
    | Rooted, Rooted -> 0
    | _, _ -> compare a b (* FIXME: this is the MOPSA standard, but does not seem great *)


  let to_string s = 
    match s with
    | Rooted-> "root"
    | NotRooted -> "not rooted"
    
  let print printer b = pp_string printer (to_string b)
end
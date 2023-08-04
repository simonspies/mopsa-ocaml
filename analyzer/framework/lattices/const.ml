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


(** Lattice of constants *)

open Core.All


(** Signature of ordered types with printers *)
module type ORDER =
sig
  type t
  val compare: t -> t -> int
  val print : Print.printer -> t -> unit
  val to_string : t -> string
end


module Make(Const:ORDER) =
struct

  type t = Const.t Utils_core.Bot_top.with_bot_top

  let bottom : t = BOT

  let top : t = TOP
 
  let embed (x: Const.t) : t = Nbt x

  let is_const (x: t) (c: Const.t) = 
    match x with
    | TOP -> false
    | BOT -> false
    | Nbt d -> Const.compare c d = 0

  let map (f: Const.t -> Const.t) (x: t): t = 
    match x with
    | TOP -> TOP
    | BOT -> BOT
    | Nbt c -> Nbt (f c)

  let is_bottom (x:t) : bool = 
    match x with BOT -> true | _ -> false 

  let subset (x:t) (y:t) : bool = 
    match x, y with 
    | BOT, _ -> true 
    | _, TOP -> true 
    | Nbt c1, Nbt c2 -> compare c1 c2 = 0
    | _ -> false 

  let join x y : t =
    if subset x y then y else TOP

  let meet x y : t =
    if subset x y then x else BOT

  let widen ctx x y : t = join x y

  let print (printer: Print.printer) (x: t) : unit =
    match x with 
    | TOP -> Print.pp_string printer Utils_core.Top.top_string
    | BOT -> Print.pp_string printer Utils_core.Bot.bot_string
    | Nbt s -> Const.print printer s

  let to_string (x: t) : string =
      match x with 
      | TOP -> Utils_core.Top.top_string
      | BOT -> Utils_core.Bot.bot_string
      | Nbt s -> Const.to_string s
end

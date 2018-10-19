(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(**
   [compose cl] applies a list of comparison functions [cl] in sequence
   and stops when encountering the first non-zero result.
*)
let rec compose = function
  | [] -> 0
  | cmp :: tl ->
    let r = cmp () in
    if r <> 0 then r else compose tl

(** [list p] lifts the 'a compare function [p] to 'a list *)
let list p =
  fun l l' ->
    let rec aux a b = match a,b with
      | t::r , t'::r' -> let x = p t t' in if x = 0 then aux r r' else x
      | []   , t'::r' -> -1
      | []   , []     -> 0
      | t::r , []     -> 1
    in
    aux l l'

(** [pair p] lifts the 'a compare function [p], 'b compare
   function [q] to 'a * 'b *)
let pair p q =
  fun (a,b) (c,d) ->
    let x = p a c in
    if x = 0 then q b d else x

(** [triple p] lifts the 'a compare function [p], 'b compare
   function [q], 'c compare function [r] to 'a * 'b * 'c *)
let triple p q r =
  fun (a,b,c) (d,e,f) ->
    let x = p a d in
    if x = 0 then
      let y = q b e in
      if y = 0 then
        r c f
      else
        y
    else
      x

(** [option p] lifts [p: 'a -> 'a -> int] to ['a option -> 'a option -> int] *)
let option p q r =
  match q, r with
  | Some x, Some y -> p x y
  | _ -> Pervasives.compare q r
(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(** Reduction operators of post-conditions *)

open Manager
open Pool

module type REDUCTION =
sig
  val trigger : Post.channel option
  val reduce : Ast.stmt -> ('a, 'd) domain_man -> ('a, 'v) nonrel_man -> ('a, 'b) man -> 'a flow -> 'a flow
end

(** Registration *)
let reductions : (string * (module REDUCTION)) list ref = ref []
let register_reduction name rule = reductions := (name, rule) :: !reductions
let find_reduction name = List.assoc name !reductions
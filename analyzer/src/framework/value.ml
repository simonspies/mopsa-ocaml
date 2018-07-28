(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(** Abstraction of values. *)

module type VALUE =
sig

  (*==========================================================================*)
                        (** {2 Lattice structure} *)
  (*==========================================================================*)

  include Lattice.LATTICE

  val of_constant : Ast.constant -> t
  (** Create a singleton abstract value from a constant. *)

  (*==========================================================================*)
                          (** {2 Forward semantics} *)
  (*==========================================================================*)

  val unop : Ast.operator -> t -> t
  (** Forward evaluation of unary operators. *)

  val binop : Ast.operator -> t -> t -> t
  (** Forward evaluation of binary operators. *)


  (*==========================================================================*)
                          (** {2 Backward operators} *)
  (*==========================================================================*)

  val bwd_unop : Ast.operator -> t -> t -> t
  (** Backward evaluation of unary operators.
      [bwd_unop op x r] returns x':
       - x' abstracts the set of v in x such as op v is in r
       i.e., we fiter the abstract values x knowing the result r of applying
       the operation on x

       it is safe, as first approximation, to implement it as the identity:
       let bwd_unop _ x _ = x
     *)

  val bwd_binop : Ast.operator -> t -> t -> t -> t * t
  (** Backward evaluation of binary operators.
      [bwd_binop op x y r] returns (x',y') where
      - x' abstracts the set of v  in x such that v op v' is in r for some v' in y
      - y' abstracts the set of v' in y such that v op v' is in r for some v  in x
      i.e., we filter the abstract values x and y knowing that, after
      applying the operation op, the result is in r

      it is safe, as first approximation, to implement it as the identity:
      let bwd_binop _ x y _ = (x,y)
  *)

  val compare : Ast.operator -> t -> t -> t * t
  (** Forward evaluation of boolean comparisons. [compare op x y] returns (x',y') where:
       - x' abstracts the set of v  in x such that v op v' is true for some v' in y
       - y' abstracts the set of v' in y such that v op v' is true for some v  in x
       i.e., we filter the abstract values x and y knowing that the test is true

       a safe, but not precise implementation, would be:
       compare op x y = (x,y)
  *)

  (*==========================================================================*)
  (**                          {2 Value zone}                                 *)
  (*==========================================================================*)
  val zone : Zone.t
  (** Language zone in which the value abstraction is defined *)

end

let values : (string * (module VALUE)) list ref = ref []
let register_value name modl = values := (name, modl) :: !values
let find_value name = List.assoc name !values

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

(** Expressions

    This module allows adding new expressions to the extensible Mopsa AST.

    New expressions are added by extending the type [expr_kind]. For example,
    to add an expression for subscript access to arrays
    {[
      type expr_kind += E_array_subscript of expr * expr
    ]}

    New expressions need to be registered using [register_expr] as follows:
    {[
      let () = register_expr {
          compare = (fun next e1 e2 ->
              match ekind e1, ekind e2 with
              | E_array_subscript(a1,i1), E_array_subscript(a2,i2) ->
                Compare.pair compare_expr compare_expr (a1,i1) (a2,i2)
              | _ -> next e1 e2
            );
          print = (fun next fmt e ->
              match ekind e with
              | E_array_subscript(a,i) -> 
                Format.fprintf fmt "%a[%a]"
                  pp_expr a
                  pp_expr i
              | _ -> next fmt e
            );
        }
    ]}

    Registered expressions can be compare using function [compare_expr] and 
    printed using the function [pp_expr].

 *)


open Location
open Typ
open Program
open Operator
open Constant
open Var
open Format


type expr_kind = ..
(** Extensible type of expression kinds *)

type expr = {
  ekind: expr_kind;   (** kind of the expression *)
  etyp: typ;          (** type of the expression *)
  erange: range;      (** location range of the expression *)
  eprev: expr option; (** previous version of the expression in the
                          transformation lineage *)
}
(** Expressions *)


val compare_expr : expr -> expr -> int
(** [compare_expr e1 e2] implements a total order between expressions *)

val pp_expr : Format.formatter -> expr -> unit
(** [pp_expr fmt e] pretty-prints expression [e] with format [fmt] *)

val ekind : expr -> expr_kind
(** Get the kind of an expression *)

val etyp : expr -> typ
(** Get the type of an expression *)

val erange : expr -> range
(** Get the location of an expression *)

val mk_expr : ?etyp:typ -> ?eprev:expr option -> expr_kind -> range -> expr
(** [mk_expr ~etyp:t ~eprev:e ekind range] constructs an expression with kind
    [ekind], location [range], type [t] ([T_any] if not given) and previous
    version [e] ([None] if not given) *) 


(****************************************************************************)
(**                         {1 Registration}                                *)
(****************************************************************************)

val register_expr : expr TypeExt.info -> unit
(** [register_expr info] registers new expressions with their comparison
    function [info.compare] and pretty-printer [info.print] *)

val register_expr_compare : expr TypeExt.compare -> unit
(** [register_expr_compare compare] registers a new expression comparison *)

val register_expr_pp : expr TypeExt.print -> unit
(** [register_expr_compare compare] registers a new expression printer *)


(****************************************************************************)
(**                    {1 Some common expressions}                          *)
(****************************************************************************)

(** {2 Variable expressions} *)

(** Variables *)
type expr_kind += E_var of var         (** variable *) *
                           mode option (** optional access mode overloading
                                           the variable's access mode *)

val mk_var : var -> ?mode:mode option -> range -> expr
(** Create a variable expression *)

val weaken_var_expr : expr -> expr
(** Change the access mode of a variable expression to [WEAK] *)

val strongify_var_expr : expr -> expr
(** Change the access mode of a variable expression to [STRONG] *)

val var_mode : var -> mode option -> mode
(** Get the overloaded access mode of a variable *)


(** {2 Constant expressions} *)

(** Constants *)
type expr_kind += E_constant of constant

val mk_constant : ?etyp:typ -> constant -> range -> expr
(** Create a constant expression *)


(** {2 Unary expressions} *)

(** Unary operator expressions *)
type expr_kind += E_unop of operator (** operator *) *
                            expr     (** operand *)
  

val mk_unop :  ?etyp:typ -> operator -> expr -> range -> expr
(** Create a unary operator expression *)

val mk_not : expr -> range -> expr
(** [mk_not e range] returns the negation of expression [e] using the operator
    {!Operator.O_log_not} *)


(** {2 Binary expressions} *)

(** Binary operator expressions *)
type expr_kind += E_binop of operator (** operator *) *
                             expr     (** first operand *) *
                             expr     (** second operand *)

val mk_binop : ?etyp:typ -> expr -> operator -> expr -> range -> expr
(** Create a binary operator expression *)


(****************************************************************************)
(**                      {1 Expressions containers}                         *)
(****************************************************************************)

module ExprSet : SetExtSig.S with type elt = expr
(** Sets of expression *)

module ExprMap : MapExtSig.S with type key = expr
(** Maps of expressions *)
(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(** Non-relational numeric abstraction of machine integers. *)

open Framework.Domains.Global
open Framework.Domains
open Framework.Manager
open Framework.Flow
open Framework.Ast
open Universal.Ast
open Ast

let name = "c.memory.numeric.machine_integers"
let debug fmt = Debug.debug ~channel:name fmt


(** Abstract domain. *)
module Domain =
struct


  (*==========================================================================*)
  (**                           {2 Lattice}                                   *)
  (*==========================================================================*)

  module VMap = Universal.Nonrel.Domain.Make(Universal.Numeric.Integers)

  include VMap

  let print fmt a =
    Format.fprintf fmt "int: @[%a@]@\n"
      VMap.print a

  (*==========================================================================*)
  (**                        {2 Transfer functions}                           *)
  (*==========================================================================*)

  let init prog man flow = flow

  let eval exp man ctx flow =
    match ekind exp with
    | E_var v when is_inttype v.vtyp ->
      assert false

    | _ -> None

  let exec stmt man ctx flow =
    match skind stmt with
    | S_assign({ekind = E_var v}, e) when is_inttype e.etyp ->
      assert false

    | _ -> None

  let ask _ _ _ _ = None

end


(*==========================================================================*)
(**                            {2 Setup}                                    *)
(*==========================================================================*)

let setup () =
  register_domain name (module Domain)

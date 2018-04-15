(**
  Relation - Relations (or multimaps) between ordered sets.

  Copyright (C) 2018 The MOPSA Project

  This program is free software: you can redistribute it and/or modify
  it under the terms of the CeCILL license V2.1.

  @author Antoine Mine'
 *)

open MapExtSig

module Make(Ord: OrderedType) : S with type key = Ord.t
(** Generic functor to build a map data-type from ordered keys
    to an arbitrary type.
 *)     

module StringMap   : S with type key = string
module IntMap      : S with type key = int
module Int32Map    : S with type key = int32
module Int64Map    : S with type key = int64
module ZMap        : S with type key = Z.t
(** A few useful map instances. *)
           
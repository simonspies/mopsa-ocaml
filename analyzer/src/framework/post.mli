(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

open Manager

type channel = ..
(** Reduction channels *)

type 'a post = {
  flow : 'a flow;
  mergers : Ast.stmt list;
  channels : channel list;
}
(** Post-conditions of statement transfer functions *)

val of_flow : 'a flow -> 'a post

val add_mergers : Ast.stmt list -> 'a post -> 'a post
(** [add_mergers m p] adds meet mergers [m] to post-condition [p] *)

val add_channels : channel list -> 'a post -> 'a post
(** [add_channels ch p] adds reduction channels [ch] to post-condition [p] *)

val join : ('a, _) man -> 'a post -> 'a post -> 'a post
(** Join two post-conditions *)

val bind :
  ?zone:Zone.zone -> ('a, _) man ->
  ('e -> 'a flow -> 'a post) -> ('a, 'e) evl -> 'a post

val assume :
  Ast.expr -> ?zone:Zone.zone -> ('a, _) man ->
  fthen:('a Flow.flow -> 'a post) ->
  felse:('a Flow.flow -> 'a post) ->
  ?fboth:('a Flow.flow -> 'a Flow.flow -> 'a post) ->
  ?fnone:('a Flow.flow -> 'a post) ->
  'a flow ->
  'a post

val switch :
  ((Ast.expr * bool) list * ('a flow -> 'a post)) list ->
  ?zone:Zone.zone ->
  ('a, 'b) man -> 'a flow ->
  'a post

val print : ('a, _) man -> Format.formatter -> 'a post -> unit

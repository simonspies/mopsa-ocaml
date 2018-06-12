(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)


(** Post-conditions of exec transfer functions *)

open Flow

type reduction_channel = ..

type 'a post = {
  flow : 'a flow;
  channels : reduction_channel list;
  mergers : Ast.stmt list;
}

let singleton ?(channels = []) ?(mergers = []) flow = {
  flow;
  channels;
  mergers;
}

let join (post1: 'a post) (post2: 'a post) ~(flow_join: 'a flow -> 'a flow -> 'a flow) : 'a post =
  {
    flow     = flow_join post1.flow post2.flow;
    channels = post1.channels @ post2.channels;
    mergers  = post1.mergers @ post2.mergers;
  }

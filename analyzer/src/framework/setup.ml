(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(** Information about system setup of the analyzer *)

(** Path to share directory *)
let opt_share_dir = ref ""

let set_share_dir dir =
  if not (Sys.is_directory dir) then Exceptions.panic "%s is not a directory" dir;
  opt_share_dir := dir

(* Return the path to the configurations directory *)
let get_configs_dir () =
  Filename.concat !opt_share_dir "configs"

(* Return the path to the stubs directory *)
let get_stubs_dir () =
  Filename.concat !opt_share_dir "stubs"

(* Return the path to the stubs directory of a language *)
let get_lang_stubs_dir lang () =
  Filename.concat (get_stubs_dir ()) lang

let resolve_stub lang stub =
  Filename.concat (get_lang_stubs_dir lang ()) stub
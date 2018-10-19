(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)


(** Render the output of an analysis depending on the selected engine. *)

type format =
  | F_text (* Textual output *)
  | F_json (* Formatted output in JSON *)


(* Command line option *)
(* ------------------- *)

let opt_format = ref F_text
let opt_file = ref None

let () =
  Options.register_option (
    "-format",
    Arg.String (fun s ->
        match s with
        | "text" -> opt_format := F_text
        | "json" -> opt_format := F_json
        | _ -> Exceptions.fail "Unknown output format %s" s
      ),
    " display format of the results. Possible values: text or json (default: text)."
  );

  Options.register_option (
    "-output",
    Arg.String (fun s -> opt_file := Some s),
    " path where results are stored."
  )



(* Result rendering *)
(* ---------------- *)

(* Print collected alarms in the desired output format *)
let render man flow time files =
  let alarms = Flow.fold (fun acc tk env ->
      match tk with
      | Alarm.T_alarm a -> a :: acc
      | _ -> acc
    ) [] man flow
  in
  match !opt_format with
  | F_text -> Text.render man alarms time files !opt_file
  | F_json -> Json.render man alarms time files !opt_file


let panic ?btrace exn files =
  match !opt_format with
  | F_text -> Text.panic ?btrace exn files !opt_file
  | F_json -> Json.panic ?btrace exn files !opt_file
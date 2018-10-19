(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)


(** Format the results of the analysis in JSON. *)

open Yojson.Basic

let print json out =
  let channel =
    match out with
    | None -> stdout
    | Some file -> open_out file
  in
  to_channel channel json

let render man alarms time files out =
  let json : json = `Assoc [
      "success", `Bool true;
      "time", `Float time;
      "files", `List (List.map (fun f -> `String f) files);
      "alarms", `List (List.map (fun alarm ->
          let title =
            let () = Alarm.pp_alarm_title Format.str_formatter alarm in
            Format.flush_str_formatter ()
          in
          let trace = alarm.Alarm.alarm_trace in
          `Assoc [
            "title", `String title;
            "trace", `List (List.map (fun range ->
                let origin = Location.get_origin_range range in
                let file = Location.(origin.range_begin.loc_file) in
                let line = Location.(origin.range_begin.loc_line) in
                let r = file ^ ":" ^ (string_of_int line) in
                `String r
              ) trace)
          ]
        ) alarms);
    ]
  in
  print json out


let panic ?(btrace="<none>") exn files out =
  let json : json = `Assoc [
      "success", `Bool false;
      "files", `List (List.map (fun f -> `String f) files);
      "exception", `String (Printexc.to_string exn);
      "backtrace", `String btrace;
    ]
  in
  print json out
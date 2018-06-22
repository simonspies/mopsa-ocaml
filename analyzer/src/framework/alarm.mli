(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)


(** Alarms allows reporting potential errors inferred by abstract domains. *)

type alarm_kind = ..

type alarm_level =
  | ERROR
  | WARNING
  | PANIC

type alarm = {
  alarm_kind : alarm_kind;   (** the kind of the alarm *)
  alarm_range : Utils.Location.range;       (** the range of the program where the alarm was detected *)
  alarm_level : alarm_level;
}


val register_alarm_compare: ((alarm -> alarm -> int) -> alarm -> alarm -> int) -> unit

val compare_alarm : alarm -> alarm -> int


(*==========================================================================*)
                           (** {2 Query} *)
(*==========================================================================*)


type _ Query.query +=
  | QGetAlarms: (alarm list) Query.query
  (** Query to extract collected alarms *)


val register_pp_alarm : ((Format.formatter -> alarm -> unit) -> Format.formatter -> alarm -> unit) -> unit

val pp_alarm : Format.formatter -> alarm -> unit

(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(** C Runtime errors. *)

open Framework.Ast
open Framework.Pp
open Framework.Domains.Stateless
open Framework.Manager
open Framework.Visitor
open Framework.Domains
open Framework.Alarm
open Framework.Flow
open Universal.Ast
open Ast


let name = "c.alarms"
let debug fmt = Debug.debug ~channel:name fmt


(*==========================================================================*)
(**                   {2 Errors flows and alarms}                           *)
(*==========================================================================*)


type token +=
  | TOutOfBound of range
  | TNullDeref of range
  | TInvalidDeref of range
  | TIntegerOverflow of range
  | TDivideByZero of range

type alarm_kind +=
  | AOutOfBound
  | ANullDeref
  | AInvalidDeref
  | AIntegerOverflow
  | ADivideByZero

let is_error_token = function
  | TOutOfBound _ -> true
  | TNullDeref _ -> true
  | TInvalidDeref _ -> true
  | TIntegerOverflow _ -> true
  | TDivideByZero _ -> true
  | _ -> false

let error_token_range = function
  | TOutOfBound(r) -> r
  | TNullDeref(r) -> r
  | TInvalidDeref(r) -> r
  | TIntegerOverflow(r) -> r
  | TDivideByZero(r) -> r
  | _ -> assert false

(*==========================================================================*)
(**                       {2 Abstract domain}                               *)
(*==========================================================================*)


module Domain = struct


  (*==========================================================================*)
  (**                     {2 Transfer functions}                              *)
  (*==========================================================================*)

  let init man ctx prog flow = ctx, flow

  let exec man ctx stmt flow = None

  let eval man ctx exp flow = None

  let ask : type r. ('a, unit) manager -> Framework.Context.context -> r Framework.Query.query -> 'a flow -> r option =
    fun man ctx query flow ->
      match query with
      | Framework.Alarm.QGetAlarms ->
        let alarms = man.flow.fold (fun acc env -> function
            | TOutOfBound range ->
              let alarm = {
                alarm_kind = AOutOfBound;
                alarm_range = range;
                alarm_level = ERROR;
              } in
              alarm :: acc

            | TNullDeref(range) ->
              let alarm = {
                alarm_kind = ANullDeref;
                alarm_range = range;
                alarm_level = ERROR;
              } in
              alarm :: acc

            | TInvalidDeref(range) ->
              let alarm = {
                alarm_kind = AInvalidDeref;
                alarm_level = ERROR;
                alarm_range = range;
              } in
              alarm :: acc

            | TIntegerOverflow(range) ->
              let alarm = {
                alarm_kind = AIntegerOverflow;
                alarm_level = ERROR;
                alarm_range = range;
              } in
              alarm :: acc

            | TDivideByZero(range) ->
              let alarm = {
                alarm_kind = ADivideByZero;
                alarm_range = range;
                alarm_level = ERROR;
              } in
              alarm :: acc

            | _ -> acc
          ) [] flow
        in
        Some alarms

      | _ -> None

end

let setup () =
  register_domain name (module Domain);

  register_pp_token (fun next fmt -> function
      | TOutOfBound(r) -> Format.fprintf fmt "outbound@%a" Framework.Pp.pp_range r
      | TNullDeref(r) -> Format.fprintf fmt "null@%a" Framework.Pp.pp_range r
      | TInvalidDeref(r) -> Format.fprintf fmt "invalid@%a" Framework.Pp.pp_range r
      | TIntegerOverflow(r) -> Format.fprintf fmt "integer overflow@%a" Framework.Pp.pp_range r
      | TDivideByZero(r) -> Format.fprintf fmt "division by zero @%a" Framework.Pp.pp_range r
      | tk -> next fmt tk
    );

  register_pp_alarm (fun next fmt alarm ->
      match alarm.alarm_kind with
      | AOutOfBound -> Format.fprintf fmt "Out of bound access"
      | ANullDeref -> Format.fprintf fmt "Null pointer dereference"
      | AInvalidDeref -> Format.fprintf fmt "Invalid pointer dereference"
      | AIntegerOverflow -> Format.fprintf fmt "Integer overflow"
      | ADivideByZero -> Format.fprintf fmt "Division by zero"
      | _ -> next fmt alarm
    );

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

open Mopsa


type check +=
   | CHK_PY_UNCAUGHT_EXCEPTION
   | CHK_PY_STOPITERATION
   | CHK_PY_ATTRIBUTEERROR
   | CHK_PY_ASSERTIONERROR
   | CHK_PY_INDEXERROR
   | CHK_PY_KEYERROR
   | CHK_PY_LOOKUPERROR
   | CHK_PY_MODULENOTFOUNDERROR
   | CHK_PY_NAMEERROR
   | CHK_PY_OVERFLOWERROR
   | CHK_PY_SYSTEMERROR
   | CHK_PY_TYPEERROR
   | CHK_PY_UNBOUNDLOCALERROR
   | CHK_PY_VALUEERROR
   | CHK_PY_ZERODIVISIONERROR

type alarm_kind += A_py_uncaught_exception of expr * string * Universal.Strings.Powerset.StringPower.t


let raise_py_uncaught_exception_alarm exn exn_name exn_messages range lattice flow =
  let cs = Flow.get_callstack flow in
  let alarm = mk_alarm (A_py_uncaught_exception (exn,exn_name,exn_messages)) cs range in
  Flow.raise_alarm alarm ~bottom:false lattice flow

let py_name_to_check = function
  | "StopIteration" -> CHK_PY_STOPITERATION
  | "AttributeError" -> CHK_PY_ATTRIBUTEERROR
  | "AssertionError" -> CHK_PY_ASSERTIONERROR
  | "IndexError" -> CHK_PY_INDEXERROR
  | "KeyError" -> CHK_PY_KEYERROR
  | "LookUpError" -> CHK_PY_LOOKUPERROR
  | "ModuleNotFoundError" -> CHK_PY_MODULENOTFOUNDERROR
  | "NameError" -> CHK_PY_NAMEERROR
  | "OverflowError" -> CHK_PY_OVERFLOWERROR
  | "SystemError" -> CHK_PY_SYSTEMERROR
  | "TypeError" -> CHK_PY_TYPEERROR
  | "UnboundLocalError" -> CHK_PY_UNBOUNDLOCALERROR
  | "ValueError" -> CHK_PY_VALUEERROR
  | "ZeroDivisionError" -> CHK_PY_ZERODIVISIONERROR
  | _ -> CHK_PY_UNCAUGHT_EXCEPTION

let py_check_to_name = function
  | CHK_PY_UNCAUGHT_EXCEPTION -> "Python"
  | CHK_PY_STOPITERATION -> "StopIteration"
  | CHK_PY_ATTRIBUTEERROR -> "AttributeError"
  | CHK_PY_ASSERTIONERROR -> "AssertionError"
  | CHK_PY_INDEXERROR -> "IndexError"
  | CHK_PY_KEYERROR -> "KeyError"
  | CHK_PY_LOOKUPERROR -> "LookupError"
  | CHK_PY_MODULENOTFOUNDERROR -> "ModuleNotFoundError"
  | CHK_PY_NAMEERROR -> "NameError"
  | CHK_PY_OVERFLOWERROR -> "OverflowError"
  | CHK_PY_SYSTEMERROR -> "SystemError"
  | CHK_PY_TYPEERROR -> "TypeError"
  | CHK_PY_UNBOUNDLOCALERROR -> "UnboundLocalError"
  | CHK_PY_VALUEERROR -> "ValueError"
  | CHK_PY_ZERODIVISIONERROR -> "ZeroDivisionError"
  | _ -> assert false

let () =
  register_check (fun default fmt a ->
        match a with
        | CHK_PY_UNCAUGHT_EXCEPTION
        | CHK_PY_STOPITERATION
        | CHK_PY_ATTRIBUTEERROR
        | CHK_PY_ASSERTIONERROR
        | CHK_PY_INDEXERROR
        | CHK_PY_KEYERROR
        | CHK_PY_LOOKUPERROR
        | CHK_PY_MODULENOTFOUNDERROR
        | CHK_PY_NAMEERROR
        | CHK_PY_OVERFLOWERROR
        | CHK_PY_SYSTEMERROR
        | CHK_PY_TYPEERROR
        | CHK_PY_UNBOUNDLOCALERROR
        | CHK_PY_VALUEERROR
        | CHK_PY_ZERODIVISIONERROR -> Format.fprintf fmt "%s exception" (py_check_to_name a)
        | _ -> default fmt a
    );
  register_alarm {
      check = (fun next -> function
                | A_py_uncaught_exception (_, n, _) -> py_name_to_check n
                | a -> next a
              );
      compare = (fun default a a' ->
        match a, a' with
        | A_py_uncaught_exception (e, n, m), A_py_uncaught_exception (e', n', m') ->
           Compare.compose
             [
               (fun () -> compare_expr e e');
               (fun () -> Stdlib.compare n n');
               (fun () -> Universal.Strings.Powerset.StringPower.compare m m');
             ]
        | _ -> default a a'
      );
      print = (fun default fmt a ->
        match a with
        | A_py_uncaught_exception (e, n, m) -> Format.fprintf fmt "Uncaught Python exception: %s: %a" n (format Universal.Strings.Powerset.StringPower.print) m
        | _ -> default fmt a
        );
      join = (fun next a1 a2 ->
        match a1, a2 with
        | A_py_uncaught_exception _, A_py_uncaught_exception _ ->
           if compare_alarm_kind a1 a2 = 0 then Some a1
           else None
        | _ -> next a1 a2
      );
    }

(** Flow token for exceptions *)
type py_exc_kind =
  | Py_exc_unprecise
  | Py_exc_with_callstack of range * callstack

type token +=
   | T_py_exception of expr (* the exception *) * string (* type of exception as str *) * Universal.Strings.Powerset.StringPower.t (* exception messages *) * py_exc_kind

let mk_py_unprecise_exception obj name =
  T_py_exception(obj,name,Universal.Strings.Powerset.StringPower.empty,Py_exc_unprecise)

let mk_py_exception obj name messages ~cs range =
  T_py_exception (obj, name, messages, Py_exc_with_callstack (range,cs))

let pp_py_exc_kind fmt = function
  | Py_exc_unprecise -> ()
  | Py_exc_with_callstack (range,cs) -> Format.fprintf fmt "%a@,%a" pp_range range pp_callstack_short cs

let () =
  register_token {
    compare = (fun next tk1 tk2 ->
        match tk1, tk2 with
        | T_py_exception (e1,n1,m1,k1), T_py_exception (e2,n2,m2,k2) ->
          Compare.compose [
              (fun () -> compare_expr e1 e2);
              (fun () -> Stdlib.compare n1 n2);
              (fun () -> Universal.Strings.Powerset.StringPower.compare m1 m2);
            (fun () ->
               match k1, k2 with
               | Py_exc_unprecise, Py_exc_unprecise -> 0
               | Py_exc_with_callstack (r1, cs1), Py_exc_with_callstack (r2, cs2) ->
                 Compare.compose [
                   (fun () -> compare_range r1 r2);
                   (fun () -> compare_callstack cs1 cs2);
                 ]
               | _ -> compare k1 k2
            );
          ]
        | _ -> next tk1 tk2
      );
    print = (fun next fmt tk ->
        match tk with
        | T_py_exception (_,name,str,k) -> Format.fprintf fmt "@[<hv 2>PyExc(%s: %a)@,%a@]" name (format Universal.Strings.Powerset.StringPower.print) str pp_py_exc_kind k
        | _ -> next fmt tk);
  }


type check += CHK_PY_INVALID_TYPE_ANNOTATION
type alarm_kind += A_py_invalid_type_annotation of expr * expr

let () =
  register_check (fun next fmt -> function
      | CHK_PY_INVALID_TYPE_ANNOTATION -> Format.fprintf fmt " Type annotations"
      | a -> next fmt a)

let () =
  register_alarm {
      check = (fun next -> function
                | A_py_invalid_type_annotation _ -> CHK_PY_INVALID_TYPE_ANNOTATION
                | a -> next a);
      compare = (fun next a1 a2 ->
        match a1, a2 with
        | A_py_invalid_type_annotation (v1, a1), A_py_invalid_type_annotation (v2, a2) ->
           Compare.compose
             [
               (fun () -> compare_expr v1 v2);
               (fun () -> compare_expr a1 a2);
             ]
        | _ -> next a1 a2);
      print = (fun next fmt -> function
                | A_py_invalid_type_annotation (v, annot) ->
                   Format.fprintf fmt "Variable '%a' does not satisfy annotation '%a'" pp_expr v pp_expr annot
                | a -> next fmt a);
      join = (fun next -> next);
    }

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

(** Heap addresses *)

open Mopsa_utils
open Var

(** Kind of heap addresses, used to store extra information. *)
type addr_kind = ..

let addr_kind_compare_chain : (addr_kind -> addr_kind -> int) ref =
  ref (fun a1 a2 -> compare a1 a2)

let addr_kind_pp_chain : (Format.formatter -> addr_kind -> unit) ref =
  ref (fun fmt a -> Exceptions.panic "addr_kind_pp_chain: unknown address")

let pp_addr_kind fmt ak =
  !addr_kind_pp_chain fmt ak

let compare_addr_kind ak1 ak2 =
  if ak1 == ak2 then 0 else
  !addr_kind_compare_chain ak1 ak2

let register_addr_kind (info: addr_kind TypeExt.info) =
  addr_kind_compare_chain := info.compare !addr_kind_compare_chain;
  addr_kind_pp_chain := info.print !addr_kind_pp_chain;
  ()


(** Addresses are grouped by static criteria to make them finite *)
type addr_partitioning = ..

type addr_partitioning +=
  | G_all (** Group all addresses into one *)

let addr_partitioning_compare_chain : (addr_partitioning -> addr_partitioning -> int) ref =
  ref (fun a1 a2 -> compare a1 a2)

let addr_partitioning_pp_chain : (Format.formatter -> addr_partitioning -> unit) ref =
  ref (fun fmt g ->
      match g with
      | G_all -> Format.pp_print_string fmt "*"
      | _     -> Exceptions.panic "pp_addr_partitioning: not registered"
    )

(** Command line option to use hashes as address format *)
let opt_hash_addr = ref false

let pp_addr_partitioning_hash fmt (g:addr_partitioning) =
  let s = Format.asprintf "%a" !addr_partitioning_pp_chain g in
  let md5 = Digest.string s |> Digest.to_hex in
  Format.pp_print_string fmt (String.sub md5 0 7)

(** Print a partitioning policy. Flag [full] overloads the option
    [opt_hash_addr] and displays the full partitioning string (not its hash,
    which is useful for creating unique names of addresses) *)
let pp_addr_partitioning ?(full=false) fmt ak =
  match ak with
  | G_all -> !addr_partitioning_pp_chain fmt ak
  | _ ->
    if !opt_hash_addr && not full
    then pp_addr_partitioning_hash fmt ak
    else !addr_partitioning_pp_chain fmt ak

let pp_addr_partitioning_full fmt ak =
  !addr_partitioning_pp_chain fmt ak

let compare_addr_partitioning a1 a2 =
  if a1 == a2 then 0 else !addr_partitioning_compare_chain a1 a2

let register_addr_partitioning (info: addr_partitioning TypeExt.info) =
  addr_partitioning_compare_chain := info.compare !addr_partitioning_compare_chain;
  addr_partitioning_pp_chain := info.print !addr_partitioning_pp_chain;
  ()

(** Heap addresses. *)
type addr = {
  addr_kind : addr_kind;                 (** Kind of the address. *)
  addr_partitioning : addr_partitioning; (** Partitioning policy of the address *)
  addr_mode : mode;                      (** Assignment mode of address (string or weak) *)
}

let akind addr = addr.addr_kind

let pp_addr fmt a =
  Format.fprintf fmt "@@%a%a%s"
    pp_addr_kind a.addr_kind
    (fun fmt -> function
       | G_all -> ()
       | p     -> Format.fprintf fmt ":%a" (pp_addr_partitioning ~full:false) p )
    a.addr_partitioning
    (match a.addr_mode with WEAK -> ":w" | STRONG -> "")

(** Get the unique name of an address. This is safer and faster than calling
    [Format.asprintf "%s" pp_addr a] when [opt_hash_addr] is set. *)
let addr_uniq_name a =
  Format.asprintf "@@%a%a%s"
    pp_addr_kind a.addr_kind
    (fun fmt -> function
       | G_all -> ()
       | p     -> Format.fprintf fmt ":%a" (pp_addr_partitioning ~full:true) p )
    a.addr_partitioning
    (match a.addr_mode with WEAK -> ":w" | STRONG -> "")

let compare_addr a b =
  if a == b then 0
  else Compare.compose [
      (fun () -> compare_addr_kind a.addr_kind b.addr_kind);
      (fun () -> compare_addr_partitioning a.addr_partitioning b.addr_partitioning);
      (fun () -> compare_mode a.addr_mode b.addr_mode);
    ]

let addr_mode (a:addr) (omode: mode option) : mode =
  match omode with
  | None -> a.addr_mode
  | Some m -> m


(** Address variables *)
type var_kind +=
  | V_addr_attr of addr * string

let () =
  register_var {
    compare = (fun next v1 v2 ->
        match vkind v1, vkind v2 with
        | V_addr_attr (a1,attr1), V_addr_attr (a2,attr2) ->
          Compare.compose [
            (fun () -> compare_addr a1 a2);
            (fun () -> compare attr1 attr2)
          ]
        | _ -> next v1 v2
      );
    print = (fun next fmt v ->
        match vkind v with
        | V_addr_attr (addr, attr) -> Format.fprintf fmt "%a.%s" pp_addr addr attr
        | _ -> next fmt v
      )
  }

let mk_addr_attr addr attr typ =
  let name = Format.asprintf "%s.%s" (addr_uniq_name addr) attr in
  mkv name (V_addr_attr (addr,attr)) ~mode:addr.addr_mode typ

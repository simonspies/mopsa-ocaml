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


(**
  Clang_parser_cache - Cache parsed AST to improve efficiency.

  AST are cached in marshalized files.
  We store the list of files used during parsing and check that they
  have not been modified before using the cache.
 *)



open Clang_AST
open Clang_parser



(** Output debug information. *)
let debug = ref false

                   

(** Version number. 
    This is checked when using the cache, and should be changed when
    the signature or the AST type change to invalidate the cache.
*)
let version = "Mopsa.C.AST/1"

       
(** Source file identification. *)
type file_signature =
    string   (* absolute filename *)
    * float  (* last modification time *)
    * int    (* length *)

        
(** Parse identification. *)
type signature =
    string                  (* parser command *)
    * target_options        (* target *)
    * string array          (* parser arguments *)
    * file_signature list   (* file names and timestamp *)


                     
(** Make filename absolute. *)
let file_abs f =
(*  if Filename.is_relative f then Filename.concat (Sys.getcwd ()) f
  else*) f

         
let get_file_signature (f:string) : file_signature =
  let f = file_abs f in
  let s = Unix.stat f in
  f, s.Unix.st_mtime, s.Unix.st_size

                        
let get_signature cmd tgt opts files : signature =
  cmd, tgt, opts, List.map get_file_signature files

                           
(** Checks that the signature is valid. *)    
let check_signature cmd tgt opts signature : bool =
  let cmd', tgt', opts', files' = signature in
  cmd = cmd' && tgt = tgt' && opts = opts' &&
  (List.for_all (fun s -> let f,_,_ = s in get_file_signature f = s) files')

    
(** File name of cache for a given source file name. *)
let file_cache_name file =
   file ^ ".mopsa_ast" 

    
(** Drop-in replacement to [Clang_parser.cache], but uses a cache on disk. *)
let parse cmd tgt file opts : parse_result =

  if !debug then Printf.printf "Clang_parser_cache: parsing %s\n" file;
      
  (* try to read cache *)
  let file_cache = file_cache_name file in
  if !debug then Printf.printf "Clang_parser_cache: looking for cache file %s\n" file_cache;
  let from_cache : parse_result option =
    try
      (* try cache file *)
      let cache = open_in file_cache in
      let v = Marshal.from_channel cache in
      if v <> version then (
        if !debug then Printf.printf "Clang_parser_cache: incompatible version\n";
        None
      )
      else
        let signature : signature = Marshal.from_channel cache in
        let check =
          try check_signature cmd tgt opts signature with _ -> false
        in
        let r = 
          if check then  (
            (* correct signature -> use cache *)
            if !debug then Printf.printf "Clang_parser_cache: found\n";
            Some (Marshal.from_channel cache)
          )
          else (
            (* incorrect signature *)
            if !debug then Printf.printf "Clang_parser_cache: incompatible signature\n";
            None
          )
        in
        close_in cache;
        r
    with _ ->
      (* cache file not available *)
      if !debug then Printf.printf "Clang_parser_cache: cache file not found\n";
      None 
  in
  
  match from_cache with
  | Some c -> c
  | None ->
     (* parse *)
     let r = Clang_parser.parse cmd tgt file opts in
     let files = List.sort compare r.parse_files in
     let files = List.filter (fun x -> x <> "<built-in>") files in
     let c = get_signature cmd tgt opts files in
     (* store signature & parse result *)
     if !debug then Printf.printf "Clang_parser_cache: storing cache to %s\n" file_cache;
    let cache = open_out file_cache in
     Marshal.to_channel cache version [];
     Marshal.to_channel cache c [];
     Marshal.to_channel cache r [];
     close_out cache;
     r

let parse cmd tgt enable_cache file opts =
  if enable_cache then parse cmd tgt file opts
  else Clang_parser.parse cmd tgt file opts
   
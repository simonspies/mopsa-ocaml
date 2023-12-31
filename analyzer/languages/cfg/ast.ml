(****************************************************************************)
(*                                                                          *)
(* This file is part of MOPSA, a Modular Open Platform for Static Analysis. *)
(*                                                                          *)
(* Copyright (C) 2018-2019 The MOPSA Project.                               *)
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

(** Extends the simple Universal language with Control Flow Graphs. *)

open Mopsa
open Universal.Ast

   
(*==========================================================================*)
                         (** {2 Graph types} *)
(*==========================================================================*)


module Loc =
struct    
  type t = Location.pos (* maybe add a unique tag? *)
  let compare = Location.compare_pos
  let hash = Hashtbl.hash
  let equal l1 l2 = Location.compare_pos l1 l2 = 0
  let print = Location.pp_position
end

module TagLoc =
struct    
  type t =
    { loc: Loc.t;
      tag: string; (* optional tag (may be "") *)
      id:  int;    (* unique among t with the same log ans tag *)
    }

  let compare (t1:t) (t2:t) : int =
    Compare.triple
      Loc.compare compare compare
      (t1.loc, t1.id, t1.tag) (t2.loc, t2.id, t2.tag)

  let hash : t -> int = Hashtbl.hash

  let equal (t1:t) (t2:t) : bool = compare t1 t2 = 0

  let print fmt (t:t) =
    match t.tag, t.id with
    | "",0 -> Loc.print fmt t.loc
    | "",_ -> Format.fprintf fmt "%a(%i)" Loc.print t.loc t.id
    | _,0  -> Format.fprintf fmt "%a(%s)" Loc.print t.loc t.tag
    | _    -> Format.fprintf fmt "%a(%s:%i)" Loc.print t.loc t.tag t.id

end

module Range =
struct
  type t = range
  let compare = compare_range
  let hash = Hashtbl.hash
  let equal l1 l2 = compare l1 l2 = 0
  let print = pp_range
end

module Port =
struct
  type t = token
  let compare = compare_token
  let hash = Hashtbl.hash
  let equal l1 l2 = compare l1 l2 = 0
  let print = pp_token
end

module LocSet = SetExt.Make(Loc)
module LocMap = MapExt.Make(Loc)
module LocHash = Hashtbl.Make(Loc)

module TagLocSet = SetExt.Make(TagLoc)
module TagLocMap = MapExt.Make(TagLoc)
module TagLocHash = Hashtbl.Make(TagLoc)

module RangeSet = SetExt.Make(Range)
module RangeMap = MapExt.Make(Range)
module RangeHash = Hashtbl.Make(Range)

                 
(** Build CFG module. *)
module CFG_Param =
struct
  module NodeId = TagLoc
  (** Identify nodes by source location. *)
                  
  module EdgeId = Range
  (** Identify edges by source range. *)

  module Port = Port
  (** Edge outputs are distinguished by flow tokens. *)
end
  
module CFG = Graph.Make(CFG_Param)

(** Edges are labelled with a statement.
    Nodes have no information in the graph structure.
    Abstract invariant information will be kept in maps separately
    from the CFG. 
    This way, CFG can be kept immutable.
 *)
type graph = (unit, stmt) CFG.graph
type node  = (unit, stmt) CFG.node
type edge  = (unit, stmt) CFG.edge
          
type node_id = TagLoc.t
type edge_id = Range.t
type port = token

type cfg =
  { cfg_graph: graph;
    mutable cfg_order: node GraphSig.nested_list list;
  }


(*==========================================================================*)
                       (** {2 Graph utilities} *)
(*==========================================================================*)

          
let mk_node_id ?(id=0) ?(tag="") (loc:Loc.t) : node_id =
  TagLoc.{ id; tag; loc; }

let fresh_node_id = LocHash.create 16 
  
let mk_fresh_node_id ?(tag="") (loc:Loc.t) : node_id =
  let id = try LocHash.find fresh_node_id loc with Not_found -> 0 in
  LocHash.replace fresh_node_id loc (id+1);
  mk_node_id ~id ~tag loc
(** Fresh node with some source location information. 
    NOTE: Do not mix mk_fresh_node_id and mk_node_id as it can break 
    uniqueness.
 *)  

let loc_anonymous : Loc.t =
  Location.mk_pos "<anonymous>" (-1) (-1)
  
let mk_anonymous_node_id ?(tag="") () : node_id =
  mk_fresh_node_id ~tag loc_anonymous
(** Fresh node without any source location information. *)  

let copy_node_id (n:node_id) : node_id =
  mk_fresh_node_id ~tag:n.TagLoc.tag n.TagLoc.loc
  
let node_loc (t:node_id) : Loc.t = t.TagLoc.loc

let pp_node_id = TagLoc.print
let pp_node_as_id fmt node = pp_node_id fmt (CFG.node_id node)

let compare_node_id = TagLoc.compare


               
let mk_edge_id ?(tag="") (range:range) : edge_id =
  if tag = "" then range else tag_range range "%s" tag

let fresh_edge_id = RangeHash.create 16
(* we use our own fresh range generator to keep an origin_range information *)
  
let mk_fresh_edge_id ?(tag="") (range:range) : edge_id =
  let id = try RangeHash.find fresh_edge_id range with Not_found -> 0 in
  RangeHash.replace fresh_edge_id range (id+1);
  let tag =
    if id = 0 then tag
    else if tag = "" then string_of_int id
    else tag^":"^(string_of_int id)
  in
  mk_edge_id ~tag range
(** Fresh range with possible some source range information. 
    NOTE: Do not mix mk_fresh_edge_id and mk_edge_id as it can break 
    uniqueness.
*)  

let mk_anonymous_edge_id ?(tag="") () : edge_id =
  mk_edge_id ~tag (mk_fresh_range ())
(** Fresh range without any source range information. *)

let edge_range (t:edge_id) : range = t

let pp_edge_id = Range.print
let pp_edge_as_id fmt edge = pp_edge_id fmt (CFG.edge_id edge)

let compare_edge_id = Range.compare
                
          
(*==========================================================================*)
                           (** {2 Flows} *)
(*==========================================================================*)


(** Associate a flow to each CFG node.
    We can store abstract information for the whole graph in a 
    single abstract state, using node flows.
    We also associate a flow to cache the post-image of each CFG edge.
 *)
type token +=
  | T_cfg_node of node_id
  | T_cfg_edge_post of edge_id * port
  | T_cfg_entry of port

(** Flow for true and false branch of tests. *)            
type token +=
   | T_true
   | T_false

   
(*==========================================================================*)
                           (** {2 Statements} *)
(*==========================================================================*)


type stmt_kind +=
   | S_cfg of cfg              
   | S_test of expr (** test nodes, with a true and a false branch *)
   | S_skip (** empty node *)

   
let mk_skip range =
  mk_stmt S_skip range

let mk_test e range =
  mk_stmt (S_test e) range

let mk_cfg cfg range =
  mk_stmt (S_cfg cfg) range




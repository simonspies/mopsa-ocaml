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

(* A general smashing abstraction for Python lists, (hopefully)
   irrelevant of the value/type domain *)

(* currently, lists are smashed into one variable abstracting all
   its elements. To avoid allocating a new variable each time
   (especially during loops), we allocate them only if there has
   been not other allocation at the same point. This is quite
   similar to the recency abstraction, and is probably not optimal
*)

(* TODO: add length for lists and position for iterator? *)

open Mopsa
open Ast
open Addr
open Universal.Ast

type addr_kind +=
  | A_py_list of var (* variable where the smashed elements are stored *)
  | A_py_iterator of string (* iterator kind (list_iterator, ...) *) * addr  (* addr of the container iterated on *)

let () =
  Format.(register_addr {
      print = (fun default fmt a ->
          match a with
          | A_py_list var -> fprintf fmt "list[%a]" pp_var var
          | A_py_iterator (s, addr) -> fprintf fmt "%s[%a]" s pp_addr addr
          | _ -> default fmt a);
      compare = (fun default a1 a2 ->
          match a1, a2 with
          | A_py_list v1, A_py_list v2 -> compare_var v1 v2
          | A_py_iterator (s1, a1), A_py_iterator (s2, a2) ->
            Compare.compose [
              (fun () -> Pervasives.compare s1 s2);
              (fun () -> compare_addr a1 a2);
            ]
          | _ -> default a1 a2);})


module Domain =
struct

  type _ domain += D_python_objects_list : unit domain

  let id = D_python_objects_list
  let name = "python.objects.list"
  let identify : type a. a domain -> (unit, a) eq option = function
    | D_python_objects_list -> Some Eq
    | _ -> None

  let debug fmt = Debug.debug ~channel:name fmt


  module VarInfo = struct type t = var let compare = compare_var let print = pp_var end
  module ListInfo = struct
    type t = Callstack.cs * range
    let compare (cs, r) (cs', r') =
      Compare.compose
        [
          (fun () -> Callstack.compare cs cs');
          (fun () -> compare_range r r')
        ]
    let print fmt (cs, r) =
      Format.fprintf fmt "(%a, %a)"
        Callstack.pp_call_stack cs
        pp_range r
  end

  module Equiv = Equiv.Make(ListInfo)(VarInfo)

  type ('a, _) Annotation.key +=
    | KListInfo : ('a, Equiv.t) Annotation.key

  let () =
    Annotation.(register_stateless_annot {
        eq = (let f: type a b. (a, b) key -> (Equiv.t, b) eq option =
                function
                | KListInfo -> Some Eq
                | _ -> None
              in
              f);
        print = (fun fmt m -> Format.fprintf fmt "List annots: @[%a@]" Equiv.print m);
      }) ();
    ()


  let fresh_smashed_var =  mkfresh (fun uid -> "$l*" ^ (string_of_int uid)) T_any

  let get_var_equiv (info: ListInfo.t) (e: Equiv.t) =
    try
      Equiv.find_l info e, e
    with Not_found ->
      let var = fresh_smashed_var () in
      let new_eq = Equiv.add (info, var) e in
      var, new_eq

  let get_var_flow (info: ListInfo.t) (f: 'a flow) : var * 'a flow =
    let a = Flow.get_annot KListInfo f in
    let var, a = get_var_equiv info a in
    var, Flow.set_annot KListInfo a f

  let exec_interface = {export = []; import = [Zone.Z_py_obj]}
  let eval_interface = {export = [Zone.Z_py, Zone.Z_py_obj]; import = [Zone.Z_py, Zone.Z_py_obj; Universal.Zone.Z_u_heap, Z_any]}

  let init (prog:program) man flow =
    Some (
      Flow.set_annot KListInfo Equiv.empty flow
    )


  let rec eval zones exp man flow =
    let range = erange exp in
    match ekind exp with
    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "list.__add__")}, _)}, [listl; listr], []) ->
      Utils.check_instances man flow range
        [listl ; listr]
        ["list"; "list"]
        (fun args flow ->
           let listl, listr = match args with [l; r] -> l, r | _ -> assert false in
           let elsl_var = match ekind listl with
             | E_py_object ({addr_kind = A_py_list a}, _) -> a
             | _ -> assert false in
           let elsr_var = match ekind listr with
             | E_py_object ({addr_kind = A_py_list a}, _) -> a
             | _ -> assert false in
           (* FIXME: try to reuse other functions? in the impl, list_concat (Objects/listobject.c) is not reusing anything *)
           (* First, allocate new addr for the list, and new addr for the list elements *)
           (* Then assign the el addr to both addresses above *)
           let els_res_var, flow = get_var_flow (Callstack.get flow, range) flow in
           let flow = List.fold_left (fun acc el ->
               man.exec ~zone:Zone.Z_py (mk_assign (mk_var ~mode:WEAK els_res_var range) el range) acc)
               flow [mk_var ~mode:WEAK elsl_var range;
                     mk_var ~mode:WEAK elsr_var range] in
           let addr_list = mk_alloc_addr (A_py_list els_res_var) range in
           man.eval ~zone:(Universal.Zone.Z_u_heap, Z_any) addr_list flow |>
           Eval.bind (fun list_addr flow ->
               let alist_addr = match ekind list_addr with | E_addr a -> a | _ -> assert false in
               Eval.singleton (mk_py_object (alist_addr, None) range) flow
             )
        )
      |> OptionExt.return

    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "list.__mul__")}, _)}, [list; int], [])
    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "list.__rmul__")}, _)}, [list; int], []) ->
      Utils.check_instances man flow range
        [list; int]
        ["list"; "int"]
        (fun args flow ->
           let list, int = match args with [l; r] -> l, r | _ -> assert false in
           let els_list = match ekind list with
             | E_py_object ({addr_kind = A_py_list a}, _) -> a
             | _ -> assert false in
           let els_var, flow = get_var_flow (Callstack.get flow, range) flow in
           let flow = man.exec ~zone:Zone.Z_py (mk_assign (mk_var ~mode:WEAK els_var range) (mk_var ~mode:WEAK els_list range) range) flow in
           let addr_list = mk_alloc_addr (A_py_list els_var) range in
           man.eval ~zone:(Universal.Zone.Z_u_heap, Z_any) addr_list flow |>
           Eval.bind (fun eaddr_list flow ->
               let addr_list = match ekind eaddr_list with
                 | E_addr a -> a
                 | _ -> assert false in
               Eval.singleton (mk_py_object (addr_list, None) range) flow
             )
        )
      |> OptionExt.return

    | E_py_list ls ->
      debug "Skipping list.__new__, list.__init__ for now@\n";
      (* TODO: handle empty lists *)
      let els_var, flow = get_var_flow (Callstack.get flow, range) flow in
      let flow = List.fold_left (fun acc el ->
          man.exec ~zone:Zone.Z_py (mk_assign (mk_var ~mode:WEAK els_var range) el range) acc) flow ls in
      let addr_list = mk_alloc_addr (A_py_list els_var) range in
      man.eval ~zone:(Universal.Zone.Z_u_heap, Z_any) addr_list flow |>
      Eval.bind (fun eaddr_list flow ->
          let addr_list = match ekind eaddr_list with
            | E_addr a -> a
            | _ -> assert false in
          Eval.singleton (mk_py_object (addr_list, None) range) flow
        )
      |> OptionExt.return


    | E_py_object ({addr_kind = A_py_list _}, e) ->
      Eval.singleton exp flow |> OptionExt.return

    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "list.append")}, _)}, [list; element], []) ->
      Utils.check_instances man flow range
        [list; element]
        ["list"]
        (fun args flow ->
           let list, element = match args with | [l; e] -> l, e | _ -> assert false in
           debug "list: %a@\n" pp_expr list;
           let var_els = match ekind list with
             | E_py_object ({addr_kind = A_py_list a}, _) -> a
             | _ -> assert false in
           man.exec (mk_assign (mk_var var_els ~mode:WEAK range) element range) flow |>
           man.eval (mk_py_none range))
      |> OptionExt.return

    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "list.insert")}, _)}, [list; index; element], []) ->
      Utils.check_instances man flow range
        [list; index; element]
        ["list"; "int"]
        (fun args flow ->
           let list, index, element = match args with | [l; i; e] -> l, i, e | _ -> assert false in
           let var_els = match ekind list with
             | E_py_object ({addr_kind = A_py_list a}, _) -> a
             | _ -> assert false in
           man.exec (mk_assign (mk_var var_els ~mode:WEAK range) element range) flow |>
           man.eval (mk_py_none range))
      |> OptionExt.return

    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "list.__init__")}, _)}, [list; sndlist], [])
    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "list.extend")}, _)}, [list; sndlist], []) ->
      Utils.check_instances man flow range
        [list; sndlist]
        ["list"; "list"]
        (fun eargs flow ->
           let list, sndlist = match eargs with [l; s] -> l, s | _ -> assert false in
           let var_els = match ekind list with
             | E_py_object ({addr_kind = A_py_list a}, _) -> a
             | _ -> assert false in
           let var_sndels = match ekind sndlist with
             | E_py_object ({addr_kind = A_py_list a}, _) -> a
             | _ -> assert false in
           man.exec (mk_assign (mk_var var_els ~mode:WEAK range) (mk_var var_sndels ~mode:WEAK range) range) flow |>
           man.eval (mk_py_none range)
        )
      |> OptionExt.return

    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "list.count")}, _)}, [list; element], []) ->
      (* TODO: something smarter depending on the occurence of \gamma(element) in \gamma(list elements) ? *)
      Utils.check_instances man flow range
        [list; element]
        ["list"]
        (fun _ flow -> man.eval (mk_py_top T_int range) flow)
      |> OptionExt.return

    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "list.index")}, _)}, [list; element], []) ->
      Utils.check_instances man flow range
        [list; element]
        ["list"]
        (fun args flow ->
           let eval_verror_f = man.exec (Utils.mk_builtin_raise "ValueError" range) flow in
           let flow = Flow.copy_annot eval_verror_f flow in
           let eval_verror = Eval.empty_singleton eval_verror_f in
           let eval_res = man.eval (mk_py_top T_int range) flow in
           Eval.join_list (eval_res :: eval_verror :: []))
      |> OptionExt.return


    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "list.pop")}, _)}, [list], []) ->
      Utils.check_instances man flow range
        [list]
        ["list"]
        (fun args flow ->
           let list = match args with [l] -> l | _ -> assert false in
           let var_els = match ekind list with
             | E_py_object ({addr_kind = A_py_list a}, _) -> a
             | _ -> assert false in
           let eval_indexerror = man.exec (Utils.mk_builtin_raise "IndexError" range) flow
                                 |> Eval.empty_singleton in
           let eval_el = man.eval (mk_var ~mode:WEAK var_els range) flow in
           Eval.join_list (Eval.copy_annot eval_indexerror eval_el :: eval_indexerror :: [])
        )
      |> OptionExt.return


    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "list.remove")}, _)}, [list; element], []) ->
      Utils.check_instances man flow range
        [list; element]
        ["list"]
        (fun args flow ->
           let eval_verror_f = man.exec (Utils.mk_builtin_raise "ValueError" range) flow in
           let eval_verror = Eval.empty_singleton eval_verror_f in
           let flow = Flow.copy_annot eval_verror_f flow in
           let eval_none = man.eval (mk_py_none range) flow in
           Eval.join_list (eval_none :: eval_verror :: [])
        )
      |> OptionExt.return


    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "list.reverse")}, _)}, [list], [])
    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "list.sort")}, _)}, [list], []) ->
      Utils.check_instances man flow range
        [list]
        ["list"]
        (fun _ flow -> man.eval (mk_py_none range) flow)
      |> OptionExt.return


    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "list.__getitem__")}, _)}, [list; index], []) ->
      Utils.check_instances man flow range
        [list; index]
        ["list"; "int"]
        (fun args flow ->
           let list, index = match args with | [list; index] -> list, index | _ -> assert false in
           let var_els = match ekind list with
             | E_py_object ({addr_kind = A_py_list a}, _) -> a
             | _ -> assert false in
           let indexerror_f = man.exec (Utils.mk_builtin_raise "IndexError" range) flow in
           let indexerror = Eval.empty_singleton indexerror_f in
           let flow = Flow.copy_annot indexerror_f flow in
           let evals = man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj) (mk_var var_els range) flow in
           Eval.join_list (evals :: Eval.copy_annot evals indexerror :: [])
        )
      |> OptionExt.return


    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "list.__setitem__")}, _)}, [list; index; value], []) ->
      Utils.check_instances man flow range
        [list; index; value]
        ["list"; "int"]
        (fun args flow ->
           let list, index, value = match args with | [l; i; v] -> l, i, v | _ -> assert false in
           let var_els = match ekind list with
             | E_py_object ({addr_kind = A_py_list a}, _) -> a
             | _ -> assert false in
           let indexerror_f = man.exec (Utils.mk_builtin_raise "IndexError" range) flow in
           let flow = Flow.copy_annot indexerror_f flow in

           let assignment_f = man.exec (mk_assign (mk_var ~mode:WEAK var_els range) value range) flow in
           let indexerror_f = Flow.copy_annot assignment_f indexerror_f in

           let assignment = man.eval (mk_py_none range) assignment_f in
           let indexerror = Eval.empty_singleton indexerror_f in
           Eval.join_list (assignment :: (Eval.copy_annot assignment indexerror) ::[])
        )
      |> OptionExt.return

    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "list.__iter__")}, _)}, [list], []) ->
      Utils.check_instances man flow range
        [list]
        ["list"]
        (fun args flow ->
           let list = match args with | [l] -> l | _ -> assert false in
           let list_addr = match ekind list with
             | E_py_object ({addr_kind = A_py_list _} as a, _) -> a
             | _ -> assert false in
           let a = mk_alloc_addr (A_py_iterator ("list_iterator", list_addr)) range in
           man.eval ~zone:(Universal.Zone.Z_u_heap, Z_any) a flow |>
           Eval.bind (fun eaddr_it flow ->
               let addr_it = match ekind eaddr_it with | E_addr a -> a | _ -> assert false in
               Eval.singleton (mk_py_object (addr_it, None) range) flow
             )
        )
      |> OptionExt.return

    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "list_iterator.__next__")}, _)}, [iterator], []) ->
      (* todo: checks ? *)
      man.eval  ~zone:(Zone.Z_py, Zone.Z_py_obj) iterator flow |>
      Eval.bind (fun iterator flow ->
          let list_addr = match ekind iterator with
            | E_py_object ({addr_kind = A_py_iterator (s, a)}, _) when s = "list_iterator" -> a
            | _ -> assert false in
          let var_els = match akind list_addr with
            | A_py_list a -> a
            | _ -> assert false in
          let els = man.eval (mk_var var_els ~mode:WEAK range) flow in
          let stopiteration = man.exec (Utils.mk_builtin_raise "StopIteration" range) flow |> Eval.empty_singleton in
          Eval.join_list (Eval.copy_annot stopiteration els::stopiteration::[])
        )
      |> OptionExt.return

    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "list_iterator.__iter__")}, _)}, [iterator], []) ->
      (* todo: checks ? *)
      man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj) iterator flow |> OptionExt.return

    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "list.__len__")}, _)}, [list], []) ->
      Utils.check_instances man flow range
        [list]
        ["list"]
        (fun args flow ->
           man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj) (mk_py_top T_int range) flow
        )
      |> OptionExt.return


    | _ -> None


  let exec zone stmt man flow = None

  let ask _ _ _ = None
end

let () =
  Framework.Domains.Stateless.register_domain (module Domain)

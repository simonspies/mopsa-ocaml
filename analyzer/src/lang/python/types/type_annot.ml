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

(** Definition of python functions annotations as well as polymorphism *)

open Mopsa
open Sig.Domain.Intermediate
open Ast
open Addr
open Universal.Ast


module Domain =
struct

  module ESet = Framework.Lattices.Powerset.Make(struct type t = expr let compare = compare_expr let print = pp_expr end)

  module TVMap = Framework.Lattices.Partial_map.Make
      (struct type t = string let compare = Pervasives.compare let print = Format.pp_print_string end)
      (ESet)

  include TVMap
  let widen ctx = widen
  let print fmt m =
    Format.fprintf fmt "TypeVar annotations: @[%a@]@\n" TVMap.print m

  include GenDomainId(struct
      type nonrec t = t
      let name = "python.types.type_annot"
    end)

  let interface = {
    iexec = {provides = [Zone.Z_py]; uses = []};
    ieval = {provides = [Zone.Z_py, Zone.Z_py_obj]; uses = [Zone.Z_py, Zone.Z_py_obj]}
  }

  let init prog man flow =
    set_env T_cur empty man flow

  let collect_typevars ?(base=TVMap.empty) signature =
    List.fold_left (fun acc oty ->
        Visitor.fold_expr
          (fun acc expr -> match ekind expr with
             | E_py_call ({ekind = E_var ({vkind = V_uniq ("TypeVar", _)}, _)}, {ekind = E_constant (C_string s)}::types, []) ->
               let set = if types = [] then ESet.top else ESet.of_list types in
               debug "in %a, set = %a" pp_expr expr ESet.print set;
               begin match TVMap.find_opt s acc with
                 | None -> Keep (TVMap.add s set acc)
                 | Some set2 ->
                   if ESet.equal set set2 then Keep acc
                   else Exceptions.panic_at (erange expr) "conflict for typevar %s, sets %a and %a differ" s ESet.print set ESet.print set2
               end
             | _ ->
               VisitParts acc)
          (fun acc stmt -> VisitParts acc)
          acc (Option.none_to_exn oty)) base signature.py_funcs_types_in

  let eval zs exp man flow =
    let range = erange exp in
    match ekind exp with
    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function(F_annot pyannot)}, _)}, args, kwargs) ->
      (* FIXME: kwargs *)
      let sigs = List.filter (fun sign -> List.length args = List.length sign.py_funcs_types_in) pyannot.py_funca_sig in
      let filter_sig in_types flow =
        List.fold_left2 (fun acc arg annot ->
            (* woops if self of method *)
            man.exec (mk_stmt (S_py_check_annot (arg, (Option.none_to_exn annot))) range) acc
          )  flow args in_types in
      let apply_sig flow signature =
        debug "apply_sig %a" pp_py_func_sig signature;
        let cur = get_env T_cur man flow in
        let new_typevars = collect_typevars signature in
        debug "new_typevars: %a" TVMap.print new_typevars;
        let ncur = TVMap.fold2o
            TVMap.add
            TVMap.add
            (fun s tycur tynew acc -> assert false)
            cur new_typevars TVMap.empty in
        let flow = set_env T_cur ncur man flow in
        let flow = filter_sig signature.py_funcs_types_in flow in
        man.exec (mk_add_var pyannot.py_funca_ret_var range) flow |>
        man.exec (mk_stmt (S_py_annot (mk_var pyannot.py_funca_ret_var range,
                                       mk_expr (E_py_annot (Option.none_to_exn signature.py_funcs_type_out)) range))
                    range) , new_typevars
      in
      Eval.join_list ~empty:(
        fun () ->
          let () = Format.fprintf Format.str_formatter "%a does not match any signature provided in the stubs" pp_var pyannot.py_funca_var in
          man.exec (Utils.mk_builtin_raise_msg "TypeError" (Format.flush_str_formatter ()) range) flow |> Eval.empty_singleton)
        (List.fold_left (fun acc sign ->
             let nflow, ntypevars = apply_sig flow sign in
             debug "nflow after apply_sig = %a@\n" (Flow.print man.lattice.print) nflow;
             let cur = get_env T_cur man nflow in
             let ncur = TVMap.filter (fun tyvar _ -> not @@ TVMap.mem tyvar ntypevars) cur in
             let nflow = set_env T_cur ncur man nflow in
             debug "nflow = %a@\n" (Flow.print man.lattice.print) nflow;
             if Flow.is_bottom man.lattice nflow then acc
             else
               (Eval.singleton (mk_var pyannot.py_funca_ret_var range) nflow ~cleaners:([mk_remove_var pyannot.py_funca_ret_var range]) |> Eval.bind (man.eval)) :: acc
           ) [] sigs)
      |> Option.return

    | E_py_annot e ->
      begin match ekind e with
        | E_var (v, mode) when is_builtin_name @@ get_orig_vname v ->
          let name = get_orig_vname v in
          begin match name with
          | "int" ->
            (fun s -> Eval.singleton (mk_py_object (s (), None) range) flow) Addr_env.addr_integers
          | "float" ->
            (fun s -> Eval.singleton (mk_py_object (s (), None) range) flow) Addr_env.addr_float
          | "NotImplementedType" ->
            (fun s -> Eval.singleton (mk_py_object (s (), None) range) flow) Addr_env.addr_notimplemented
          | "NoneType" ->
            (fun s -> Eval.singleton (mk_py_object (s (), None) range) flow) Addr_env.addr_none
          | _ ->
            Addr_env.Domain.allocate_builtin ~mode:WEAK man range flow (get_orig_vname v) (Some e)
          end
          |> Option.return

        | E_var (v, mode) ->
          debug "E_annot %s" v.vname;
          begin try
              let e = Hashtbl.find type_aliases v in
              debug "found type alias, replacing %a by %a" pp_var v pp_expr e;
              man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj) (mk_expr (E_py_annot e) range) flow |> Option.return
            with Not_found ->
              man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj) (mk_py_call e [] range) flow |> Option.return
          end

        | E_py_attribute ({ekind = E_var (v, _)}, s) ->
          debug "searching %a in the type aliases..." pp_expr e;
          begin
            try
              (* FIXME ouch, not found in man.eval would also get caught... *)
              (* FIXME: this also means that if a.pyi defines alias b and b.pyi too, we'll encounter some trouble *)
              let r = find_type_alias_by_name s in
              man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj) (mk_expr (E_py_annot r) range) flow |> Option.return
            with Not_found ->
              debug "not found, trying usual evaluation";
              man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj) e flow |> Option.return
          end

        | E_py_index_subscript ({ekind = E_py_object _} as e1, e2) ->
          warn_at range "E_py_annot subscript e1=%a e2=%a now in the wild" pp_expr e1 pp_expr e2;
          None

        | E_py_index_subscript (e1, e2) ->
          man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj) e1 flow |>
          bind_some (fun e1 flow ->
              warn_at range "trasnlated to e1=%a e2=%a" pp_expr e1 pp_expr e2;
              man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj) {exp with ekind = E_py_annot {e with ekind = E_py_index_subscript(e1, e2)}} flow
            )
          |> Option.return

        | E_py_call ({ekind = E_var ({vkind = V_uniq ("TypeVar", _)}, _)}, {ekind = E_constant (C_string s)}::[], []) ->
          Exceptions.panic_at range "generic typevar annot"

        | E_py_call ({ekind = E_var ({vkind = V_uniq ("TypeVar", _)}, _)}, {ekind = E_constant (C_string s)}::types, []) ->
          let cur = get_env T_cur man flow in
          let tycur = TVMap.find s cur in
          debug "tycur = %a@\n" ESet.print tycur;
          begin match ESet.cardinal tycur with
          | 0 ->
            Flow.bottom (Flow.get_ctx flow) (Flow.get_alarms flow) |>
            Eval.empty_singleton
          | _ ->
            assert (ESet.cardinal tycur = 1);
            let ty = ESet.choose tycur in
            man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj) {exp with ekind = E_py_annot ty} flow
          end |> Option.return

        | _ ->
          Exceptions.panic_at range "Unsupported type annotation %a@\n" pp_expr e
      end


    | _ -> None

  let exec zone stmt man flow =
    let range = srange stmt in
    match skind stmt with
    | S_py_check_annot (e, annot) ->
      begin match ekind annot with
        | E_var (v, mode) when is_builtin_name @@ get_orig_vname v ->
          man.exec (mk_assume (mk_py_isinstance_builtin e (get_orig_vname v) range) range) flow
          |> Post.return
          |> Option.return

        | E_py_index_subscript ({ekind = E_py_object _} as e1, e2) ->
          warn_at range "S_py_check_annot subscript e1=%a e2=%a now in the wild" pp_expr e1 pp_expr e2;
          None

        | E_py_index_subscript (e1, e2) ->
          man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj) e1 flow |>
          bind_some (fun e1 flow ->
              warn_at range "translated to e1=%a e2=%a" pp_expr e1 pp_expr e2;
              man.exec ~zone:Zone.Z_py_obj ({stmt with skind = S_py_check_annot (e, {annot with ekind = E_py_index_subscript (e1, e2)})}) flow |> Post.return
            )
          |> Option.return

        | E_py_call ({ekind = E_var ({vkind = V_uniq ("TypeVar", _)}, _)}, {ekind = E_constant (C_string s)}::[], []) ->
          Exceptions.panic_at range "Spycheckannot typevar"

        | E_py_call ({ekind = E_var ({vkind = V_uniq ("TypeVar", _)}, _)}, {ekind = E_constant (C_string s)}::types, []) ->
          (* filtrer domaine local et relancer S_py_check annot sur les types *)
          let flows = List.fold_left (fun acc typ ->
              let cur = get_env T_cur man flow in
              let flow = set_env T_cur (TVMap.add s (ESet.singleton typ) cur) man flow in
              (man.exec {stmt with skind = S_py_check_annot (e, typ)} flow |> Post.return) :: acc
            ) [] types in
          Result.join_list ~empty:(fun () -> Flow.bottom (Flow.get_ctx flow) (Flow.get_alarms flow) |> Post.return) flows |> Option.return


        | _ -> Exceptions.panic_at range "S_py_check_annot: %a not supported" pp_expr annot
      end

    | _ -> None

  let ask _ _ _ = None
  let refine channel man flow = Channel.return flow
  let merge _ _ _ = assert false

end

let () =
  Framework.Core.Sig.Domain.Intermediate.register_domain (module Domain)

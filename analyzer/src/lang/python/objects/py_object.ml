(****************************************************************************)
(*                                                                          *)
(* This file is part of MOPSA, a Modular Open Platform for Static Analysis. *)
(*                                                                          *)
(* Copyright (C) 2019 The MOPSA Project.                                    *)
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

(** An environment is a total map from variables to addresses. *)

open Mopsa
open Sig.Domain.Intermediate
open Ast
open Addr
open Universal.Ast
open Alarms


module Domain =
struct

  include Framework.Core.Id.GenStatelessDomainId(struct let name = "python.objects.object" end)

  let interface = {
    iexec = { provides = []; uses = []; };
    ieval = { provides = [Zone.Z_py, Zone.Z_py_obj]; uses = [Zone.Z_py, Zone.Z_py_obj]; }
  }

  let alarms = []

  let init prog man flow = flow

  let exec _ _ _ _ = None

  let rec search_mro man attr ~cls_found ~nothing_found range mro flow =
    match mro with
    | [] -> nothing_found flow
    | cls :: tl ->
      assume (mk_expr (E_py_ll_hasattr(mk_py_object cls range, attr)) range)
        man flow
        ~fthen:(cls_found cls)
        ~felse:(search_mro man attr ~cls_found ~nothing_found range tl)

  let rec eval zs exp man flow =
    let range = erange exp in
    match ekind exp with
    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "object.__new__")}, _)}, args, []) ->
      bind_list args (man.eval  ~zone:(Zone.Z_py, Zone.Z_py_obj)) flow |>
      bind_some (fun args flow ->
          match args with
          | [] ->
            debug "Error during creation of a new instance@\n";
            man.exec (Utils.mk_builtin_raise "TypeError" range) flow |> Eval.empty_singleton
          | cls :: tl ->
            let c = fst @@ object_of_expr cls in
            man.eval  ~zone:(Universal.Zone.Z_u_heap, Z_any) (mk_alloc_addr (A_py_instance c) range) flow |>
            Eval.bind (fun eaddr flow ->
                let addr = match ekind eaddr with
                  | E_addr a -> a
                  | _ -> assert false in
                man.exec ~zone:Zone.Z_py_obj (mk_add eaddr range) flow |>
                Eval.singleton (mk_py_object (addr, None) range)
              )
        )
      |> Option.return

    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "object.__init__")}, _)}, args, []) ->
      man.eval  ~zone:(Zone.Z_py, Zone.Z_py_obj) (mk_py_none range) flow |> Option.return

    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "type.__getattribute__")}, _)}, [ptype; attribute], []) ->
      man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj) (mk_py_type ptype range) flow |>
      Eval.bind (fun metatype flow ->
          let lookintype o_meta_attribute o_meta_get flow =
            man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj) ptype flow |>
            Eval.bind (fun ptype flow ->
                let mro_ptype = mro (object_of_expr ptype) in
                search_mro man attribute
                  ~cls_found:(fun cls flow ->
                      man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj) (mk_expr (E_py_ll_getattr (mk_py_object cls range, attribute)) range) flow |>
                      Eval.bind (fun attribute flow ->
                          assume (mk_py_hasattr attribute "__get__" range)
                            man flow
                            ~fthen:(fun flow ->
                              Soundness.warn_at range "FIXME: a NULL argument has been replaced with a None during evaluation";
                              man.eval
                                (mk_py_call
                                   (mk_expr (E_py_ll_getattr(attribute, mk_string "__get__" range)) range)
                                   [mk_py_none range; ptype]
                                   range
                                ) flow
                            )
                            ~felse:(Eval.singleton attribute)
                        )
                    )
                  ~nothing_found:(fun flow ->
                      match o_meta_get, o_meta_attribute with
                      | Some meta_get, _ ->
                        man.eval (mk_py_call meta_get [ptype; metatype] range) flow
                      | None, Some meta_attribute ->
                        Eval.singleton meta_attribute flow
                      | None, None ->
                        Format.fprintf Format.str_formatter "type object '%a' has no attribute '%s'" pp_expr ptype (match ekind attribute with | E_constant (C_string attr) -> attr | _ -> assert false);
                        man.exec (Utils.mk_builtin_raise_msg "AttributeError" (Format.flush_str_formatter ()) range) flow |>
                        Eval.empty_singleton
                    )
                  range mro_ptype flow
              )
          in

          let mro_metatype = mro (object_of_expr metatype) in
          search_mro man attribute
            ~cls_found:(fun cls flow ->
                man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj) (mk_expr (E_py_ll_getattr (mk_py_object cls range, attribute)) range) flow |>
                Eval.bind (fun obj' flow ->
                    assume
                      (mk_py_hasattr obj' "__get__" range)
                      man flow
                      ~fthen:(fun flow ->
                          man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj) (mk_expr (E_py_ll_getattr(obj', mk_string "__get__" range)) range) flow |>
                          Eval.bind (fun meta_get flow ->
                              assume
                                (mk_py_hasattr obj' "__set__" range)
                                man flow
                                ~fthen:(man.eval (mk_py_call meta_get [ptype; metatype] range))
                                ~felse:(lookintype (Some obj') (Some meta_get))
                            )
                        )
                      ~felse:(lookintype (Some obj') None)
                  )
              )
            ~nothing_found:(lookintype None None)
            range mro_metatype flow

        )
      |> Option.return


    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "object.__getattribute__")}, _)}, [instance; attribute], []) ->
      man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj) (mk_py_type instance range) flow |>
      Eval.bind (fun class_of_exp flow ->
          let mro = mro (object_of_expr class_of_exp) in
          debug "mro of %a: %a" pp_expr class_of_exp (Format.pp_print_list (fun fmt (a, _) -> pp_addr fmt a)) mro;
          search_mro man attribute
            ~cls_found:(fun cls flow ->
                man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj) (mk_expr (E_py_ll_getattr (mk_py_object cls range, attribute)) range) flow |>
                Eval.bind (fun obj' flow ->
                    assume
                      (mk_binop (mk_py_hasattr obj' "__get__" range) O_py_and (mk_py_hasattr obj' "__set__" range) range)
                      (* FIXMES:
                         1) it's __set__ or __del__
                         2) also,  GenericGetAttrWithDict uses low level field accesses (like descr->ob_type->tp_descr_get), but these fields get inherited during type creation according to the doc, so even a low-level access actually is something more complicated. The clean fix would be to handle this at class creation for special fields.
                      *)
                      man flow
                      ~fthen:(fun flow ->
                          (* FIXME: I guess it's E_py_ll_getattr rather than mk_py_attr *)
                          man.eval (mk_py_call (mk_py_attr obj' "__get__" range) [instance; class_of_exp] range) flow
                        )
                      ~felse:(fun flow ->
                          assume
                            (mk_expr (E_py_ll_hasattr (instance, attribute)) range)
                            man flow
                            ~fthen:(man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj) (mk_expr (E_py_ll_getattr(instance, attribute)) range))
                            ~felse:(fun flow ->
                                assume
                                  (mk_py_isinstance_builtin obj' "function" range)
                                  man flow
                                  ~fthen:(fun flow ->
                                      debug "obj'=%a; exp=%a@\n" pp_expr obj' pp_expr instance;
                                      eval_alloc man (A_py_method (object_of_expr obj', instance)) range flow |>
                                      bind_some (fun addr flow ->
                                          let obj = (addr, None) in
                                          Eval.singleton (mk_py_object obj range) flow)
                                    )
                                  ~felse:(Eval.singleton obj')
                              )
                        )
                  )
              )
            ~nothing_found:(fun flow ->
                assume
                  (mk_expr (E_py_ll_hasattr (instance, attribute)) range)
                  man flow
                  ~fthen:(man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj) (mk_expr (E_py_ll_getattr(instance, attribute)) range))
                  ~felse:(fun flow ->
                      debug "No attribute found for %a@\n" pp_expr instance;
                      Format.fprintf Format.str_formatter "'%a' object has no attribute '%s'" pp_expr instance (match ekind attribute with | E_constant (C_string attr) -> attr | _ -> assert false);
                      man.exec (Utils.mk_builtin_raise_msg "AttributeError" (Format.flush_str_formatter ()) range) flow |>
                      Eval.empty_singleton)
              )
            range mro flow
        )
      |> Option.return

    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "type.__setattr__")}, _)}, [lval; attr; rval], [])
    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "object.__setattr__")}, _)}, [lval; attr; rval], []) ->
      man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj) (mk_py_type lval range) flow |>
      Eval.bind (fun class_of_lval flow ->
          let mro = mro (object_of_expr class_of_lval) in
          search_mro man attr
            ~cls_found:(fun cls flow ->
                man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj) (mk_expr (E_py_ll_getattr (mk_py_object cls range, attr)) range) flow |>
                Eval.bind (fun obj' flow ->
                    assume (mk_py_hasattr obj' "__set__" range)
                      man flow
                      ~fthen:(fun flow ->
                          man.eval (mk_py_call (mk_py_attr obj' "__set__" range) [lval; rval] range) flow
                        )
                      ~felse:(
                        man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj) (mk_expr (E_py_ll_setattr (lval, attr, Some rval)) range)
                      )
                  )
              )
            ~nothing_found:(man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj) (mk_expr (E_py_ll_setattr (lval, attr, Some rval)) range))
            range mro flow
        )
      |> Option.return

    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "type.__delattr__")}, _)}, [lval; attr], [])
    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "object.__delattr__")}, _)}, [lval; attr], []) ->
      man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj) (mk_py_type lval range) flow |>
      Eval.bind (fun class_of_lval flow ->
          let mro = mro (object_of_expr class_of_lval) in
          search_mro man attr
            ~cls_found:(fun cls flow ->
                man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj) (mk_expr (E_py_ll_getattr (mk_py_object cls range, attr)) range) flow |>
                Eval.bind (fun obj' flow ->
                    assume (mk_py_hasattr obj' "__delete__" range)
                      man flow
                      ~fthen:(fun flow ->
                          man.eval (mk_py_call (mk_py_attr obj' "__delete__" range) [lval] range) flow
                        )
                      ~felse:(
                        man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj) (mk_expr (E_py_ll_setattr (lval, attr, None)) range)
                      )
                  )
              )
            ~nothing_found:(man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj) (mk_expr (E_py_ll_setattr (lval, attr, None)) range))
            range mro flow
        )
      |> Option.return

    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "object.__init_subclass__")}, _)}, cls::args, []) ->
      man.eval ~zone:(Zone.Z_py, Zone.Z_py_obj) (mk_py_none range) flow |> Option.return


    | _ -> None

  let ask _ _ _ = None

  let refine channel man flow = Channel.return flow
end


let () = Framework.Core.Sig.Domain.Stateless.register_domain (module Domain);

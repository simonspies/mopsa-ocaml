(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(** Data model for attribute access. *)

open Framework.Essentials
open Universal.Ast
open Ast
open Addr


type expr_kind +=
   (** low-level hasattribute working at the object level only *)
   | E_py_ll_hasattr of expr (** object *) * string (** attribute name *)
   (** low-level attribute access working at the object level only *)
   | E_py_ll_getattr of expr (** object *) * string (** attribute name *)

let () =
  register_pp_expr (fun default fmt exp ->
      match ekind exp with
      | E_py_ll_hasattr (e, attr) -> Format.fprintf fmt "E_py_ll_hasattr(%a, %s)" pp_expr e attr
      | E_py_ll_getattr (e, attr) -> Format.fprintf fmt "E_py_ll_getattr(%a, %s)" pp_expr e attr
      | _ -> default fmt exp)


module Domain =
  struct

    type _ domain += D_python_data_model_attribute : unit domain

    let id = D_python_data_model_attribute
    let name = "python.data_model.attribute"
    let identify : type a. a domain -> (unit, a) eq option = function
      | D_python_data_model_attribute -> Some Eq
      | _ -> None

    let debug fmt = Debug.debug ~channel:name fmt

    let exec_interface = {export = []; import = []}
    let eval_interface = {export = [any_zone, any_zone]; import = []}

    let init _ _ flow = Some flow

    let eval zs exp man flow =
      let range = erange exp in
      match ekind exp with
      (* Special attributes *)
      | E_py_attribute(obj, ("__dict__" as attr))
        | E_py_attribute(obj, ("__class__" as attr))
        | E_py_attribute(obj, ("__bases__" as attr))
        | E_py_attribute(obj, ("__name__" as attr))
        | E_py_attribute(obj, ("__qualname__" as attr))
        | E_py_attribute(obj, ("__mro__" as attr))
        | E_py_attribute(obj, ("mro" as attr))
        | E_py_attribute(obj, ("__subclass__" as attr)) ->
         Framework.Exceptions.panic_at range "Access to special attribute %s not supported" attr

      (* Other attributes *)
      | E_py_attribute (e, attr) ->
         debug "%a@\n" pp_expr exp;
         man.eval e flow |>
           Eval.bind (fun exp flow ->
               Eval.assume (mk_expr (E_py_ll_hasattr (exp, attr)) range)
                 ~fthen:(fun flow ->
                   debug "instance attribute found locally@\n";
                   man.eval (mk_expr (E_py_ll_getattr(exp, attr)) range) flow
                 )
                 ~felse:(fun flow ->
                   (* now we need to search the attribute in the MRO *)
                   let rec search_mro flow (mro:Ast.py_object list) = match mro with
                     | [] ->
                        let flow = man.exec (Utils.mk_builtin_raise "AttributeError" range) flow in
                        Eval.empty_singleton flow
                     | cls :: tl ->
                        Eval.assume
                          (mk_expr (E_py_ll_hasattr (mk_py_object cls range, attr)) range)
                          ~fthen:(fun flow ->
                            (* FIXME: disjunction between instances an non-instances *)
                            man.eval (mk_py_object_attr cls attr range) flow |>
                              Eval.bind (fun obj' flow ->
                                  Eval.assume
                                    (mk_py_call (mk_py_object (Addr.find_builtin "isinstance") range) [obj'; mk_py_object (Addr.find_builtin "function") range] range)
                                    ~fthen:(fun flow ->
                                      Debug.fail "todo@\n";
                                      (* let exp = mk_expr (E_alloc_addr (A_py_method(object_of_expr obj', object_of_expr exp))) range in *)
                                      Eval.singleton exp flow)
                                    ~felse:(fun flow ->
                                      (* FIXME? *)
                                      let exp = mk_attribute_var cls attr range in
                                      Eval.singleton exp flow)
                                    man flow
                                )
                          )
                          ~felse:(fun flow -> search_mro flow tl)
                          man flow
                   in
                   let mro = Addr.mro (object_of_expr exp) in
                   search_mro flow mro
                 )
                 man flow
             )
         |> OptionExt.return

      | _ -> None

    let exec _ _ _ _ = None
    let ask _ _ _ = None
  end


let () = Framework.Domains.Stateless.register_domain (module Domain)

(* TODO: move S_assume and eval of not into t_bool domain? *)
open Mopsa
open Ast
open Addr
open Data_model.Attribute
open MapExt
open Objects.Function
open Universal.Ast


module Domain =
struct

  type polytype =
    | Bot | Top

    | Class of class_address * py_object list (* class * mro *)
    | Function of function_address
    | Method of function_address * addr
    | Module of module_address

    | Instance of pytypeinst

    (* | Union of addr list *)
    | Typevar of int

  and pytypeinst = {classn: polytype (* TODO: polytype or addr? *); uattrs: addr StringMap.t; oattrs: addr StringMap.t}

  type addr_kind +=
    | A_py_instance (*of  class_address*)

  let () =
    Format.(register_addr {
        print = (fun default fmt a ->
            match a with
            | A_py_instance (*c -> fprintf fmt "Inst{%a}" pp_addr_kind (A_py_class (c, []))*)
              -> fprintf fmt "inst"
            | _ -> default fmt a);
        compare = (fun default a1 a2 ->
            match a1, a2 with
            (* | A_py_instance c1, A_py_instance c2 ->
             *   compare_addr_kind (A_py_class (c1, [])) (A_py_class (c2, [])) *)
            | _ -> default a1 a2);})

  let rec compare_polytype t1 t2 =
    match t1, t2 with
    | Class (ca, objs), Class (ca', objs') ->
      compare_addr_kind (A_py_class (ca, objs)) (A_py_class (ca', objs'))
    | Function f1, Function f2 ->
      compare_addr_kind (A_py_function f1) (A_py_function f2)
    | Module m1, Module m2 ->
      compare_addr_kind (A_py_module m1) (A_py_module m2)
    | Instance i1, Instance i2 ->
      Compare.compose [
        (* (fun () -> compare_addr i1.classn i2.classn); *)
        (fun () -> compare_polytype i1.classn i2.classn);
        (fun () -> StringMap.compare compare_addr i1.uattrs i2.uattrs);
        (fun () -> StringMap.compare compare_addr i1.oattrs i2.oattrs)
      ]
    (* | Union l1, Union l2 ->
     *   ListExt.compare compare_addr l1 l2 *)
    | Typevar a1, Typevar a2 ->
      Pervasives.compare a1 a2
    | _ -> Pervasives.compare t1 t2

  let map_printer = MapExtSig.{ print_empty = "∅";
                                print_begin = "{";
                                print_arrow = ":";
                                print_sep = ";";
                                print_end = "}"; }

  let rec pp_polytype fmt t =
    match t with
    | Bot -> Format.fprintf fmt "⊥"
    | Top -> Format.fprintf fmt "⊤"
    | Class (C_user c, _) -> Format.fprintf fmt "Class {%a}" pp_var c.py_cls_var
    | Class (C_builtin c, _) | Class (C_unsupported c, _) -> Format.fprintf fmt "Class[%s]" c
    | Function (F_user f) -> Format.fprintf fmt "Function {%a}" pp_var f.py_func_var
    | Function (F_builtin f) | Function (F_unsupported f) -> Format.fprintf fmt "Function[%s]" f
    | Method (F_user f, a) -> Format.fprintf fmt "Method {%a}@%a" pp_var f.py_func_var pp_addr a
    | Method (F_builtin f, a) | Method (F_unsupported f, a) -> Format.fprintf fmt "Method {%s}@%a" f pp_addr a

    | Module (M_user (m, _) | M_builtin(m)) -> Format.fprintf fmt "Module[%s]" m

    | Instance {classn; uattrs; oattrs} ->
     if StringMap.is_empty uattrs && StringMap.is_empty oattrs then
       Format.fprintf fmt "Instance[%a]" pp_polytype classn
     else
       let pp_attrs = (StringMap.fprint map_printer Format.pp_print_string pp_addr) in
       Format.fprintf fmt "Instance[%a, %a, %a]" pp_polytype classn pp_attrs uattrs pp_attrs oattrs

    (* | Union l -> Format.fprintf fmt "Union[%a]" (Format.pp_print_list ~pp_sep:(fun fmt () -> Format.fprintf fmt ",@ ") pp_addr) l *)

    | Typevar t -> Format.fprintf fmt "α(%d)" t

  module Polytypeset = Framework.Lattices.Powerset.Make
      (struct
        type t = polytype
        let compare = compare_polytype
        let print = pp_polytype
      end)

  module TMap = Framework.Lattices.Partial_map.Make
      (struct
        type t = addr
        let compare = compare_addr
        let print = pp_addr
      end)
      (Polytypeset)

  type typevar = int

  module TypeVarMap = Framework.Lattices.Partial_map.Make
      (struct
        type t = typevar
        let compare = compare
        let print fmt d = Format.fprintf fmt "%d@\n" d
      end)
      (Polytypeset)

  type t = {abs_heap: TMap.t;
            typevar_env: TypeVarMap.t}

  type _ domain += D_python_typing : t domain

  let id = D_python_typing
  let name = "python.types.typing"
  let identify : type a. a domain -> (t, a) eq option = function
    | D_python_typing -> Some Eq
    | _ -> None

  type _ Framework.Query.query +=
    | Q_types : Framework.Ast.expr -> Typingdomain.polytype Framework.Query.query

  let debug fmt = Debug.debug ~channel:name fmt

  let exec_interface = {export = [any_zone]; import = [Zone.Z_py_types]}
  let eval_interface = {export = [Zone.Z_py, Zone.Z_py_addr]; import = [Universal.Zone.Z_u_heap, Z_any]}

  let join _ = Exceptions.panic "todo join "

  let polytype_leq (pty, env) (pty', env') =
    (* FIXME *)
    compare_polytype pty pty' = 0

  let subset d d' =
    TMap.fold (fun absaddr ptys acc ->
        let ptys' = TMap.find absaddr d'.abs_heap in
        (* acc && polytype_leq (pty, d.typevar_env) (pty', d'.typevar_env) *)
        acc && Polytypeset.for_all (fun pty -> Polytypeset.exists (fun pty' -> polytype_leq (pty, d.typevar_env) (pty', d'.typevar_env)) ptys') ptys
      )
      d.abs_heap true

  let meet _ _ =  Exceptions.panic "todo meet "
  let widen _ _  = Exceptions.panic "todo widen"
  let top = {abs_heap = TMap.top; typevar_env = TypeVarMap.top}
  let bottom = (* FIXME *) {abs_heap = TMap.bottom; typevar_env = TypeVarMap.bottom}
  let is_bottom {abs_heap; typevar_env} = TMap.is_bottom abs_heap && TypeVarMap.is_bottom typevar_env

  let pp_absheap = TMap.print

  let pp_typevar_env = TypeVarMap.print

  let print fmt {abs_heap; typevar_env} =
    Format.fprintf fmt "abs_heap = %a@\ntypevar_env = %a@\n"
      pp_absheap abs_heap
      pp_typevar_env typevar_env

  let init progr man flow =
    Flow.set_domain_env T_cur {abs_heap = TMap.empty; typevar_env = TypeVarMap.empty} man flow |> Flow.without_callbacks |> OptionExt.return

  let class_le (c, b: class_address * py_object list) (d, b': class_address * py_object list) : bool =
    List.exists (fun x -> match akind @@ fst x with
        | A_py_class (x, _) -> x = d
        | _ -> false) b

  let exec zone stmt man flow =
    debug "exec %a@\n" pp_stmt stmt;
    match skind stmt with
    | S_rename ({ekind = E_addr a}, {ekind = E_addr a'}) ->
      (* TODO: le faire autrepart (addr_env), /!\ zones *)
      let cur = Flow.get_domain_cur man flow in
      let abs_heap = TMap.rename a a' cur.abs_heap in
      debug "abs_heap = %a@\n" pp_absheap abs_heap;
      Flow.set_domain_cur {cur with abs_heap} man flow |> Post.return

    | S_add _ -> Post.return flow

    | S_assign({ekind = E_py_attribute(lval, attr)}, rval) ->
      begin match ekind lval, ekind rval with
        | E_py_object (alval, _), E_py_object (arval, _) ->
          (* FIXME: weak vs strong updates? *)
          let cur = Flow.get_domain_cur man flow in
          Polytypeset.fold (fun old_inst acc ->
              let old_inst = match old_inst with
                | Instance i -> i
                | _ -> assert false in
              let new_inst = Instance {classn=old_inst.classn;
                                       uattrs=StringMap.add attr arval old_inst.uattrs;
                                       oattrs=old_inst.oattrs} in
              let abs_heap = TMap.add alval (Polytypeset.singleton new_inst) cur.abs_heap in
              Flow.set_domain_cur {cur with abs_heap} man flow :: acc) (TMap.find alval cur.abs_heap) []
          |> Flow.join_list man |> Post.return

        | _ -> assert false
      end

    | _ -> None

  let allocate_builtin exp man range flow bltin =
    (* allocate addr, and map this addr to inst bltin *)
    let bltin_cls, bltin_mro =
      let obj = find_builtin bltin in
      match kind_of_object obj with
      | A_py_class (c, b) -> c, b
      | _  -> assert false in
    man.eval (mk_alloc_addr (A_py_instance (*bltin_cls*)) range) flow |>
    Eval.bind (fun eaddr flow ->
        let addr = match ekind eaddr with
          | E_addr a -> a
          | _ -> assert false in
        let cur = Flow.get_domain_cur man flow in
        let bltin_inst = (Polytypeset.singleton (Instance {classn=Class (bltin_cls, bltin_mro); uattrs=StringMap.empty; oattrs=StringMap.empty})) in
        let abs_heap = TMap.add addr bltin_inst cur.abs_heap in
        let flow = Flow.set_domain_cur {cur with abs_heap} man flow in
        (* Eval.singleton eaddr flow *)
        Eval.singleton (mk_py_object (addr, exp) range) flow
      )

  let eval zs exp man flow =
    debug "eval %a@\n" pp_expr exp;
    let range = erange exp in
    match ekind exp with
    | E_addr addr ->
      let cur = Flow.get_domain_cur man flow in
      Polytypeset.fold (fun pty acc ->
          let abs_heap = TMap.add addr (Polytypeset.singleton pty) cur.abs_heap in
          let flow = Flow.set_domain_cur {cur with abs_heap} man flow in
          match pty with
            | Class (c, b) ->
              Eval.singleton (mk_py_object ({addr with addr_kind = (A_py_class (c, b))}, exp) range) flow :: acc

            | _ -> Exceptions.panic_at range "%a@\n" pp_polytype pty)
        (TMap.find addr cur.abs_heap) []
      |> Eval.join_list |> OptionExt.return

    | E_constant (C_top T_bool)
    | E_constant (C_bool _ ) ->
      allocate_builtin exp man range flow "bool" |> OptionExt.return

    | E_constant (C_top T_int)
    | E_constant (C_int _) ->
      allocate_builtin exp man range flow "int" |> OptionExt.return

    | E_constant (C_top (T_float _))
    | E_constant (C_float _) ->
      allocate_builtin exp man range flow "float" |> OptionExt.return

    | E_constant C_py_none ->
      allocate_builtin exp man range flow "NoneType" |> OptionExt.return

    | E_constant (C_top T_string)
    | E_constant (C_string _) ->
      allocate_builtin exp man range flow "str" |> OptionExt.return

    | E_py_bytes _ ->
      allocate_builtin exp man range flow "bytes" |> OptionExt.return

    | E_constant C_py_not_implemented ->
      allocate_builtin exp man range flow "NotImplementedType" |> OptionExt.return

    (* Je pense pas avoir besoin de ça finalement *)
    (* | E_py_object ({addr_kind = A_py_class (c, b)} as addr, expr) ->
     *   let cur = Flow.get_domain_cur man flow in
     *   let abs_heap = TMap.add addr (Polytypeset.singleton (Class (c, b))) cur.abs_heap in
     *   let flow = Flow.set_domain_cur {cur with abs_heap} man flow in
     *   Eval.singleton (mk_addr addr range) flow |> OptionExt.return *)

    (* begin match akind with
     * | A_py_method (func, self) ->
     *    man.eval (mk_py_object ({addr_kind = akind; addr_uid = (-1); addr_mode=STRONG}, mk_py_empty range) range) flow
     * | _ ->
     *    let addr = {addr_kind = akind; addr_uid=(-1);addr_mode=STRONG} in
     *    Eval.singleton (mk_addr addr range) flow
     * end
     * |> OptionExt.return *)

    | E_unop(Framework.Ast.O_log_not, {ekind=E_constant (C_bool b)}) ->
      Eval.singleton (mk_py_bool (not b) range) flow
      |> OptionExt.return

    | E_unop(Framework.Ast.O_log_not, e') ->
      man.eval e' flow |>
      Eval.bind
        (fun exp flow ->
           (* FIXME: test if instance of bool and proceed accordingly *)
           match ekind exp with
           | E_constant (C_top T_bool) -> Eval.singleton exp flow
           | E_constant (C_bool true) ->  Eval.singleton (mk_py_false range) flow
           | E_constant (C_bool false) -> Eval.singleton (mk_py_true range) flow
           | _ -> failwith "not: ni"
        )
      |> OptionExt.return

    | E_py_ll_hasattr({ekind = E_py_object(addr, expr)} as e, attr) ->
      let attr = match ekind attr with
        | E_constant (C_string s) -> s
        | _ -> assert false in
      begin match akind addr with
        | A_py_class (C_builtin _, _)
        | A_py_module _ ->
          Eval.singleton (mk_py_bool (is_builtin_attribute (object_of_expr e) attr) range) flow

        | A_py_class (C_user c, b) ->
          Eval.singleton (mk_py_bool (List.exists (fun v -> v.org_vname = attr) c.py_cls_static_attributes) range) flow

        | A_py_instance ->
          let cur = Flow.get_domain_cur man flow in
          let ptys = TMap.find addr cur.abs_heap in

          Polytypeset.fold (fun pty acc ->
              match pty with
              | Instance {classn; uattrs; oattrs} when StringMap.exists (fun k _ -> k = attr) uattrs ->
                Eval.singleton (mk_py_true range) flow :: acc

              | Instance {classn; uattrs; oattrs} when StringMap.exists (fun k _ -> k = attr) oattrs ->
                let pty_u = Instance {classn; uattrs= StringMap.add attr (StringMap.find attr oattrs) uattrs; oattrs = StringMap.remove attr oattrs} in
                let pty_o = Instance {classn; uattrs; oattrs = StringMap.remove attr oattrs} in
                let cur = Flow.get_domain_cur man flow in
                let flowt = Flow.set_domain_cur {cur with abs_heap = TMap.add addr (Polytypeset.singleton pty_u) cur.abs_heap} man flow in
                let flowf = Flow.set_domain_cur {cur with abs_heap = TMap.add addr (Polytypeset.singleton pty_o) cur.abs_heap} man flow in
                Eval.singleton (mk_py_true range) flowt :: Eval.singleton (mk_py_false range) flowf :: acc

              | Instance _ -> Eval.singleton (mk_py_false range) flow :: acc

              | _ -> Exceptions.panic "ll_hasattr %a" pp_polytype pty) ptys [] |> Eval.join_list

        | _ ->
          debug "%a@\n" pp_expr e; assert false
      end
      |> OptionExt.return

    | E_py_ll_getattr({ekind = E_py_object (addr, expr)} as e, attr) ->
      let attr = match ekind attr with
        | E_constant (C_string s) -> s
        | _ -> assert false in
      begin match akind addr with
        | A_py_class (C_builtin c, b) ->
          Eval.singleton (mk_py_object (find_builtin_attribute (object_of_expr e) attr) range) flow

        | A_py_class (C_user c, b) ->
          let f = List.find (fun x -> x.org_vname = attr) c.py_cls_static_attributes in
          man.eval (mk_var f range) flow

        | _ -> Exceptions.panic_at range "ll_getattr: todo"
      end
      |> OptionExt.return

    | E_py_call({ekind = E_py_object ({addr_kind = A_py_class (C_builtin "type", _)}, _)}, [arg], []) ->
      man.eval arg flow |>
      Eval.bind
        (fun earg flow ->
           let cur = Flow.get_domain_cur man flow in
           match ekind earg with
           | E_py_object ({addr_kind = A_py_instance} as addr, _) ->
             let ptys = TMap.find addr cur.abs_heap in
             let types = Polytypeset.fold (fun pty acc ->
                 match pty with
                 | Instance {classn = Class (c, b) } -> (c, b, Flow.get_domain_cur man flow)::acc
                 | _ -> Exceptions.panic_at range "type : todo"
               ) ptys [] in
             let proceed (cl, mro, cur) =
               let flow = Flow.set_domain_cur cur man flow in
               let obj = mk_py_object ({addr with addr_kind = A_py_class (cl, mro)}, exp) range in
               Eval.singleton obj flow in
             List.map proceed types |> Eval.join_list

           | _ -> Exceptions.panic_at range "type: todo"


        )
      |> OptionExt.return

    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "issubclass")}, _)}, [cls; cls'], []) ->
      Exceptions.panic "issubclass"

    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "isinstance")}, _)}, [obj; attr], []) ->
      Eval.eval_list [obj; attr] man.eval flow |>
      Eval.bind (fun evals flow ->
          let eobj, eattr = match evals with [e1; e2] -> e1, e2 | _ -> assert false in
          let addr_obj = match ekind eobj with
            | E_py_object (a, _) -> a
            | _ -> assert false in
          let addr_attr = match ekind eattr with
            | E_py_object (a, _) -> a
            | _ -> assert false in
          match akind addr_obj, akind addr_attr with
          | A_py_class _, A_py_class (C_builtin c, _) ->
            Eval.singleton (mk_py_bool (c = "type") range) flow

          | A_py_function _, A_py_class (C_builtin c, _) ->
            Eval.singleton (mk_py_bool (c = "function") range) flow

          | A_py_instance, A_py_class (c, mro) ->
            let cur = Flow.get_domain_cur man flow in
            let ptys = TMap.find addr_obj cur.abs_heap in
            Polytypeset.fold (fun pty acc ->
                begin match pty with
                  | Instance {classn=Class (ci, mroi); uattrs; oattrs} ->
                    Eval.singleton (mk_py_bool (class_le (ci, mroi) (c, mro)) range) flow :: acc
                  | _ -> Exceptions.panic "todo@\n"
                end) ptys []
            |> Eval.join_list

          | _ -> assert false
        )
      |> OptionExt.return

    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "object.__new__")}, _)}, args, []) ->
      Eval.eval_list args man.eval flow |>
      Eval.bind (fun args flow ->
          match args with
          | [] ->
            debug "Error during creation of a new instance@\n";
            man.exec (Utils.mk_builtin_raise "TypeError" range) flow |> Eval.empty_singleton
          | cls :: tl ->
            man.eval (mk_alloc_addr A_py_instance range) flow |>
            Eval.bind (fun eaddr flow ->
                let addr = match ekind eaddr with
                  | E_addr a -> a
                  | _ -> assert false in
                let cur = Flow.get_domain_cur man flow in
                let cls, mro = match akind @@ fst @@ object_of_expr cls with
                  | A_py_class (c, mro) -> c, mro
                  | _ -> assert false in
                let inst = Polytypeset.singleton (Instance {classn = Class (cls, mro); uattrs=StringMap.empty; oattrs=StringMap.empty}) in
                let abs_heap = TMap.add addr inst cur.abs_heap in
                let flow = Flow.set_domain_cur {cur with abs_heap} man flow in
                Eval.singleton (mk_py_object (addr, exp) range) flow
              )
        )
      |> OptionExt.return

    | E_py_call({ekind = E_py_object ({addr_kind = A_py_function (F_builtin "object.__init__")}, _)}, args, []) ->
      man.eval (mk_py_none range) flow |> OptionExt.return

    | E_py_sum_call (f, args) ->
      let func = match ekind f with
        | E_function (User_defined func) -> func
        | _ -> assert false in
      (* if !opt_pyty_summaries then
       *   Exceptions.panic_at range "todo@\n"
       * else *)
        man.eval (mk_call func args range) flow
        |> OptionExt.return


    | _ ->
      debug "Warning: no eval for %a" pp_expr exp;
      None


  let is_type_query : type r. r Framework.Query.query -> bool =
    function
    | Q_types _ -> true
    | _ -> false

  let ask : type r. r Framework.Query.query -> ('a, t) man -> 'a flow -> r option =
    fun query man flow ->
    match query with
    | Q_types t ->
      Exceptions.panic "query on %a@\n" pp_expr t
    | _ -> None

end

let () = register_domain (module Domain)

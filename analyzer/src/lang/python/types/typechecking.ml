open Mopsa
open Addr
open Typing
open Addr_env
open Ast
open Universal.Ast



module Domain =
struct
  (* TODO: lists and polymorphism? *)

  module AD = Addr_env.Domain
  module TD = Typing.Domain

  module Iter = Framework.Combiners.Domain.Sequence.Make
      (Framework.Core.Sig.Intermediate.Domain.MakeLowlevelDomain(AD))
      (Framework.Core.Sig.Intermediate.Domain.MakeLowlevelDomain(TD))

  include Iter

  let name = "python.types.typechecking"
  let debug fmt = Debug.debug ~channel:name fmt

  (* let opt_polymorphism = ref false
   *
   * let () =
   *   register_domain_option name {
   *     key = "-pyty-polymorphism";
   *     category = "Python";
   *     doc = " enable type polymorphism";
   *     spec = ArgExt.Set opt_polymorphism;
   *     default = "false"
   *   } *)

  let extract_types_aset (t: TD.t) (aset: AD.ASet.t) : TD.Polytypeset.t =
    AD.ASet.fold (fun addr acc ->
        match addr with
        | Def addr ->
          let to_join = match addr.addr_kind with
            (* | A_py_var _ (\* TODO: est-ce que c'est ok? *\) *)
            | A_py_instance _ ->
  (TD.TMap.find addr t.abs_heap)
            | A_py_class (c, b) ->
              let ty = Class (c, b) in
              TD.Polytypeset.singleton ty
            | A_py_module m ->
              TD.Polytypeset.singleton (Module m)
            | A_py_function f ->
              TD.Polytypeset.singleton (Function f)
            | _ -> Debug.warn "%a@\n" pp_addr addr;
              TD.Polytypeset.empty
          in
          TD.Polytypeset.union acc to_join
        | _ -> acc
      ) aset TD.Polytypeset.empty

  let extract_types (a: AD.t) (t: TD.t) (v: var) : TD.Polytypeset.t =
    extract_types_aset t (AD.AMap.find v a)

  module VarSet = SetExt.Make
      (struct
        type t = var
        let compare = compare_var
        let print = pp_var
      end
      )

  type partition = (VarSet.t * TD.Polytypeset.t) list

  type intersectedpartition = (VarSet.t * TD.Polytypeset.t * TD.Polytypeset.t) list

  let pp_i fmt (vs, tys1, tys2) =
    Format.fprintf fmt "[%a -> %a | %a]" (VarSet.fprint SetExt.printer_default pp_var) vs TD.Polytypeset.print tys1 TD.Polytypeset.print tys2

  let pp_ip fmt ip =
    Format.pp_print_list ~pp_sep:(fun fmt () -> Format.fprintf fmt "@\n") pp_i fmt ip

  let pp_e fmt (vs, tys1) =
    Format.fprintf fmt "[%a -> %a]" (VarSet.fprint SetExt.printer_default pp_var) vs TD.Polytypeset.print tys1

  let pp_p fmt p =
    Format.pp_print_list ~pp_sep:(fun fmt () -> Format.fprintf fmt "@\n") pp_e fmt p

  let create_partition (a: AD.t) (t: TD.t) : partition =
    AD.AMap.fold (fun var aset acc ->
        let tys = match aset with
          | TOP -> TD.Polytypeset.top
          | _ ->   extract_types_aset t aset in
          let sameclass, others = ListExt.partition (fun (_, tys') -> TD.Polytypeset.equal tys tys') acc in
          match sameclass with
          | [] -> (VarSet.singleton var, tys):: others
          | [(vars, _)] -> (VarSet.add var vars, tys):: others
          | _ -> assert false
      ) a []

  let intersect_partitions (p: partition) (p': partition) : intersectedpartition =
    let lift_left (p: partition) : intersectedpartition = List.map (fun (vars, tys) -> (vars, tys, TD.Polytypeset.empty)) p in
    let intersect_one (part: intersectedpartition) ((vars, tys): VarSet.t * TD.Polytypeset.t) : intersectedpartition =
      List.fold_left (fun acc (vars_part, tys_part, tys_other) ->
          let vars_int, vars_diff = VarSet.inter vars_part vars, VarSet.diff vars_part vars in
          let res_int  = vars_int, tys_part, TD.Polytypeset.union tys_other tys
          and res_diff = vars_diff, tys_part, tys_other in
          match VarSet.is_empty vars_int, VarSet.is_empty vars_diff with
          | true, true   -> acc
          | false, false -> res_int  :: res_diff :: acc
          | true, false  -> res_diff :: acc
          | false, true  -> res_int  :: acc
        ) [] part in
    List.fold_left (fun acc part' -> intersect_one acc part') (lift_left p) p'



  (* let join man a a' =
   *   Framework.Core.Sig.Intermediate.Domain.lift_binop
   *     (fun (hd, tl) (hd', tl') ->
   *        (\* if !opt_polymorphism then *\)
   *        match hd, hd' with
   *        | AD.AMap.Top, _ | _, AD.AMap.Top -> Iter.top
   *        | _ ->
   *          match tl.TD.abs_heap, tl'.TD.abs_heap with
   *          | TD.TMap.Top, _ | _, TD.TMap.Top -> Iter.top
   *          | _ ->
   *            debug "hd, tl = %a, %a@\n@\nhd', tl' = %a, %a@\n" AD.print hd TD.print tl AD.print hd' TD.print tl';
   *            let p = create_partition hd tl
   *            and p' = create_partition hd' tl' in
   *            let ip = intersect_partitions p p' in
   *            let ip = List.filter (fun (vars, ty1, ty2) -> not (TD.Polytypeset.is_top ty1) && not (TD.Polytypeset.is_top ty2) && VarSet.cardinal vars > 1 && TD.Polytypeset.cardinal ty1 > 0 && TD.Polytypeset.cardinal ty2 > 0 && not (TD.Polytypeset.cardinal ty1 = 1 && TD.Polytypeset.equal ty1 ty2))
   *                ip in
   *            debug "interesting partitions:@[@\n%a@]@\n" pp_ip ip;
   *            (\* FIXME: is that necessary? *\)
   *            let jhd = AD.join hd hd' and jtl = TD.join tl tl' in
   *            let rhd, rabsheap = List.fold_left (fun (rhd, rabsheap) (vars, ty1, ty2) ->
   *                let alpha = get_fresh_a_py_var () in
   *                let addr = {addr_uid = alpha; addr_kind = A_py_var alpha; addr_mode = WEAK} in
   *                let types = TD.Polytypeset.join ty1 ty2 in
   *                let rhd = VarSet.fold (fun var rhd -> AD.AMap.add var (AD.ASet.singleton (Def addr)) rhd) vars rhd in
   *                let rabsheap = TD.TMap.add addr types rabsheap in
   *                (rhd, rabsheap)
   *              ) (jhd, jtl.abs_heap) ip in
   *            let rtl = {jtl with abs_heap = rabsheap} in
   *            debug "result is %a@\n%a@\n" AD.print rhd TD.print rtl;
   *            rhd, {jtl with abs_heap = rabsheap}
   *            (\* else
   *             *   Iter.join annot (hd, tl) (hd', tl') *\)
   *     ) man a a' *)

end

let () = Framework.Core.Sig.Lowlevel.Domain.register_domain (module Domain)

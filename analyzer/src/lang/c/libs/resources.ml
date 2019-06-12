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

(** Common transfer functions for resource management *)

open Mopsa
open Framework.Core.Sig.Domain.Stateless
open Universal.Ast
open Stubs.Ast
open Memory.Common.Points_to
open Ast
open Zone


module Domain =
struct


  (** Domain identification *)
  (** ===================== *)

  include GenStatelessDomainId(struct
      let name = "c.libs.resources"
    end)

  let interface= {
    iexec = {
      provides = [Z_c];
      uses = [Z_c; Z_c_scalar; Z_c_low_level]
    };

    ieval = {
      provides = [Z_c_low_level, Z_c_scalar];
      uses = [Z_c_low_level, Z_c_points_to]
    }
  }


  (** Initialization of environments *)
  (** ============================== *)

  let init _ _ flow =  flow


  (** Bytes attribute *)
  (** =============== *)

  type var_kind +=
    | V_c_bytes of addr

  let pp_bytes fmt addr =
    Format.fprintf fmt "bytes(%a)" pp_addr addr

  let () =
    register_var {
      print = (fun next fmt v ->
          match v.vkind with
          | V_c_bytes addr -> pp_bytes fmt addr
          | _ -> next fmt v
        );

      compare = (fun next v1 v2 ->
          match v1.vkind, v2.vkind with
          | V_c_bytes a1, V_c_bytes a2 -> compare_addr a1 a2
          | _ -> next v1 v2
        );
    }


  let mk_bytes_var addr =
    let name =
      let () = pp_bytes Format.str_formatter addr in
      Format.flush_str_formatter ()
    in
    mkv name (V_c_bytes addr) (T_c_integer C_unsigned_long)

  let mk_bytes addr range =
    let v = mk_bytes_var addr in
    mk_var v ~mode:addr.addr_mode range

  let mk_size addr elm range =
    let bytes = mk_bytes addr range in
    if Z.equal elm Z.one
    then bytes
    else mk_binop bytes O_div (mk_z elm range) ~etyp:bytes.etyp range


  (** Computation of post-conditions *)
  (** ============================== *)

  let exec zone stmt man flow  =
    match skind stmt with
    | S_stub_free { ekind = E_addr (addr) } ->
      Post.return flow |>
      Option.return

    | S_stub_free p ->
      man.eval ~zone:(Z_c, Z_c_points_to) p flow |>
      Option.return |> Option.lift @@ post_eval man @@ fun pt flow ->

      begin match ekind pt with
        | E_c_points_to (P_block (A ({ addr_kind = A_stub_resource _ } as addr), _)) ->
          (* Remove the bytes attribute before removing the address *)
          let stmt' = mk_remove_var (mk_bytes_var addr) stmt.srange in
          let flow' = man.exec ~zone:Z_c_scalar stmt' flow in

          let stmt' = mk_free_addr addr stmt.srange in
          let flow' = man.exec stmt' flow' in

          let stmt'' = mk_stub_free (mk_addr addr stmt.srange) stmt.srange in
          man.exec stmt'' flow' |>
          Post.return

        | _ ->
          panic_at stmt.srange "resources.common: free(p | p %a) not supported" pp_expr pt
      end

    | S_rename ({ ekind = E_addr ({ addr_kind = A_stub_resource _ } as addr1) },
                { ekind = E_addr ({ addr_kind = A_stub_resource _ } as addr2) })
      ->
      let bytes1 = mk_bytes_var addr1 in
      let bytes2 = mk_bytes_var addr2 in
      man.exec ~zone:Z_c_scalar (mk_rename_var bytes1 bytes2 stmt.srange) flow |>
      man.exec ~zone:Z_c_low_level stmt |>
      Post.return |>
      Option.return

    | _ -> None



  (** Evaluation of expressions *)
  (** ========================= *)

  let eval zone exp man flow =
    match ekind exp with
    (* 𝔼⟦ new Resource ⟧ *)
    | E_stub_alloc res ->
      (* Allocate in the heap *)
      let alloc = mk_alloc_addr (A_stub_resource res) exp.erange in
      man.eval ~zone:(Universal.Zone.Z_u_heap, Z_any) alloc flow |>
      Option.return |> Option.lift @@ Eval.bind @@ fun exp flow ->

      begin match ekind exp with
      | E_addr addr ->
        (* Add bytes attribute *)
        let bytes = mk_bytes_var addr in
        let flow' = man.exec ~zone:Z_c_scalar (mk_add_var bytes exp.erange) flow in
        Eval.singleton exp flow'

      | _ -> assert false
      end

    | E_stub_builtin_call(BYTES, { ekind = E_addr addr }) ->
      Eval.singleton (mk_var (mk_bytes_var addr) exp.erange) flow |>
      Option.return


    | E_stub_builtin_call(BYTES, e) ->
      Some (
        man.eval ~zone:(Z_c_low_level,Z_c_points_to) e flow |>
        Eval.bind @@ fun pt flow ->

        match ekind pt with
        | E_c_points_to (P_block (V var,_)) ->
          Eval.singleton (mk_z (sizeof_type var.vtyp) exp.erange ~typ:ul) flow

        | E_c_points_to (P_block (S str,_)) ->
          Eval.singleton (mk_int (String.length str + 1) exp.erange ~typ:ul) flow

        | E_c_points_to (P_block (A addr,_)) ->
          Eval.singleton (mk_bytes addr exp.erange) flow

        | E_c_points_to (P_block (Z,_)) -> panic ~loc:__LOC__ "bytes: addresses not supported"

        | E_c_points_to P_top ->
          Eval.singleton (mk_top ul exp.erange) flow

        | _ -> panic_at exp.erange "bytes(%a | %a %a) not supported" pp_expr e pp_expr e pp_expr pt
      )

    | E_stub_builtin_call(SIZE, e) ->
      Some (
        man.eval ~zone:(Z_c_low_level,Z_c_points_to) e flow |>
        Eval.bind @@ fun pt flow ->

        let elm =
          match under_type e.etyp with
          | T_c_void -> Z.one
          | t -> sizeof_type t
        in

        match ekind pt with
        | E_c_points_to (P_block (V var,_)) ->
          Eval.singleton (mk_z (Z.div (sizeof_type var.vtyp) elm) exp.erange ~typ:ul) flow

        | E_c_points_to (P_block (S str,_)) ->
          Eval.singleton (mk_z (Z.div (Z.of_int (String.length str + 1)) elm) exp.erange ~typ:ul) flow

        | E_c_points_to (P_block (A addr,_)) ->
          Eval.singleton (mk_size addr elm exp.erange) flow

        | E_c_points_to (P_block (Z,_)) -> panic ~loc:__LOC__ "eval_base_size: addresses not supported"

        | E_c_points_to P_top ->
          Eval.singleton (mk_top ul exp.erange) flow

        | E_c_points_to P_valid ->
          let _,max = rangeof ul in
          Eval.singleton (mk_z_interval Z.one max exp.erange) flow

        | E_c_points_to P_null 
        | E_c_points_to P_invalid ->
          warn_at exp.erange "size(%a) where %a %a not supported" pp_expr e pp_expr e pp_expr pt;
          Eval.singleton (mk_top ul exp.erange) flow


        | _ -> panic_at exp.erange "size(%a | %a %a) not supported" pp_expr e pp_expr e pp_expr pt
      )


    | E_stub_attribute({ ekind = E_addr _ }, _) ->
      None

    | E_stub_attribute(p, attr) ->
      man.eval ~zone:(Z_c, Z_c_points_to) p flow |>
      Option.return |> Option.lift @@ Eval.bind @@ fun pt flow ->

      begin match ekind pt with
        | E_c_points_to (P_block (A ({ addr_kind = A_stub_resource _ } as addr), _)) ->
          let exp' = { exp with ekind = E_stub_attribute(mk_addr addr exp.erange, attr) }  in
          man.eval exp' flow

        | E_c_points_to P_top ->
          (* When the resource is not assigned yet, can we just return an interval ? *)
          let l, u = rangeof exp.etyp in
          let exp' = mk_z_interval l u ~typ:exp.etyp exp.erange in
          Eval.singleton exp' flow

        | _ -> assert false
      end

    | E_stub_resource_mem(p, res) ->
      man.eval ~zone:(Z_c, Z_c_points_to) p flow |>
      Option.return |> Option.lift @@ Eval.bind @@ fun pt flow ->

      begin match ekind pt with
        | E_c_points_to (P_block (A { addr_kind = A_stub_resource res' }, _)) ->
          if res = res' then
            Eval.singleton (mk_one exp.erange ~typ:u8) flow
          else
            Eval.singleton (mk_zero exp.erange ~typ:u8) flow

        | E_c_points_to P_top ->
          Eval.singleton (mk_top T_bool exp.erange) flow

        | _ ->
          Eval.singleton (mk_zero exp.erange ~typ:u8) flow
      end

    | _ -> None

  let ask _ _ _ = None

end

let () =
  Framework.Core.Sig.Domain.Stateless.register_domain (module Domain)
(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(** Disjunctive normal form. *)

type 'a t = 'a list list

let singleton (a: 'a) : 'a t = [[a]]

let mk_true = [[]]

let mk_false = []

let rec mk_and ?(fand=(@)) (a: 'a t) (b: 'a t) : 'a t =
   List.fold_left (fun acc conj1 ->
      List.fold_left (fun acc conj2 ->
          let conj = fand conj1 conj2 in
          mk_or acc [conj]
        ) acc b
    ) mk_false a

and mk_or (a: 'a t) (b: 'a t) : 'a t = a @ b

and mk_neg neg (a: 'a t) : 'a t =
  a |> List.fold_left (fun acc conj ->
      mk_and acc (
        conj |>
        List.fold_left (fun acc x ->
            mk_or acc (neg x)
          ) []
      )
    ) [[]]

let map
    (f: 'a -> 'b)
    (dnf: 'a t)
  : 'b t =
  List.map (List.map f) dnf

let fold
    (f: 'b -> 'a -> 'b)
    (join: 'b -> 'b -> 'b)
    (meet: 'b -> 'b -> 'b)
    (init: 'b)
    (dnf: 'a t)
  : 'b =
  let rec apply_conj acc = function
    | [] -> assert false
    | [e] -> f acc e
    | e :: tl ->
      let acc1 = f acc e in
      let acc2 = apply_conj acc1 tl in
      meet acc1 acc2
  in
  let rec apply_disj acc = function
    | [conj] -> apply_conj acc conj
    | conj :: tl ->
      let acc1 = apply_conj acc conj in
      let acc2 = apply_disj acc1 tl in
      join acc1 acc2
    | _ -> assert false
  in
  apply_disj init dnf

let fold2
    (f: 'c -> 'a -> 'b * 'c)
    (join: 'b -> 'b -> 'b)
    (meet: 'b -> 'b -> 'b)
    (init: 'c)
    (dnf: 'a t)
  : 'b * 'c =
  let rec apply_conj acc = function
    | [] -> assert false
    | [e] -> f acc e
    | e :: tl ->
      let (b1, acc1) = f acc e in
      let (b2, acc2) = apply_conj acc1 tl in
      meet b1 b2, acc2
  in
  let rec apply_disj acc = function
    | [conj] -> apply_conj acc conj
    | conj :: tl ->
      let (b1, acc1) = apply_conj acc conj in
      let (b2, acc2) = apply_disj acc1 tl in
      (join b1 b2, acc2)
    | _ -> assert false
  in
  apply_disj init dnf

let choose (dnf: 'a t) : 'a =
  match dnf with
  | [] | [[]] -> failwith "Dnf.choose: empty argument"
  | (hd :: _) :: _ -> hd
  | _ -> assert false

let to_list dnf = dnf

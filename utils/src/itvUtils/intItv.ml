(**
  IntItv - Intervals for arbitrary precision integers.

  We rely on Zarith for arithmetic operations, and IntBounds to
  represent unbounded intervals.


  Copyright (C) 2017 The MOPSA Project

  This program is free software: you can redistribute it and/or modify
  it under the terms of the CeCILL license V2.1.

  @author Antoine Mine'
 *)


open Bot
module B = IntBound


(** {2 Types} *)


type t = B.t (** lower bound *) * B.t (** upper bound *)
(**
  The type of non-empty intervals: a lower bound and an upper bound.
  The lower bound can be MINF, but not PINF; the upper bound can be PINF, but not MINF.
  Moreover, lower bound ≤ upper bound.
 *)

type t_with_bot = t with_bot
(** The type of possibly empty intervals. *)

let is_valid ((a,b):t) : bool =
  B.leq a b && a <> B.PINF && b <> B.MINF



(** {2 Constructors} *)

let of_bound (a:B.t) (b:B.t) : t =
  if a = B.PINF || b = B.MINF || B.gt a b then
    invalid_arg (Printf.sprintf "IntItv.of_bound [%s,%s]" (B.to_string a) (B.to_string b));
  a, b

let of_z (a:Z.t) (b:Z.t) : t =
  if Z.gt a b then
    invalid_arg (Printf.sprintf "IntItv.of_z [%s,%s]" (Z.to_string a) (Z.to_string b));
  B.Finite a, B.Finite b

let of_int (a:int) (b:int) : t =
  if a > b then
    invalid_arg (Printf.sprintf "IntItv.of_int [%i,%i]" a b);
  B.of_int a, B.of_int b

let of_int64 (a:int64) (b:int64) : t =
  if a > b then
    invalid_arg (Printf.sprintf "IntItv.of_int64 [%Li,%Li]" a b);
  B.of_int64 a, B.of_int64 b
(** Constructs a non-empty interval. *)

let of_float (a:float) (b:float) : t =
  if a > b || a = infinity || b = neg_infinity then
    invalid_arg (Printf.sprintf "IntItv.of_float [%f,%f]" a b);
  B.of_float a, B.of_float b
(** Constructs a non-empty interval. *)

let of_range = of_z

let of_bound_bot (a:B.t) (b:B.t) : t_with_bot =
  if B.gt a b || a = B.PINF || b = B.MINF then BOT
  else Nb (a, b)

let of_range_bot (a:Z.t) (b:Z.t) : t_with_bot =
  if Z.gt a b then BOT
  else Nb (B.Finite a, B.Finite b)

let of_int_bot (a:int) (b:int) : t_with_bot =
  if a > b then BOT
  else Nb (B.of_int a, B.of_int b)

let of_int64_bot (a:int64) (b:int64) : t_with_bot =
  if a > b then BOT
  else Nb (B.of_int64 a, B.of_int64 b)
(** Constructs a possibly empty interval. *)

let of_float_bot (a:float) (b:float) : t_with_bot =
  if a > b || a = infinity || b = neg_infinity then BOT
  else Nb (B.of_float a, B.of_float b)
(** Constructs a possibly empty interval. *)

let hull (a:B.t) (b:B.t) : t =
  B.min a b, B.max a b
(** Constructs the smallest interval containing a and b. *)

let cst (c:Z.t) : t =
  B.Finite c, B.Finite c
(** Singleton interval. *)

let cst_int (c:int) : t = cst (Z.of_int c)

let cst_int64 (c:int64) : t = cst (Z.of_int64 c)

let zero : t = cst Z.zero
(** [0,0] *)

let one : t = cst Z.one
(** [1,1] *)

let mone : t = cst Z.minus_one
(** [-1,-1] *)

let zero_one : t = B.Finite Z.zero, B.Finite Z.one
(** [0,1] *)

let mone_zero : t = B.Finite Z.minus_one, B.Finite Z.zero
(** [-1,0] *)

let mone_one : t = B.Finite Z.minus_one, B.Finite Z.one
(** [-1,1] *)

let zero_inf : t = B.Finite Z.zero, B.PINF
(** [0,+∞] *)

let minf_zero : t = B.MINF, B.Finite Z.zero
(** [-∞,0] *)

let minf_inf : t = B.MINF, B.PINF
(** [-∞,+∞] *)


let unsigned (bits:int) : t = B.zero, B.pred (B.pow2 bits)
let unsigned8 : t = unsigned 8
let unsigned16 : t = unsigned 16
let unsigned32 : t = unsigned 32
let unsigned64 : t = unsigned 64
(** Intervals of unsigned integers with the specified bitsize. *)

let signed (bits:int) : t = B.neg (B.pow2 (bits-1)), B.pred (B.pow2 (bits-1))
let signed8 : t = signed 8
let signed16 : t = signed 16
let signed32 : t = signed 32
let signed64 : t = signed 64
(** Intervals of two compement's integers with the specified bitsize. *)



(** {2 Predicates} *)


let equal ((a,b):t) ((a',b'):t) : bool =
  B.eq a a' && B.eq b b'
(** Equality. = also works *)

let equal_bot : t_with_bot -> t_with_bot -> bool =
  bot_equal equal

let included ((a,b):t) ((a',b'):t) : bool =
  B.geq a a' && B.leq b b'
(** Set ordering. *)

let included_bot : t_with_bot -> t_with_bot -> bool =
  bot_included included

let intersect ((a,b):t) ((a',b'):t) : bool =
  B.leq a b' && B.leq a' b
(** Whether the intervals have an non-empty intersection. *)

let intersect_bot : t_with_bot -> t_with_bot -> bool =
  bot_dfl2 false intersect

let contains (x:Z.t) ((a,b):t) : bool =
  B.leq a (B.Finite x) && B.leq (B.Finite x) b
(** Whether the interval contains a (finite) value. *)

let compare ((a,b):t) ((a',b'):t) : int =
  if B.eq a a' then B.compare b b' else B.compare a a'
(**
  A total ordering (lexical ordering) returning -1, 0, or 1.
  Can be used as compare for sets, maps, etc.
*)

let compare_bot (x:t with_bot) (y:t with_bot) : int =
  Bot.bot_compare compare x y
(** Total ordering on possibly empty intervals. *)

let contains_zero ((a,b):t) : bool =
  B.sign a <= 0 && B.sign b >= 0
(** [a,b] contains 0. *)

let contains_one ((a,b):t) : bool =
  B.leq a B.one && B.geq b B.one
(** [a,b] contains 1. *)

let contains_nonzero ((a,b):t) : bool =
  B.neq a B.zero || B.neq b B.zero
(** [a,b] contains a non-zero value. *)

let is_zero (ab:t) : bool = ab = zero
let is_positive ((a,b):t) : bool = B.is_positive a
let is_negative ((a,b):t) : bool = B.is_negative b
let is_positive_strict ((a,b):t) : bool = B.is_positive_strict a
let is_negative_strict ((a,b):t) : bool = B.is_negative_strict b
let is_nonzero ((a,b):t) : bool = B.gt a B.zero || B.lt b B.zero
(** Interval sign. *)

let is_singleton ((a,b):t) : bool = B.eq a b
(** [a,b] contains a single element. *)

let is_bounded ((a,b):t) : bool = a <> B.MINF && b <> B.PINF
(** [a,b] has finite bounds. *)

let is_minf_inf ((a,b):t) : bool = a = B.MINF && b = B.PINF
(** [a,b] represents [-∞,+∞]. *)

let is_in_range (a:t) (lo:Z.t) (up:Z.t) =
  included a (B.Finite lo, B.Finite up)
(** Whether the interval is included in the range [lo,up]. *)



(** {2 Printing} *)


let to_string ((a,b):t) : string = "["^(B.to_string a)^","^(B.to_string b)^"]"
let print ch (x:t) = output_string ch (to_string x)
let fprint ch (x:t) = Format.pp_print_string ch (to_string x)
let bprint ch (x:t) = Buffer.add_string ch (to_string x)

let to_string_bot = bot_to_string to_string
let print_bot = bot_print print
let fprint_bot = bot_fprint fprint
let bprint_bot = bot_bprint bprint



(** {2 Enumeration} *)


let size ((a,b):t) =
  match a,b with
  | B.Finite x, B.Finite y -> Z.succ (Z.sub y x)
  | _ -> invalid_arg (Printf.sprintf "IntItv.size: unbounded interval %s" (to_string (a,b)))
(** Number of elements. Raises an invalid argument if it is unbounded. *)

let to_list ((a,b):t) =
  let rec doit l h acc =
    if l=h then l :: acc
    else doit l (Z.pred h) (h::acc)
  in
  match a,b with
  | B.Finite x, B.Finite y -> doit x y []
  | _ -> invalid_arg (Printf.sprintf "IntItv.to_list: unbounded interval %s" (to_string (a,b)))
(** List of elements, in increasing order. Raises an invalid argument if it is unbounded. *)


(** {2 Set operations} *)


let join ((a,b):t) ((a',b'):t) : t =
  B.min a a', B.max b b'
(** Join of non-empty intervals. *)

let join_bot (a:t_with_bot) (b:t_with_bot) : t_with_bot =
  bot_neutral2 join a b
(** Join of possibly empty intervals. *)

let join_list (l:t list) : t_with_bot =
  List.fold_left (fun a b -> join_bot a (Nb b)) BOT l
(** Join of a list of (non-empty) intervals. *)

let meet ((a,b):t) ((a',b'):t) : t_with_bot =
  of_bound_bot (B.max a a') (B.min b b')
(** Intersection of non-emtpty intervals (possibly empty) *)

let meet_bot (a:t_with_bot) (b:t_with_bot) : t_with_bot =
  bot_absorb2 meet a b
(** Intersection of possibly empty intervals. *)

let meet_list (l:t list) : t_with_bot =
  List.fold_left (fun a b -> meet_bot a (Nb b)) (Nb minf_inf) l
(** Meet of a list of (non-empty) intervals. *)

let widen ((a,b):t) ((a',b'):t) : t =
  (if B.lt a' a then B.MINF else a),
  (if B.gt b' b then B.PINF else b)
(** Basic widening: put unstable bounds to infinity. *)

let widen_bot (a:t_with_bot) (b:t_with_bot) : t_with_bot =
  bot_neutral2 widen a b


let positive (a:t) : t_with_bot = meet a zero_inf
let negative (a:t) : t_with_bot = meet a minf_zero
(** Positive and negative part. *)

let meet_zero (a:t) : t_with_bot =
  meet a zero
(** Intersects with {0}. *)

let meet_nonzero ((a,b):t) : t_with_bot =
  match B.is_zero a, B.is_zero b with
  | true,  true  -> BOT
  | true,  false -> Nb (B.succ a, b)
  | false, true  -> Nb (a, B.pred b)
  | false, false -> Nb (a,b)
(** Keeps only non-zero elements. *)



(** {2 Forward operations} *)


(** Given one or two interval argument(s), return the interval result. *)


let neg ((a,b):t) : t =
  B.neg b, B.neg a
(** Negation. *)

let abs ((a,b):t) : t =
  if B.sign a <= 0 then
    if B.sign b <= 0 then neg (a,b)
    else B.zero, B.max (B.neg a) b
  else a,b
(** Absolute value. *)

let succ ((a,b):t) : t =
  B.succ a, B.succ b
(** Add 1. *)

let pred ((a,b):t) : t =
  B.pred a, B.pred b
(** Subtract 1. *)


let add ((a,b):t) ((a',b'):t) : t =
  B.add a a', B.add b b'
(** Addition. *)

let sub ((a,b):t) ((a',b'):t) : t =
  B.sub a b', B.sub b a'
(** Subtraction. *)

let minmax4 op (a,b) (c,d) =
  let x,y,z,t = op a c, op a d, op b c, op b d in
  B.min (B.min x y) (B.min z t), B.max (B.max x y) (B.max z t)
(* utility used internally for multiplication and others *)

let mul (ab:t) (ab':t) : t =
  minmax4 B.mul ab ab'
(** Multiplication. *)

let div_unmerged (ab:t) ((a',b'):t) : t list =
  (* division by an interval of constant sign *)
  let div_pos ab ab' = minmax4 B.div ab ab' in
  (* split denominator and do 2 cases *)
  (if B.is_positive_strict b' then [div_pos ab (B.max a' B.one, b')] else [])@
  (if B.is_negative_strict a' then [div_pos ab (a', B.min b' B.minus_one)] else [])
(** Division (with truncation).
    Returns a list of 0, 1, or 2 intervals to remain precise.
 *)

let div (a:t) (b:t) : t_with_bot =
  join_list (div_unmerged a b)
(** Division (with truncation).
    Returns a single (possibly empty) overapproximating interval.
 *)

let rem ((a,b):t) (ab':t) : t_with_bot =
  (* x % y = x % |y| *)
  let a',b' = abs ab' in
  if B.is_zero b' then BOT else (* case [a,b] % {0} ⟹ ⊥ *)
    let m = B.pred b' in
    if B.gt a (B.neg a') && B.lt b a' then
      (* case [a,b] ⊆ [-a+1',a'-1] ⟹ identity *)
      Nb (a,b)
    else if B.equal a' b' && B.equal (B.div a a') (B.div b a') then
      (* case [a,b] % {a'} and [a,b] ⊆ [a'k,a'(k+1)-1] *)
      Nb (B.rem a a', B.rem b a')
    else if B.is_positive a then
      (* case [a,b] % [a',b'] positive *)
      Nb (B.zero, m)
    else if B.is_negative b then
      (* case [a,b] % [a',b'] negative *)
      Nb (B.neg m, B.zero)
    else
      (* general case *)
      Nb (B.neg m, m)
(** Remainder. Uses the C semantics for remainder (%). *)

let pow (ab:t) (ab':t) : t =
  minmax4 B.pow ab ab'
(** Power. *)

let wrap ((a,b):t) (lo:Z.t) (up:Z.t) : t =
  match a,b with
  | B.MINF,_ | _,B.PINF -> B.Finite lo, B.Finite up
  | B.Finite aa, B.Finite bb ->
     let w = Z.succ (Z.sub up lo) in
     let (aq,ar), (bq,br) = Z.ediv_rem (Z.sub aa lo) w, Z.ediv_rem (Z.sub bb lo) w in
     if aq = bq then
        (* included in some [lo,up]+kw *)
       B.Finite (Z.add ar lo), B.Finite (Z.add br lo)
     else
       (* crosses interval boundaries *)
       B.Finite lo, B.Finite up
  | _ -> invalid_arg (Printf.sprintf "IntItv.wrap %s in [%s,%s]" (to_string (a,b)) (Z.to_string lo) (Z.to_string up))
(** Put back the interval inside [lo,up] by modular arithmetics.
    Useful to model the effect of arithmetic or conversion overflow. *)


let to_bool (can_be_zero:bool) (can_be_one:bool) : t =
  match can_be_zero, can_be_one with
  | true, false -> zero
  | false, true -> one
  | true, true -> zero_one
  | _ -> failwith "unreachable case encountered in IntItv.to_bool"
(* helper function for operators returning a boolean that can be zero and/or one *)

let log_cast (ab:t) : t =
  to_bool (contains_zero ab) (contains_nonzero ab)
(** Conversion from integer to boolean in [0,1]: maps 0 to 0 (false) and non-zero to 1 (true). *)

let log_not (ab:t) : t =
  to_bool (contains_nonzero ab) (contains_zero ab)
(** Logical negation.
    Logical operation use the C semantics: they accept 0 and non-0 respectively as false and true, but they always return 0 and 1 respectively for false and true.
*)

let log_and (ab:t) (ab':t) : t =
  to_bool (contains_zero ab || contains_zero ab') (contains_nonzero ab && contains_nonzero ab')
(** Logical and. *)

let log_or (ab:t) (ab':t) : t =
  to_bool (contains_zero ab && contains_zero ab') (contains_nonzero ab || contains_nonzero ab')
(** Logical or. *)

let log_xor (ab:t) (ab':t) : t =
  let f,f' = contains_zero ab, contains_zero ab'
  and t,t' = contains_nonzero ab, contains_nonzero ab' in
  to_bool ((f && f') || (t && t')) ((f && t') || (t && f'))
(** Logical exclusive or. *)

let log_eq (ab:t) (ab':t) : t = to_bool (not (equal ab ab' && is_singleton ab)) (intersect ab ab')
let log_leq ((a,b):t) ((a',b'):t) : t = to_bool (B.gt b a') (B.leq a b')
let log_geq ((a,b):t) ((a',b'):t) : t = to_bool (B.lt a b') (B.geq b a')
let log_lt ((a,b):t) ((a',b'):t) : t = to_bool (B.geq b a') (B.lt a b')
let log_gt ((a,b):t) ((a',b'):t) : t = to_bool (B.leq a b') (B.gt b a')
let log_neq (ab:t) (ab':t) : t = to_bool (intersect ab ab') (not (equal ab ab' && is_singleton ab))
(** C comparison tests. Returns an interval included in [0,1] (a boolean) *)

let is_log_eq (ab:t) (ab':t) : bool = intersect ab ab'
let is_log_leq ((a,b):t) ((a',b'):t) : bool = B.leq a b'
let is_log_geq ((a,b):t) ((a',b'):t) : bool = B.geq b a'
let is_log_lt ((a,b):t) ((a',b'):t) : bool = B.lt a b'
let is_log_gt ((a,b):t) ((a',b'):t) : bool = B.gt b a'
let is_log_neq (ab:t) (ab':t) : bool = not (equal ab ab' && is_singleton ab)
(** C comparison tests. Returns a boolean if the test may succeed *)



let shift_left (ab:t) (ab':t) : t_with_bot =
  match positive ab' with
  | BOT -> BOT
  | Nb ab'' -> Nb (minmax4 B.shift_left ab ab'')
(** Bitshift left: multiplication by a power of 2. *)

let shift_right (ab:t) (ab':t) : t_with_bot =
  match positive ab' with
  | BOT -> BOT
  | Nb ab'' -> Nb (minmax4 B.shift_right ab ab'')
(** Bitshift right: division by a power of 2 rounding towards -∞. *)

let shift_right_trunc (ab:t) (ab':t) : t_with_bot =
  match positive ab' with
  | BOT -> BOT
  | Nb ab'' -> Nb (minmax4 B.shift_right_trunc ab ab'')
(** Unsigned bitshift right: division by a power of 2 with truncation. *)


let bit_not (ab:t) : t =
  pred (neg ab)
(** Bitwise negation: ~x = -x-1 *)


(**
  Note:
  The following bitwise operations are only precise for simple cases:
  singletons and booleans.
  They could be improved.
  See Hacker's Delight by Henry S. Warren Jr., 2nd ed., Sect. 4.3.
 *)

let bit_or (ab:t) (ab':t) : t =
  if included ab zero_one && included ab' zero_one then
    (* boolean case *)
    log_or ab ab'
  else
    match ab, ab' with
    | (B.Finite al, B.Finite ah), (B.Finite bl, B.Finite bh) ->
       (* finite cases *)
       if al=ah && bl=bh then
         (* singleton case *)
         cst (Z.logor al bl)
       else if is_positive ab && is_positive ab' then
         (* positive case *)
         B.Finite (Z.max al bl), B.Finite (Z.add ah bh)
       else
         (* general case *)
         minf_inf
    | _ ->
       (* infinite cases *)
       if is_positive ab && is_positive ab' then
         (* positive case *)
         zero_inf
       else
         (* general case *)
         minf_inf
(** Bitwise or (to be improved). *)

let bit_and (ab:t) (ab':t) : t =
  if included ab zero_one && included ab' zero_one then
    (* boolean case *)
    log_and ab ab'
  else
    match ab, ab' with
    | (B.Finite al, B.Finite ah), (B.Finite bl, B.Finite bh) ->
       (* finite cases *)
       if al=ah && bl=bh then
         (* singleton case *)
         cst (Z.logand al bl)
       else if is_positive ab && is_positive ab' then
         (* positive cases *)
         B.Finite Z.zero, B.Finite (Z.min ah bh)
       else if is_positive ab then
         B.Finite Z.zero, B.Finite ah
       else if is_positive ab' then
         B.Finite Z.zero, B.Finite bh
       else
         (* general case *)
         minf_inf
    | _ ->
       (* infinite cases *)
       if is_positive ab || is_positive ab' then
         (* positive case *)
         zero_inf
       else
         (* general case *)
         minf_inf
(** Bitwise and (to be improved). *)

let bit_xor (ab:t) (ab':t) : t =
  if included ab zero_one && included ab' zero_one then
    (* boolean case *)
    log_xor ab ab'
  else
    match ab, ab' with
    | (B.Finite al, B.Finite ah), (B.Finite bl, B.Finite bh) ->
       (* finite cases *)
       if al=ah && bl=bh then
         (* singleton case *)
         cst (Z.logxor al bl)
       else if is_positive ab && is_positive ab' then
         (* positive case *)
         B.Finite Z.zero, B.Finite (Z.add ah bh)
       else
         (* general case *)
         minf_inf
    | _ ->
       (* infinite cases *)
       if is_positive ab && is_positive ab' then
         (* positive case *)
         zero_inf
       else
         (* general case *)
         minf_inf
(** Bitwise exclusive or (to be improved). *)



(** {2 Filters} *)


(** Given two interval aruments, return the arguments assuming that the predicate holds.
 *)


let filter_leq ((a,b):t) ((a',b'):t) : (t*t) with_bot =
  bot_merge2 (of_bound_bot a (B.min b b')) (of_bound_bot (B.max a a') b')

let filter_geq ((a,b):t) ((a',b'):t) : (t*t) with_bot =
  bot_merge2 (of_bound_bot (B.max a a') b) (of_bound_bot a' (B.min b b'))

let filter_lt ((a,b):t) ((a',b'):t) : (t*t) with_bot =
  bot_merge2 (of_bound_bot a (B.min b (B.pred b'))) (of_bound_bot (B.max (B.succ a) a') b')

let filter_gt ((a,b):t) ((a',b'):t) : (t*t) with_bot =
  bot_merge2 (of_bound_bot (B.max a (B.succ a')) b) (of_bound_bot a' (B.min (B.pred b) b'))

let filter_eq ((a,b):t) ((a',b'):t) : (t*t) with_bot =
  match meet (a,b) (a',b') with BOT -> BOT | Nb x -> Nb (x,x)

let filter_neq ((a,b):t) ((a',b'):t) : (t*t) with_bot =
  match B.equal a b, B.equal  a' b' with
  | true, true  when B.equal a a' -> BOT
  | true, false when B.equal a a' -> bot_merge2 (Nb (a,b)) (of_bound_bot (B.succ a') b')
  | true, false when B.equal b b' -> bot_merge2 (Nb (a,b)) (of_bound_bot a' (B.pred b'))
  | false, true when B.equal a a' -> bot_merge2 (of_bound_bot (B.succ a) b) (Nb (a',b'))
  | false, true when B.equal b b' -> bot_merge2 (of_bound_bot a (B.pred b)) (Nb (a',b'))
  | _ -> Nb ((a,b),(a',b'))



(** {2 Backward operations} *)


(** Given one or two interval argument(s) and a result interval, return the
    argument(s) assuming the result in the operation is in the given result.
 *)

let bwd_default_unary (a:t) (r:t) : t_with_bot =
  Nb a
(** Fallback for backward unary operators *)

let bwd_default_binary (a:t) (b:t) (r:t) : (t*t) with_bot =
  Nb (a,b)
(** Fallback for backward binary operators *)

let bwd_neg (a:t) (r:t) : t_with_bot =
  meet a (neg r)

let bwd_abs (a:t) (r:t) : t_with_bot =
  join_bot (meet a r) (meet a (neg r))

let bwd_succ (a:t) (r:t) : t_with_bot =
  meet a (pred r)

let bwd_pred (a:t) (r:t) : t_with_bot =
  meet a (succ r)

let bwd_add (a:t) (b:t) (r:t) : (t*t) with_bot =
  (* r = a + b ⇒ a = r - b ∧ b = r - a *)
  bot_merge2 (meet a (sub r b)) (meet b (sub r a))

let bwd_sub (a:t) (b:t) (r:t) : (t*t) with_bot =
  (* r = a - b ⇒ a = b + r ∧ b = a - r *)
  bot_merge2 (meet a (add b r)) (meet b (sub a r))

let bwd_mul (a:t) (b:t) (r:t) : (t*t) with_bot =
  (* r = a * b ⇒ ((a = r / b) ∨ (b = r = 0)) ∧ ((b = r / a) ∨ (a = r = 0)) *)
  let aa = if contains_zero b && contains_zero r then Nb a else div r b
  and bb = if contains_zero a && contains_zero r then Nb b else div r a in
  bot_merge2 aa bb

let bwd_div ((a,a'):t) ((b,b'):t) (r:t) : (t*t) with_bot =
  (* r = a / b ⇒ (a = r * b + r % b) ∧ ((b = (a - r % b) / r) ∨ ((a - r % b) = r = 0)) *)
  (* m = max [b,b'] - 1 *)
  let m = B.pred (B.max (B.abs b) (B.abs b')) in
  (* md = approximate r % b *)
  let md =
    (if B.is_negative_strict a  then B.neg m else B.zero),
    (if B.is_positive_strict a' then m else B.zero)
  in
  (* aa = r * b + r % b *)
  let aa = meet (a,a') (add (mul r (b,b')) md) in
  (* (bb = a / r)  ∨ (bb = b ∧ (a - r % b) = r = 0)*)
  let ax = sub (a,a') md in
  let bb =
    if contains_zero ax && contains_zero r then Nb (b,b')
    else meet_bot (Nb (b,b')) (div ax r)
  in
  bot_merge2 aa bb

let bwd_pow = bwd_default_binary

let bwd_bit_not (a:t) (r:t) : t_with_bot =
  meet a (bit_not r)

let bwd_join (a:t) (b:t) (r:t) : (t*t) with_bot =
  bot_merge2 (meet a r) (meet b r)
(** Backward join: both arguments and intersected with the result. *)

let bwd_bit_xor (a:t) (b:t) (r:t) : (t*t) with_bot =
  bot_merge2 (meet a (bit_xor b r)) (meet b (bit_xor a r))
(** r = a xor b ⇒ a = r xor b ∧ b = r xor a. *)


let bwd_rem : t -> t -> t -> (t*t) with_bot= bwd_default_binary
let bwd_wrap (ab :t) range (r:t) : t_with_bot = bwd_default_unary ab r
let bwd_shift_left : t -> t -> t -> (t*t) with_bot = bwd_default_binary
let bwd_shift_right : t -> t -> t -> (t*t) with_bot = bwd_default_binary
let bwd_shift_right_trunc : t -> t -> t -> (t*t) with_bot = bwd_default_binary
let bwd_bit_or : t -> t -> t -> (t*t) with_bot = bwd_default_binary
let bwd_bit_and : t -> t -> t -> (t*t) with_bot = bwd_default_binary
let bwd_log_eq : t -> t -> t -> (t*t) with_bot = bwd_default_binary
let bwd_log_neq : t -> t -> t -> (t*t) with_bot = bwd_default_binary
let bwd_log_lt : t -> t -> t -> (t*t) with_bot = bwd_default_binary
let bwd_log_leq : t -> t -> t -> (t*t) with_bot = bwd_default_binary
let bwd_log_gt : t -> t -> t -> (t*t) with_bot = bwd_default_binary
let bwd_log_geq : t -> t -> t -> (t*t) with_bot = bwd_default_binary
(* TODO: more precise backward and, or, rem, shift, wrap *)

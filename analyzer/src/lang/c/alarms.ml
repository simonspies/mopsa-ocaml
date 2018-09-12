open Framework.Essentials
open Framework.Alarm

type token +=
  | TOutOfBound of Framework.Location.range
  | TNullDeref of Framework.Location.range
  | TInvalidDeref of Framework.Location.range

type alarm_kind +=
  | AOutOfBound
  | ANullDeref
  | AInvalidDeref

let () =
  register_token
    { print = (fun next fmt -> function
          | TOutOfBound r -> Format.fprintf fmt "TOutOfBound %a" Framework.Location.pp_range r
          | TNullDeref r -> Format.fprintf fmt "TNullDeref %a" Framework.Location.pp_range r
          | TInvalidDeref r -> Format.fprintf fmt "TInvalidDeref %a" Framework.Location.pp_range r
          | tk -> next fmt tk
        );
      compare = (fun next a b ->
          match a,b with
          | TOutOfBound x, TOutOfBound y -> Framework.Location.compare_range x y
          | TNullDeref x, TNullDeref y -> Framework.Location.compare_range x y
          | TInvalidDeref x, TInvalidDeref y -> Framework.Location.compare_range x y
          | _ -> next a b
        )
    };

  register_alarm
    {
      compare = (fun default a b -> match a.alarm_kind, b.alarm_kind with
          | AOutOfBound, AOutOfBound -> 0
          | ANullDeref, ANullDeref -> 0
          | AInvalidDeref, AInvalidDeref -> 0
          | _ -> default a b
        );
      print = (fun default fmt a -> match a.alarm_kind with
          | AOutOfBound -> Format.fprintf fmt "Out of bound access"
          | ANullDeref -> Format.fprintf fmt "Null dereference"
          | AInvalidDeref -> Format.fprintf fmt "Invalid dereference"
          | _ -> default fmt a
        )
    };

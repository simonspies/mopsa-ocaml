(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(** Build the global abstract domain from a json configuration file.

   The supported syntax for a [domain] is as follows:

    - a string denotes a leaf domain or a non-relational value abstraction.

    - [\{"functor": domain, "arg": domain\}] creates a functor domain 
    parameterized by an argument domain.

    - [\{"iter": \[domain list\]\}] uses the iterator composer to
    combine a list of domains in sequence.
    
    - [\{"product": \[string list\], "reductions": \[string list\]\}] 
    constructs a reduced product of a set of abstract domains and 
    non-relational value abstractions with some reduction rules 
*)


val parse : string -> (module Domain.DOMAIN)
(** [parse path] constructs an abstract domain from a configuration file *)

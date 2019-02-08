(****************************************************************************)
(*                   Copyright (C) 2017 The MOPSA Project                   *)
(*                                                                          *)
(*   This program is free software: you can redistribute it and/or modify   *)
(*   it under the terms of the CeCILL license V2.1.                         *)
(*                                                                          *)
(****************************************************************************)

(** Entry point of the analyzer. *)

open Framework


(** Call the appropriate frontend to parse the input sources *)
let parse_program lang files =
  Framework.Logging.phase "parsing";
  match lang with
  | "universal" -> Lang.Universal.Frontend.parse_program files
  | "c" -> Lang.C.Frontend.parse_program files
  | "python" -> Lang.Python.Frontend.parse_program files
  | _ -> Exceptions.panic "Unknown language"



(** Parse command line arguments and apply [f] on the list of target
   source files *)
let parse_options f () =
  let files = ref [] in
  let n = Array.length Sys.argv in
  let return_value = ref 0 in
  Arg.parse (Options.to_arg ()) (fun filename ->
      files := filename :: !files;
      if !Arg.current = n - 1 then
        return_value := !return_value * 10 + (f !files)
    ) "Modular Open Platform for Static Analysis";
  !return_value

(** Main entry point *)
let () =
  exit @@ parse_options (fun files ->
      try
        let lang, domain = Config.parse () in

        let prog = parse_program lang files in

        (* Top layer analyzer *)
        let module Domain = (val domain) in
        let module Analyzer = Analyzer.Make(Domain) in

        let t = Timing.start () in

        Framework.Logging.phase "computing initial environments";
        let flow = Analyzer.init prog in
        let stmt =
          Ast.mk_stmt (Ast.S_program prog) prog.prog_range
        in

        Framework.Logging.phase "starting the analysis";

        let res = Analyzer.exec stmt flow in
        let t = Timing.stop t in

        Output.Factory.render Analyzer.man res t files

      with
        e -> Output.Factory.panic ~btrace:(Printexc.get_backtrace()) e files; 2
    ) ()

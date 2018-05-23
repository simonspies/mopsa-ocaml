let init () =

  Objects.(
    Object.setup ();
    Class.setup ();
    Function.setup ();
    Number.setup ();
    Strings.setup ();
    Containers.(
      Lists.setup ();
      Dicts.setup ();
      Ranges.setup ();
      Sets.setup ();
      Tuples.setup ();
    );
    Data_model.(
      Attribute.setup ();
      Callable.setup ();
      Arith_ops.setup ();
      Subscript.setup ();
      Compare_ops.setup ();
    );
  );

  Flows.(
    Exceptions.setup ();
  );

  Desugar.(
    Bool.setup ();
    Assert.setup ();
    If.setup ();
    Import.setup ();
    Iterable_assign.setup ();
  );

  Libs.(
    Mopsa.setup ();
    Stdlib.setup ();
    Unittest.setup ();
  );

  Memory.(
    Nonrel.setup ();
  );

  Program.setup ();

  ()

let start () =
  Builtins.setup ();
  ()

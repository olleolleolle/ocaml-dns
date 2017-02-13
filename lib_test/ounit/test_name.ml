
open OUnit2

let cstruct_of ints =
  let buf = Buffer.create (List.length ints) in
  ints |> List.iter (fun i ->
    Buffer.add_char buf (Char.chr i));
  Cstruct.of_bytes (Buffer.contents buf)

open Dns
open Name

let tests =
  "Name" >:::
  [
    "parse-root-domain-name" >:: (fun test_ctxt ->
      let buf = cstruct_of [0x00] in
      let names = Hashtbl.create 32 in
      let name, (base,buf) = parse names 0 buf in
      assert_equal "" (Name.to_string name);
    );

    "parse-label-single" >:: (fun test_ctxt ->
      let buf = cstruct_of [
        0x03; 0x63; 0x6f; 0x6d;
        0x00
      ] in
      let names = Hashtbl.create 32 in
      let name, (base,buf) = parse names 0 buf in
      assert_equal "com" (Name.to_string name);
    );

    "parse-label-seq" >:: (fun test_ctxt ->
      let buf = cstruct_of [
        0x03; 0x66; 0x6f; 0x6f;
        0x03; 0x63; 0x6f; 0x6d;
        0x00
      ] in
      let names = Hashtbl.create 32 in
      let name, (base,buf) = parse names 0 buf in
      assert_equal "foo.com" (Name.to_string name);
    );

    "parse-pointer-to-root-domain" >:: (fun test_ctxt ->
      let buf = cstruct_of [
        0xff; (* padding *)
        0x00;
        0xc0; 0x01
      ] in
      let names = Hashtbl.create 32 in
      let buf = Cstruct.shift buf 1 in
      let name, (base,buf) = parse names 1 buf in
      let name, (base,buf) = parse names 2 buf in
      assert_equal "" (Name.to_string name);
    );

    "parse-pointer-to-label" >:: (fun test_ctxt ->
      let buf = cstruct_of [
        0x03; 0x63; 0x6f; 0x6d;
        0x00;
        0xc0; 0x00
      ] in
      let names = Hashtbl.create 32 in
      let name, (base,buf) = parse names 0 buf in
      let name, (base,buf) = parse names base buf in
      assert_equal "com" (Name.to_string name);
    );

    "parse-pointer-to-pointer-to-label" >:: (fun test_ctxt ->
      let buf = cstruct_of [
        0x03; 0x63; 0x6f; 0x6d;
        0x00;
        0xc0; 0x00;
        0xc0; 0x05
      ] in
      let names = Hashtbl.create 32 in
      let name, (base,buf) = parse names 0 buf in
      let name, (base,buf) = parse names base buf in
      let name, (base,buf) = parse names base buf in
      assert_equal "com" (Name.to_string name);
    );

    "parse-label-then-label-with-pointer-to-label" >:: (fun test_ctxt ->
      let buf = cstruct_of [
        0x03; 0x63; 0x6f; 0x6d;
        0x00;
        0x03; 0x66; 0x6f; 0x6f;
        0xc0; 0x00
      ] in
      let names = Hashtbl.create 32 in
      let name, (base,buf) = parse names 0 buf in
      let name, (base,buf) = parse names base buf in
      assert_equal "foo.com" (Name.to_string name);
    );

    "parse-pointer-to-self" >:: (fun test_ctxt ->
      let buf = cstruct_of [ 0xc0; 0x00 ] in
      let names = Hashtbl.create 32 in
      assert_raises
        (Failure "Name.parse_pointer: Cannot dereference pointer to (0) at position (0)")
        (fun () -> parse names 0 buf)
    );

    "parse-pointer-to-invalid-address" >:: (fun test_ctxt ->
      let buf = cstruct_of [ 0xc0; 0x0e ] in
      let names = Hashtbl.create 32 in
      assert_raises
        (Failure "Name.parse_pointer: Cannot dereference pointer to (14) at position (0)")
        (fun () -> parse names 0 buf)
    );

    "parse-pointer-cycle" >:: (fun test_ctxt ->
      let buf = cstruct_of [
        0xc0; 0x02;
        0xc0; 0x00
      ] in
      let names = Hashtbl.create 32 in
      assert_raises
        (Failure "Name.parse_pointer: Cannot dereference pointer to (2) at position (0)")
        (fun () -> parse names 0 buf)
    );

  ]

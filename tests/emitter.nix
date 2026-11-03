# SPDX-License-Identifier: MIT
{ pkgs, backend }:
let
  output = backend.makeHook {
    pkg = pkgs.hello;
    name = "proof";
  };
  invalid = builtins.tryEval (
    (backend.makeHook {
      pkg = pkgs.hello;
      name = "../escape";
    }).drvPath
  );
in
assert !invalid.success;
pkgs.runCommand "mkinitcpio-emitter" { } ''
  test -x ${output}/usr/lib/initcpio/install/proof
  test -x ${output}/usr/lib/initcpio/impurifiers/proof${pkgs.hello}/bin/hello
  test ! -e ${output}/usr/lib/initcpio/impurifiers/proof/nix/var/nix/db/db.sqlite
  touch "$out"
''

# SPDX-License-Identifier: MIT
{ pkgs, coreSrc }:
let
  inherit (pkgs) lib;
  core = import (coreSrc + "/nix") { inherit pkgs; };
  makeHook =
    {
      pkg,
      name ? "nix-${pkg.pname}",
      runtimeHook ? null,
    }:
    assert lib.assertMsg (
      builtins.match "[a-z][a-z0-9_-]*" name != null
    ) "invalid mkinitcpio hook name";
    let
      trees = map (pkg: core.makeNativePayload { inherit pkg; }) (
        [ pkg ] ++ lib.optional (runtimeHook != null) runtimeHook
      );
    in
    pkgs.runCommand "${name}-mkinitcpio-hook" { } ''
      root="$out/usr/lib/initcpio"
      mkdir -p "$root/hooks" "$root/install" "$root/impurifiers/${name}/nix/store"
      for tree in ${lib.escapeShellArgs (map toString trees)}; do
        for object in "$tree"/nix/store/*; do
          destination="$root/impurifiers/${name}/nix/store/$(basename "$object")"
          test -e "$destination" || test -L "$destination" || cp -a "$object" "$destination"
        done
      done
      ${lib.optionalString (
        runtimeHook != null
      ) ''cp ${runtimeHook} "$root/hooks/${name}"; chmod 755 "$root/hooks/${name}"''}
      cat > "$root/install/${name}" <<'SCRIPT'
      #!/bin/bash
      build() {
          local payload
          payload="$(dirname "''${BASH_SOURCE[0]}")/../impurifiers/${name}"
          local entry destination
          while IFS= read -r -d "" entry; do
              destination="''${entry#"$payload"}"
              if [[ -L "$entry" ]]; then
                  add_symlink "$destination" "$(readlink "$entry")" || return
              elif [[ -d "$entry" ]]; then
                  add_dir "$destination" || return
              else
                  add_file "$entry" "$destination" || return
              fi
          done < <(find "$payload/nix" -print0)
          ${lib.optionalString (runtimeHook != null) "add_runscript || return"}
      }
      help() { echo 'Embed the complete Nix-built runtime closure without target-side Nix.'; }
      SCRIPT
      chmod 755 "$root/install/${name}"
      install -Dm644 ${../LICENSE} "$out/usr/share/licenses/mkinitcpio-impurifier/LICENSE"
    '';
in
{
  inherit makeHook;
  nativeClient = import ./native.nix { inherit pkgs; };
}

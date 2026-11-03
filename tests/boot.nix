# SPDX-License-Identifier: MIT
{
  pkgs,
  impurifier,
  revision ? "1",
}:
let
  proof = pkgs.writeShellScriptBin "early-proof" ''
    test ! -e /sysroot/etc/os-release || exit 1
    test ! -e /nix/var/nix/db/db.sqlite || exit 1
    echo IMPURIFIER_EARLY_USERSPACE_OK:${revision} > /dev/console
  '';
  runtimeHook = pkgs.writeText "proof-runtime-hook" ''
    #!/usr/bin/ash
    run_earlyhook() {
      ${proof}/bin/early-proof || return 1
      ${pkgs.busybox}/bin/poweroff -f
    }
  '';
  hook = impurifier.makeHook {
    pkg = proof;
    name = "nixproof";
    inherit runtimeHook;
  };
  image =
    pkgs.runCommand "mkinitcpio-proof-initramfs"
      {
        nativeBuildInputs = [ impurifier.nativeClient ];
      }
      ''
        mkdir hooks
        cp -r ${impurifier.nativeClient}/lib/initcpio/{install,hooks} hooks/
        chmod -R u+w hooks
        cp -r ${hook}/usr/lib/initcpio/. hooks/
        printf 'MODULES=()\nBINARIES=()\nFILES=()\nHOOKS=(base nixproof)\nCOMPRESSION=gzip\n' > config
        mkinitcpio --nopost -D "$PWD/hooks" -c "$PWD/config" -k none -g "$out"
      '';
in
pkgs.runCommand "mkinitcpio-impurifier-boot"
  {
    nativeBuildInputs = [
      pkgs.qemu
      pkgs.python3
    ];
  }
  ''
    python3 ${./boot.py} ${pkgs.linuxPackages.kernel}/bzImage ${image} IMPURIFIER_EARLY_USERSPACE_OK:${revision}
    touch "$out"
  ''

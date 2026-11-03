# SPDX-License-Identifier: MIT
{ pkgs }:
pkgs.stdenvNoCC.mkDerivation {
  pname = "mkinitcpio";
  version = "42.2";
  src = import ./source.nix { inherit pkgs; };
  nativeBuildInputs = [
    pkgs.meson
    pkgs.ninja
    pkgs.pkg-config
    pkgs.makeWrapper
  ];
  buildInputs = [ pkgs.systemd ];
  dontAutoPatchShebangs = true;
  postPatch = ''
    substituteInPlace meson.build --replace-fail "run_command('tools/dist.sh', 'get-version', check: true).stdout().strip()" "'42.2'"
    substituteInPlace mkinitcpio --replace-fail 'export PATH="@BINDIR@:/bin"' 'export PATH="$PATH"'
    substituteInPlace install/base --replace-fail /usr/lib/initcpio/busybox ${pkgs.busybox}/bin/busybox
    patchShebangs mkinitcpio lsinitcpio
  '';
  preConfigure = ''
    mesonFlagsArray+=("--sysconfdir=$out/etc")
    export PATH=${pkgs.systemd}/lib/systemd:$PATH
  '';
  mesonFlags = [
    "-Dsystemd=disabled"
    "-Ddocs=false"
    "-Dalpm=false"
    "-Dpresets=false"
    "-Dkernel_install=false"
  ];
  postInstall = ''
    install -Dm644 ../LICENSE $out/share/licenses/mkinitcpio/LICENSE
  '';
  postFixup = ''
    wrapProgram $out/bin/mkinitcpio --prefix PATH : ${
      pkgs.lib.makeBinPath [
        pkgs.bash
        pkgs.coreutils
        pkgs.findutils
        pkgs.gnugrep
        pkgs.gnused
        pkgs.gawk
        pkgs.kmod
        pkgs.util-linux
        pkgs.file
        pkgs.cpio
        pkgs.gzip
        pkgs.zstd
        pkgs.xz
        pkgs.binutils
        pkgs.pax-utils
        pkgs.libarchive
      ]
    }
  '';
  meta.license = pkgs.lib.licenses.gpl2Only;
}

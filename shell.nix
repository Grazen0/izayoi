{
  pkgs ? import <nixpkgs> { },
}:
pkgs.mkShell {
  packages = with pkgs; [
    gtkwave
    iverilog
    xxd
  ];
}

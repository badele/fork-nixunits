{
  caps ? "[]"
, hostIp4 ? ""
, hostIp6 ? ""
, id
, interface ? ""
, ip4? ""
, ip4route? ""
, ip6? ""
, ip6route? ""
, nixpkgs? <nixpkgs>
, service? null
}:

let
  _modules = nixpkgs + "/nixos/modules";
  lib = pkgs.lib;
  pkgs = import nixpkgs {};

  caps_allow = builtins.fromJSON(caps);

  config = let
    _file =
      if service == null then
        global.fileNix id
      else
        let
          _custom = global.fileCustom service;
        in if builtins.pathExists _custom then
          _custom
        else
          global.fileService service;
  in
    if (builtins.pathExists _file) then
      builtins.trace ''Import : ${_file}'' import _file {inherit lib pkgs;}
    else let
       _ = lib.assertMgs (service != null) "Service undefined";
    in {
      services.${service}.enable = true;
    };

  global = import ./global.nix {inherit lib pkgs;};

  modules = [
    (_modules + "/misc/extra-arguments.nix")
    (_modules + "/misc/nixpkgs.nix")
    (_modules + "/system/boot/systemd.nix")
    (_modules + "/system/etc/etc.nix")
    (import ./tmpfiles.nix)
    (import ./dummy_options.nix)
    ({ config, lib, pkgs, ... }: {
      config = global.conf config.${global.moduleName};
      options = global.options // {
        boot.isContainer = lib.mkOption {
          type = lib.types.bool;
          default = true;
        };
      };
    })
    {
      ${global.moduleName}.${id} = {
        inherit caps_allow config;
        network = {
          inherit hostIp4 hostIp6 interface ip4 ip4route ip6 ip6route;
        };
      };
    }
  ];

  utils = import ./utils.nix;
in (
  lib.evalModules({
    inherit modules;
    specialArgs = {inherit pkgs;};
  })
).config.system.build.etc

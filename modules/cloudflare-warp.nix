{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.cloudflare-warp;
in
{
  disabledModules = [ "services/networking/cloudflare-warp.nix" ];

  options.services.cloudflare-warp = {
    enable = lib.mkEnableOption "Cloudflare One Client daemon";
    package = lib.mkPackageOption pkgs "cloudflare-warp" { };
    browserPaths = lib.mkOption {
      type = lib.types.listOf (lib.types.either lib.types.package lib.types.str);
      default = [];
      example = [ pkgs.chrome pkgs.firefox ];
      description = "Paths of browsers that can be used to login.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    networking.nftables.enable = true;

    systemd = {
      packages = [ cfg.package ];
      services.warp-svc.wantedBy = [ "multi-user.target" ];
      user.services.warp-taskbar = {
        path = cfg.browserPaths;
        wantedBy = [ "graphical-session.target" ];
      };
    };

    services.dbus.packages = [ cfg.package ];
  };

  meta.maintainers = [ (import ../../maintainers.nix).nightspacec ];
}

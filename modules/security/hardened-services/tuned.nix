{ hardening, pkgs, ... }:
let
    default = hardening.defaultProfile;
in
{
    services.tuned.enable = true;

    systemd.services.tuned = {
        unitConfig.JoinsNamespaceOf = "tuned-ppd.service";
        serviceConfig = hardening.mkService {
            PrivateDevices = true;

            ProtectControlGroups = false;
            ProtectKernelTunables = false;
            ProtectKernelModules = false;
            SystemCallFilter = default.SystemCallFilter ++ [ "@module" ];
            RestrictAddressFamilies = default.RestrictAddressFamilies ++ [ "AF_NETLINK" ];
            ReadWritePaths = [ /var/log/tuned /etc/tuned ];
        };
    };

    systemd.services.tuned-ppd = {
        unitConfig.JoinsNamespaceOf = "tuned.service";
        serviceConfig = hardening.mkService {
            PrivateDevices = true;

            RestrictAddressFamilies = default.RestrictAddressFamilies ++ [ "AF_NETLINK" ];
            ReadWritePaths = [ /var/log/tuned /etc/tuned ];
        };
    };

    # systemd needs /var/log/tuned and /etc/tuned to exist to set up namespaces
    systemd.services.make-tuned-dirs = {
        enable = true;
        before = [ "tuned-ppd.service" "tuned.service" ];
        wantedBy = [ "tuned-ppd.service" "tuned.service" ];
        description = "Make `tuned` state directories so setting up namespaces doesn't fail";
        serviceConfig = hardening.mkService {
            Type = "oneshot";
            ProtectSystem = false;
            ExecStart = "${pkgs.coreutils-full}/bin/mkdir -p /var/log/tuned /etc/tuned";
        };
    };
}


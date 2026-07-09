{ hardening, ... }:
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
}


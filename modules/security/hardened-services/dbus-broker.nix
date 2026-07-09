{ hardening, ... }:

{
    services.dbus.implementation = "broker";
    systemd.services.dbus-broker.serviceConfig = hardening.mkService {
        SystemCallFilter = hardening.defaultProfile.SystemCallFilter ++ [
            "@privileged"
        ];
    };
}

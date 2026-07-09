{ hardening, ... }:

{
    systemd.services.systemd-ask-password-wall.serviceConfig = hardening.mkService {
        PrivateDevices = true;
        DevicePolicy = "closed";
        SystemCallFilter = [
            "~@keyring"
            "~@swap"
            "~@clock"         
            "~@module"
            "~@obsolete"
            "~@cpu-emulation"
        ];
    };
}

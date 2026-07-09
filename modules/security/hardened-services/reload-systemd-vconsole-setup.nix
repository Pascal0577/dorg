
{ hardening, ... }:

{
    systemd.services.reload-systemd-vconsole-setup.serviceConfig = hardening.mkService {
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

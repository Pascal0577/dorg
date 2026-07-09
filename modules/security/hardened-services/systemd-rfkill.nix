{ hardening, ... }:

{
    systemd.services.systemd-rfkill.serviceConfig = hardening.mkService {};
}


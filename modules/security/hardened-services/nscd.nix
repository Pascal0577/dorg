{ hardening, ... }:

{
    systemd.services.nscd.serviceConfig = hardening.mkService {
        PrivateDevices = true;
    };
}


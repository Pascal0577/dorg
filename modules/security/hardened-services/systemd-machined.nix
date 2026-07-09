{ hardening, ... }:

{
    systemd.services.systemd-machined.serviceConfig = hardening.mkService {
        PrivateUsers = true;
        ProtectControlGroups = false;
    };
}

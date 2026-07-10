{ config, ... }:

{
    users.users.dorg = {
        hashedPasswordFile = config.sops.secrets."password".path;
        isNormalUser = true;
        extraGroups = [ "wheel" ];
    };
}

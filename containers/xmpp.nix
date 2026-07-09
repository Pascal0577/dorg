{ self, lib, ... }:
let
    hardening = import ../lib/hardened-service.nix { inherit lib; };
in
{
    networking.nat = {
        enable = true;
        internalInterfaces = [ "ve-xmpp" ];
        externalInterface = "eth0";
        forwardPorts = [{
            sourcePort = 80;
            proto = "tcp";
            destination = "10.0.0.2:8080";
        }];
    };

    networking.firewall = {
        allowedTCPPorts = [ 80 ];
        trustedInterfaces = [ "ve-xmpp" ];
    };

    containers.xmpp = {
        autoStart = true;
        ephemeral = false;
        privateNetwork = true;
        privateUsers = "pick";
        restartIfChanged = true;
        hostAddress = "10.0.0.1";
        localAddress = "10.0.0.2";
        specialArgs = { inherit hardening; };

        config = {
            imports = [ self.nixosModules.security ];

            services.prosody.enable = true;
        };
    };
}

{ self, lib, modulesPath, ... }:
let
    hardening = import ../lib/hardened-service.nix { inherit lib; };
in
{
    networking.firewall = {
        allowedTCPPorts = [ 80 ];
        trustedInterfaces = [ "ve-xmpp" ];
    };

    containers.xmpp = {
        autoStart = true;
        ephemeral = false;
        privateNetwork = true;
        restartIfChanged = true;
        hostAddress = "10.0.0.1";
        localAddress = "10.0.0.2";
        specialArgs = { inherit hardening; };

        forwardPorts = [{
            hostPort = 80;
            containerPort = 5280;
            protocol = "tcp";
        }];

        config = {
            imports = [
                { system.stateVersion = "26.05"; }
                self.nixosModules.security
                (modulesPath + "/profiles/minimal.nix")
                (modulesPath + "/profiles/headless.nix")
            ];

            services.prosody = {
                enable = true;
                xmppComplianceSuite = false;
            };
        };
    };
}

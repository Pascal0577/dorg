{ self, lib, modulesPath, ... }:
let
    hardening = import ../lib/hardened-service.nix { inherit lib; };
    domain = "xmpp.dorg.com";
    mucDomain = "conference.${domain}";
    uploadDomain = "upload.${domain}";
in
{
    networking.firewall = {
        allowedTCPPorts = [ 80 443 5281 5222 5269 ];
        trustedInterfaces = [ "ve-xmpp" ];
    };

    security.acme = {
        acceptTerms = true;
        defaults.email = ""; # TODO
        certs.${domain} = {
            group = "certs";
            webroot = "/var/lib/acme/acme-challenge";
            postRun = "nixos-container run xmpp -- systemctl reload prosody.service";
            extraDomainNames = [ mucDomain uploadDomain ];
        };
    };

    users.groups.certs.members = [ "nginx" "prosody" ];

    # We need nginx to serve the acme challenge files for domain verification
    services.nginx = {
        enable = true;
        virtualHosts.${domain} = {
            locations."/.well-known/acme-challenge".root = "/var/lib/acme/acme-challenge";
            locations."/".return = "404"; # not a real website
        };
    };

    containers.xmpp = {
        autoStart = true;
        ephemeral = false;
        privateNetwork = true;
        restartIfChanged = true;
        hostAddress = "10.0.0.1";
        localAddress = "10.0.0.2";
        specialArgs = { inherit hardening; };

        forwardPorts = [
            { hostPort = 5222; containerPort = 5222; protocol = "tcp"; } # c2s
            { hostPort = 5269; containerPort = 5269; protocol = "tcp"; } # s2s
            { hostPort = 5281; containerPort = 5281; protocol = "tcp"; } # BOSH/websocket (legacy_ssl)
        ];

        bindMounts = {
            "/certs" = {
                hostPath = "/var/lib/acme/${domain}";
                isReadOnly = false;
            };
            "/media" = {
                hostPath = "/srv/media";
                isReadOnly = false;
            };
        };

        config = {
            imports = [
                { system.stateVersion = "26.05"; }
                self.nixosModules.security
                (modulesPath + "/profiles/minimal.nix")
                (modulesPath + "/profiles/headless.nix")
            ];

            users.groups.certs.members = [ "nginx" "prosody" ];

            services.prosody = {
                enable = true;
                admins = [ "admin@${domain}" ];
                allowRegistration = false;

                ssl = {
                    cert = "/certs/fullchain.pem";
                    key = "/certs/key.pem";
                };

                httpFileShare = {
                    domain = uploadDomain;
                    uploadFileSizeLimit = 50 * 1024 * 1024; # 50 MB
                };

                muc = [{
                    domain = mucDomain;
                    name = "Chat Rooms";
                    restrictRoomCreation = false;
                }];

                virtualHosts.${domain} = {
                    inherit domain;
                    enabled = true;
                    ssl = {
                        cert = "/certs/fullchain.pem";
                        key = "/certs/key.pem";
                    };
                };

                modules = {
                    roster = true;
                    saslauth = true;
                    tls = true;
                    dialback = true;
                    disco = true;
                    carbons = true;
                    pep = true;
                    mam = true;
                    ping = true;
                    admin_adhoc = true;
                    http_files = true;
                };
            };
        };
    };
}

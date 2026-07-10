{ xmppFlake, lib, modulesPath, pkgs, ... }:
let
    hardening = import ../lib/hardened-service.nix { inherit lib; };
    uidOffset = 1000000;
    domain = "xmpp.dorg.com";
    mucDomain = "conference.${domain}";
    uploadDomain = "upload.${domain}";
in
{
    networking.firewall.allowedTCPPorts = [ 80 443 5281 5222 5269 ];
    networking.nat = {
        enable = true;
        internalInterfaces = [ "ve-xmpp" ];
        externalInterface = "eth0";
        forwardPorts = [
            { sourcePort = 5281; proto = "tcp"; destination = "10.0.0.2:5281"; }
            { sourcePort = 5222; proto = "tcp"; destination = "10.0.0.2:5222"; }
            { sourcePort = 5269; proto = "tcp"; destination = "10.0.0.2:5269"; }
        ];
    };

    security.acme = {
        acceptTerms = true;
        defaults.email = "pascalthederg@gmail.com";
        certs.${domain} = {
            group = "certs";
            webroot = "/var/lib/acme/acme-challenge";
            postRun = "nixos-container run xmpp -- systemctl reload prosody.service";
            extraDomainNames = [ mucDomain uploadDomain ];
        };
    };

    users.groups.certs.members = [ "nginx" ];
    users.groups.certs.gid = uidOffset + 999;

    # We need nginx to serve the acme challenge files for domain verification
    services.nginx = {
        enable = true;
        virtualHosts.${domain} = {
            locations."/.well-known/acme-challenge".root = "/var/lib/acme/acme-challenge";
            locations."/".return = "404"; # not a real website
        };
    };

    # Make sure root in container has proper perms
    systemd.services."container@xmpp".serviceConfig.ExecStartPre = [
        "${pkgs.writeShellScript "xmpp-container-chown" ''
            set -e
            DIR=/var/lib/nixos-containers/xmpp
            mkdir -p "$DIR"
            chown -R ${lib.toString uidOffset}:${lib.toString uidOffset} "$DIR"
        ''}"
    ];

    containers.xmpp = {
        autoStart = true;
        ephemeral = false;
        privateNetwork = true;
        privateUsers = uidOffset;
        restartIfChanged = true;
        hostAddress = "10.0.0.1";
        localAddress = "10.0.0.2";
        specialArgs = { inherit hardening; };

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
                xmppFlake.nixosModules.security
                (modulesPath + "/profiles/minimal.nix")
                (modulesPath + "/profiles/headless.nix")
            ];

            users.groups.certs.members = [ "prosody" ];
            users.groups.certs.gid = 999;

            networking.useHostResolvConf = lib.mkForce false;
            networking.firewall = {
                enable = true;
                allowedTCPPorts = [ 5222 5269 5281 ];
            };

            services.resolved = {
                enable = true;
                settings.Resolve = {
                    DNS = "9.9.9.9#dns.quad9.net";
                    FallbackDNS = "1.1.1.1#cloudflare-dns.com 8.8.8.8#dns.google";
                    DNSSEC = "allow-downgrade";
                    DNSOverTLS = true;
                };
            };

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

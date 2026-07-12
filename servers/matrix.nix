let
    domain = "matrix.dorg.com";
    certs = "/var/lib/acme/acme-challenge";
in
{
    users.groups.certs.members = [ "nginx" ];
    security.acme = {
        acceptTerms = true;
        defaults.email = "pascalthederg@gmail.com";
        certs.${domain} = {
            group = "certs";
            webroot = certs;
            postRun = "systemctl restart tuwunel.service";
        };
    };

    # We need nginx to serve the acme challenge files for domain verification
    services.nginx = {
        enable = true;
        virtualHosts.${domain} = {
            locations."/.well-known/acme-challenge".root = "/var/lib/acme/acme-challenge";
            locations."/_matrix".proxyPass = "http://127.0.0.1:6167";
            locations."/_synapse/client".proxyPass = "http://127.0.0.1:6167";
            locations."/".return = "404"; # not a real website

            forceSSL = true;
            sslCertificate = "${certs}/cert.pem";
            sslCertificateKey = "${certs}/key.pem";
        };
    };

    services.matrix-tuwunel = {
        enable = true;

        settings.global = {
            server_name = domain;
            address = [ "127.0.0.1" "::1" ];
            port = [ 6167 ];

            allow_federation = false;

            allow_registration = true;
            registration_token = "my_string";
            allow_encryption = true;

            max_request_size = 50 * 1024 * 1024;

            trusted_servers = [ ];
        };
    };
}

{
    systemd.network.enable = true;

    networking = {
        hostName = "dorg";
        useNetworkd = true;
        firewall = {
            enable = true;
            allowedTCPPorts = [ 22 ];
        };
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

    systemd.network.networks."10-wired" = {
        matchConfig.Name = "enp1s0";
        networkConfig = {
            DHCP = "yes";
            IPv6AcceptRA = true;
        };
        ipv6AcceptRAConfig = {
            UseAutonomousPrefix = true;
            Token = "prefixstable";
        };
        dhcpV4Config.RouteMetric = 10;
        linkConfig.RequiredForOnline = "routable";
    };

    # refuse to handle virtual devices
    systemd.network.networks."10-ve" = {
        matchConfig.Name = "ve-*";
        networkConfig = {
            DHCP = "no";
            LinkLocalAddressing = "no";
        };
    };
}

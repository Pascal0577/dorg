{ inputs, ... }:

{
    imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

    boot.lanzaboote = {
        enable = true;
        pkiBundle = "/var/lib/sbctl";
        autoGenerateKeys.enable = true;
        autoEnrollKeys.enable = true;
    };
}

# More work needs to be done if we want to enable secure boot.
# sudo nix-shell -p sbctl
# sudo sbctl create-keys
# Clear all the secure boot keys in the UEFI and enable secure boot there
# sudo sbctl enroll-keys --microsoft
# Re-enable secure boot in UEFI if needed

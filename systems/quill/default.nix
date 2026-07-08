{ modulesPath, ... }:

{
    imports = [
        # ./disk-layout.nix TODO
        (modulesPath + "/profiles/minimal.nix")
        (modulesPath + "/profiles/perlless.nix")
        (modulesPath + "/profiles/headless.nix")
    ];
}

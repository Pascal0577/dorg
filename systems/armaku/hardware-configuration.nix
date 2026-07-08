{
    nixpkgs.hostPlatform = "x86_64-linux";    
    hardware.cpu.amd.updateMicrocode = true;
    hardware.enableRedistributableFirmware = true;

    boot.initrd = {
        availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usb_storage" "sd_mod" ];
        kernelModules = [ "dm-snapshot" ];
    };
}

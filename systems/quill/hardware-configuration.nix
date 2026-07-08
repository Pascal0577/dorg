{
    nixpkgs.hostPlatform = "x86_64-linux";    
    hardware.cpu.intel.updateMicrocode = true;
    hardware.enableRedistributableFirmware = true;

    boot.initrd = {
        availableKernelModules = [ "xhci_pci" "nvme" "usbhid" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
        kernelModules = [ "dm-snapshot" ];
    };
}

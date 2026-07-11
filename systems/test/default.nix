{ lib, self, ... }:

{
    imports = [
        ./disk-layout.nix
        self.nixosModules.xmpp
    ];

    # Fix VM stuff
    boot = {
        initrd.systemd.emergencyAccess = true;
        zfs.devNodes = "/dev/disk/by-partlabel";
        zfs.requestEncryptionCredentials = false;

        kernelParams = lib.mkForce [
            "panic=0"
            "vga=0x317"
            "nomodeset"
            "rcupdate.rcu_expedited=1"
            "page_alloc.shuffle=1"
            "console=ttyS0,115200"
            "console=tty0"
            "nohibernate"
            "root=fstab"
            "loglevel=4"
            "lsm=landlock,yama,bpf"
            "systemd.debug_shell=1"
        ];    
    };
}

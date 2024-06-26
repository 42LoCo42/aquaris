{ modulesPath, ... }: {
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "usbhid" ];
  boot.kernelModules = [ "kvm-intel" ];

  networking.interfaces.enp6s0.useDHCP = true;
  nixpkgs.hostPlatform = "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = true;
}

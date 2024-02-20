({ pkgs, lib, ... }:
let initial = pkgs.writeText "initial-password" "password"; in {
  imports = [ (import ./disk.nix { inherit initial; }) ];

  # this fixes occasional "failures" of zfs-mount
  systemd.services."zfs-mount".serviceConfig.Restart = "on-failure";

  fileSystems."/boot".neededForBoot = true;

  boot.initrd.systemd = {
    initrdBin = with pkgs; [ clevis jose tpm2-tools ];
    services.zfs-import-rpool.script = lib.mkForce ''
      zpool status rpool || zpool import -N rpool
      read -r _ _ key _ < <(zfs get -H keylocation rpool/nixos)
      if [[ "$key" =~ initial ]]; then
        zfs load-key rpool/nixos
      else
        clevis decrypt < /sysroot/boot/primary | zfs load-key rpool/nixos
      fi
    '';
  };

  system.activationScripts.zfs-manage-initial-key.text = ''
    shopt -s expand_aliases
    alias zfs="${pkgs.zfs}/bin/zfs"
    read -r _ _ key _ < <(zfs get -H keylocation rpool/nixos)
    if [[ "$key" =~ initial ]]; then
      echo "[1;31mWARNING: ZFS is using the initial key![m"
      cp "${initial}" /boot/initial
      zfs set keylocation=file:///sysroot/boot/initial rpool/nixos
    else
      echo "[1;32mZFS is using the secure key![m"
    fi
  '';

  systemd.services.zfs-manage-primary-key = {
    requiredBy = [ "default.target" ];
    path = with pkgs; [ clevis mokutil zfs ];
    script = ''
      if mokutil --sb-state | grep enabled; then
        read -r _ _ key _ < <(zfs get -H keylocation rpool/nixos)
        if [[ "$key" =~ initial ]]; then
          echo "Switching to a secure ZFS key..."
          head -c 64 /dev/urandom | clevis encrypt tpm2 '{"pcr_bank":"sha256","pcr_ids":"7"}' > /boot/primary
          clevis decrypt < /boot/primary | zfs change-key rpool/nixos -o keylocation=prompt
          rm -f /boot/initial
        fi
      fi
    '';
  };
})

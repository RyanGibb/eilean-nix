
# TODO generate this from `nixos-generate-config`
{
  boot.loader.grub.device = "/dev/sda";
  fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };
}


# Setup

This guide walks a user through the first time setup of a server running Eilean.

If you already have a NixOS system and want to use Eilean you can add to your configuration.
Note this requires a flake-enabled system.
Add `github:RyanGibb/eilean-nix` as an input to your flake, and import `eilean.nixosModules.default`.
You should then be able to use the configuration options in `config.eilean`.
See [../template/flake.nix](../template/flake.nix) for an example.

Otherwise, some familiarity with networking, operating systems, and Linux is necessary.
And some familiarity with Nix is beneficial.

## Step 1: Find a server

- Option 1 (recommended): a Virtual Private Server (VPS) with a cloud provider such as Hetzner, Vultr, or Digital Ocean. Get an IPv4 address[^1].
You can use this referral link to get started on Hetzner: https://hetzner.cloud/?ref=XydbkWdf49TY.

- Option 2: your own hardware, such as an old PC or laptop, Raspberry Pi, or a custom-build server.
Note you'll need a static IPv4[^1] address for reliable hosting[^2]. If you're behind Network Address Translation (NAT) you'll need to set up port forwarding for every service you want to run.

The resource requirements depend on the number of services you want to run, and the load they'll be under.
With no services 10 GiB of disk space and 1 GiB of RAM is plenty, though you may want to enable swap if you have low memory.
With all services enabled and fairly populated databases 40 GiB of disk space and 2 GiB of RAM is appropriate.

[^1]: You could just use an IPv6 address, but much of the Internet is still [IPv4-only](https://stats.labs.apnic.net/ipv6).

[^2]: If you don't have a static address, Dynamic DNS is possible but takes some time to propagate. Email reputation is tied to your IP address; using a residential address assigned by your ISP may get your mail blocked.

Resource requirements depend on how many services you want to run and how much load they'll be under, but 2 GiB RAM and 20 GiB disk should be a good starting point.

## Step 2: Install NixOS with Eilean

Most service providers don't offer a NixOS image, so we'll install it manually.

- Create the server with a generic linux distribution such as Debian.
- Mount the NixOS ISO, either from your provider directly, or by uploading it yourself. For Herzner:
    - Create a new instance and power it off
    - Switch to the ISO-Images tab and mount the NixOS minimal ISO
    - Open the remote console (>_ button) and power the machine on
    - Follow the usual installation guide
    - Unmount the ISO and reboot
- Install NixOS.

The [official manual](https://nixos.org/manual/nixos/stable/index.html#sec-installation-manual) contains detailed instructions, but the minimum to get your disk partioned is:
```
DISK=/dev/sda

parted $DISK -- mklabel gpt
parted $DISK -- mkpart ESP fat32 1MB 512MB
parted $DISK -- mkpart primary 512MiB 100%
parted $DISK -- set 1 esp on
mkfs.fat -F 32 -n boot ${DISK}1
mkfs.ext4 -L nixos ${DISK}2
```

We can then mount the primary and boot partions and generate a configuration for you (possible virtualised) hardware:
```
mount /dev/disk/by-label/nixos /mnt
mkdir /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot
nixos-generate-config --root /mnt
```

It's possible to install Nix with the default configuration at this point.
However, Eilean comes with a simple template that's recommended to get you started:
```
cd /mnt/etc/nixos
rm configuration.nix
nix flake init -t github:RyanGibb/eilean-nix
```

Note that we are using the `hardware-configuration.nix` generated by `nixos-generate-config`.

Eilean uses [flakes](https://www.tweag.io/blog/2020-05-25-flakes/).
Without going into too much depth, they enable hermetic evaluation of Nix expressions and provide a standard way to compose Nix projects[^3].

[^3]: [tweag.io/blog/2020-05-25-flakes](https://www.tweag.io/blog/2020-05-25-flakes/).

You can edit the resulting `configuration.nix`.
Check out the `TODO`'s for a place to start.
The website [search.nixos.org](https://search.nixos.org/) is a great place to find information on configuration options and packages available, and with `man 5 configuration.nix` you can see the configuration options locally.
One thing you should do at this point is generate a password hash with `mkpasswd` and add it to `root.initialHashedPassword`.

Now, we can install NixOS and reboot:
```
nixos-install --root /mnt/ --flake /mnt/etc/nixos#eilean --no-root-passwd
reboot
```

Upon boot you should be able to login as root.
You may need to run `passwd <username>` (where `<username>` is `eilean` by default) to be able to log in as `<username>`[^4].
You should be able to edit `/etc/nixos/configuration.nix` and rebuild you system with `sudo nixos-rebuild switch`.

[^4]: [github.com/NixOS/nixpkgs/issues/55424](https://github.com/NixOS/nixpkgs/issues/55424)

By default, DHCP will be enabled, so your machine will discover its IP address, however some providers don't enable DHCPv6 or SLAAC, so you need to manually configure the IP address.
For example a Hetzner VPS IPv6 address can be found in the networking tab and enabled with:
```
  networking = {
    interfaces."enp1s0" = {
      ipv6.addresses = [{
        address = "<address>";
        prefixLength = 64;
      }];
    };
    defaultGateway6 = {
      address = "fe80::1";
      interface = "enp1s0";
    };
  };
```

Replace `enp1s0` with your network interface (try `ip addr`).

It's recommended to track `/etc/nixos` in a git repository.
Note that untracked files aren't seen by Nix flakes, so `git add` any new files you create to use them in Nix.
It may be useful to change the user and group from root so your user account can edit these files:
```
sudo chgrp -R eilean /etc/nixos
sudo chgrp -R users /etc/nixos
```

Eilean creates a set of NixOS modules under `eilean`.
Check out the default configuration, and files in [modules](../modules/), to see what options there are.
(Documentation and man pages are on the way).

## Step 3: Get a Domain

From your favourite registrar, e.g. [gandi.net](https://www.gandi.net/), purchase a domain.
Eilean automates Domain Name System (DNS) record creation and maintence by hosting DNS on the server and managing records decleratively.

Create a Glue record with your registrar with `ns1.<domain>` pointing to your public IP address from step 1.
Next, add this as an external nameserver.

If your domain TLD requires two nameservers, you can create a duplicate `ns2.<domain>`.
If you use a domain name other than this pattern, be sure to update `eilean.dns.nameservers`.

You may need to wait up to 24 hours for DNS records to propagate at this point.

You can check if this is working with:
```
dig <domain>
```

## Step 4: Configure Eilean

Once your domain is set up, replace these default values of Eilean with your IPv4 and IPv6 network addresses, and your public network interface:
```
  eilean.serverIpv4 = "203.0.113.0";
  eilean.serverIpv6 = "2001:DB8:0:0:0:0:0:0";
  eilean.publicInterface = "enp1s0";
```

You should be able to get these from `ip addr`.

Set `eilean.username` to what you want your username to be on email, matrix, and any other services.
A first name might be a good choice.

Now, enable services at will!
It's a good idea to enable one service at a time initially or else if you run into issues, e.g. DNS record propitiation, then you may get rate limited by Let's Encrypt for TLS certificate provisioning.

## Further Information 

For a list of options, use `man eilean-configuration.nix`.


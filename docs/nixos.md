
# NixOS

[NixOS](nixos.org) is a Linux distribution built with [Nix](./nix.md) from a modular, purely functional specification.
It has no traditional filesystem hierarchy (FSH), like `/bin`, `/lib`, `/usr`, but instead stores all components in `/nix/store`.
The system configuration is managed by Nix and configured with Nix expressions.
[NixOS modules](https://nixos.org/manual/nixos/stable/index.html#sec-writing-modules) are Nix files containing chunks of system configuration that can be composed to build a full NixOS system.
While many NixOS modules are provided in the [Nixpkgs](./nixpkgs.md) repository, they can also be written by an individual user.
For example, the expression used to deploy a DNS server is a NixOS module.
Together these modules form the configuration which builds the Linux system as a Nix derivation.

NixOS minimises global mutable state that -- without knowing it -- you might rely on being set up in a certain way.
For example, you might follow instructions to run a series of shell commands and edit some files to get a piece of software working.
You may subsequently be unable to reproduce the result because you've forgotten some intricacy or are now using a different version of the software.
Nix forces you to encode this in a reproducible way, which is extremely useful for replicating software configurations and deployments, aiming to solve the 'It works on my machine' problem.
Docker is often used to fix this configuration problem, but Nix aims to be more reproducible.

Nix provides safe and reliable atomic upgrades and rollbacks.
And every new system configuration build creates a GRUB entry, so you can boot previous systems even from your UEFI/BIOS.

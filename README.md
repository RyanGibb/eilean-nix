
# Eilean 🏝️

Eilean enables you to host your own digital 'island', where you control you're own online infrastructure.
The use of federated protocols allows you to 'bridge' your island to others.

Eilean uses [NixOS](https://nixos.org/) to enable reproducible deployments of services such as webservers, mailservers, federated communication servers, Virtual Private Network servers, and more.
However, they still require a lot of manual configuration for domain names, DNS records, user accounts, databases, HTTP proxies, TLS certificates, and more.

Eilean aims to be a optioned framework to allow the simple deployment of these services on a single machine, and a library of documentation for common issues in managing runtime state like secrets, databases, and upgrades.

By using Nix Eilean modules are extensive to other configurations outside this deployment scenario, such as offloading a particularly resource heavy service to a dedicated machine.

Contributions for additional services welcome.

For instructions on getting started see [docs/getting_started.md](./docs/getting_started.md).

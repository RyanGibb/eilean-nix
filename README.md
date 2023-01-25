Warning: work in progress.

# Eilean

Create your own digital island powered by Nix.

Self hosting is hard.
There's a lot of complexity to manage.

While NixOS enables reproducible deployments of many services, they still require much manual configuration.
Adding domain names, DNS records, user accounts, databases, HTTP proxies, SMTP servers all add additional complexity.

Eilean aims to be a personal or community 'island in a box' that requires minimal configuration.
It can achieve this by sharing configration between many NixOS modules (each for an individuial service).

### Usage

Some familiarity with Nix is required. 

TODO...

##### Networking

Requires a public IPv4 and IPv6 address.

##### DNS

Hosting DNS allows necessary records to be specified decleratively and enabled when the module that required then is.
You will need to point your domain's NS record to your IP address with your registar using a glue record.

need to update SOA serial No

##### Email

Hosting email allows for an easy, and cheap, SMTP server for services that require it.
Recieving EMail shouldn't pose an issues.
Sending email to users on your own domain shouldn't pose any issues, if for example users are signing up to services like Mastodon using an EMail account on the same Eilean.
Sending mail will require TCP port 25 to be unblocked by your network provider, and your IP address to not be blacklisted (e.g. check [here](https://mxtoolbox.com/blacklists.aspx)).


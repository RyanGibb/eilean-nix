{
  lib,
  buildGoModule,
  fetchFromGitHub,
  olm,
}:

let
  version = "0.4.4";
in
buildGoModule rec {
  name = "mautrix-meta";
  inherit version;

  src = fetchFromGitHub {
    owner = "mautrix";
    repo = "meta";
    rev = "v${version}";
    hash = "sha256-S8x3TGQEs+oh/3Q1Gz00M8dOcjjuHSgzVhqlbikZ8QE=";
  };

  buildInputs = [ olm ];

  vendorHash = "sha256-sUnvwPJQOoVzxbo2lS3CRcTrWsPjgYPsKClVw1wZJdM=";

  doCheck = false;

  excludedPackages = "cmd/lscli";

  meta = with lib; {
    homepage = "https://github.com/mautrix/meta";
    description = " A Matrix-Facebook Messenger and Instagram DM puppeting bridge.";
    license = licenses.agpl3Plus;
    mainProgram = "mautrix-meta";
  };
}

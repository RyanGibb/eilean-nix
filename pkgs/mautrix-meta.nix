{ lib, buildGoModule, fetchFromGitHub, olm }:

buildGoModule rec {
  name = "mautrix-meta";

  src = fetchFromGitHub {
    owner = "mautrix";
    repo = "meta";
    rev = "7941e937055b792d2cbfde5d9c8c4df75e68ff0a";
    hash = "sha256-QDqN6AAaEngWo4UxKAyIXB7BwCEJqsMTeuMb2fKu/9o=";
  };

  buildInputs = [ olm ];

  vendorHash = "sha256-ClHg3OEKgXYsmBm/aFKWZXbaLOmKdNyvw42QGhtTRik=";

  doCheck = false;

  excludedPackages = "cmd/lscli";

  meta = with lib; {
    homepage = "https://github.com/mautrix/meta";
    description =
      " A Matrix-Facebook Messenger and Instagram DM puppeting bridge.";
    license = licenses.agpl3Plus;
    mainProgram = "mautrix-meta";
  };
}


{
  lib,
  fetchgit,
  callPackage,
  ...
}:

let
  version = "1.0.0";

  src = fetchgit {
    url = "https://git.gay/QueerResourcesRiga/gancio-plugin-discord.git";
    rev = "v${version}";
    hash = "sha256-R9o5bU9mVHCLcxhCv5jTz334CVG9D/9rWdeFVGVVR1Q=";
  };

  # Use upstream provided package.nix
  package = callPackage "${src}/package.nix" { };
in
package
// {
  meta = {
    description = "Gancio plugin for Discord, sends events to Discord";
    homepage = "https://git.gay/QueerResourcesRiga/gancio-plugin-discord";
    license = lib.licenses.agpl3Plus;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ gearkite ];
  };
}

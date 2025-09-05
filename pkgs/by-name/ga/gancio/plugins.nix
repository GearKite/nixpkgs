{ callPackage, nodejs }:
{
  discord-bridge = callPackage ./plugin-discord-bridge { inherit nodejs; };
  telegram-bridge = callPackage ./plugin-telegram-bridge { inherit nodejs; };
}

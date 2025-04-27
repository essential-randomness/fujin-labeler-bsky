{
  lib,
  writeScriptBin,
  buildNpmPackage,
  nodejs_22,
  makeWrapper,
  ...
}:  let
  package-json = lib.importJSON (lib.snowfall.fs.get-file "package.json");
in
  buildNpmPackage {
    pname = "fujin-bsky-labeler";
    inherit (package-json) version;

    src = lib.snowfall.fs.get-file "/";
    
    npmDepsHash = "sha256-0F/3Cd+CQOP4nIpDkDnFq+7LumspGN0Brwdbq8If1zo=";

    nodejs = nodejs_22;

    dontNpmBuild = true;

    nativeBuildInputs = [makeWrapper];

    postInstall = ''
      makeWrapper ${nodejs_22}/bin/node $out/bin/fujin-bsky-labeler --add-flags $out/lib/node_modules/fujin-bsky-labeler/node_modules/.bin/tsx --add-flags $out/lib/node_modules/fujin-bsky-labeler/src/main.ts
    '';
  }

{
  lib,
  rustPlatform,
  path,
  nix,
  nixVersions,
  lixVersions,
  clippy,
  makeWrapper,

  nixVersionsToTest ? [
    nix
    nixVersions.stable
    nixVersions.minimum
    nixVersions.latest
    lixVersions.stable
    lixVersions.latest
  ],

  initNix,
  version,
}:
let
  fs = lib.fileset;
in
rustPlatform.buildRustPackage {
  pname = "nixpkgs-vet";
  inherit version;

  src = fs.toSource {
    root = ./.;
    fileset = fs.unions [
      ./Cargo.lock
      ./Cargo.toml
      ./src
      ./tests
    ];
  };

  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [
    clippy
    makeWrapper
  ];

  env.NIXPKGS_VET_NIX_PACKAGE = lib.getBin nix;
  env.NIXPKGS_VET_NIXPKGS_LIB = "${path}/lib";

  checkPhase = ''
    # This path will be symlinked to the current version that is being tested
    nixPackage=$(mktemp -d)/nix

    # For initNix
    export PATH=$nixPackage/bin:$PATH

    # This is what nixpkgs-vet uses
    export NIXPKGS_VET_NIX_PACKAGE=$nixPackage

    ${lib.concatMapStringsSep "\n" (nix: ''
      ln -s ${lib.getBin nix} "$nixPackage"
      echo "Testing with $(nix --version)"
      ${initNix}
      runHook cargoCheckHook
      rm "$nixPackage"
    '') (lib.unique nixVersionsToTest)}

    # --tests or --all-targets include tests for linting
    cargo clippy --all-targets -- -D warnings
  '';
  postInstall = ''
    wrapProgram $out/bin/nixpkgs-vet \
      --set NIXPKGS_VET_NIX_PACKAGE ${lib.getBin nix}
  '';
}

{ pkgs, database_name, mixRelease, beamPackages, hex, elixir }:

let
  platformSpecificInputs = with pkgs;
    lib.optional stdenv.isLinux inotify-tools
    ++ lib.optionals stdenv.isDarwin (with darwin.apple_sdk.frameworks; [
      CoreFoundation
      CoreServices
    ]);
in
pkgs.mkShell {
  name = "live-beats-shell";

  inputsFrom = [ mixRelease ];

  buildInputs = [
    elixir
    hex
    beamPackages.elixir_ls
    pkgs.mix2nix
    pkgs.nixpkgs-fmt
    pkgs.nixpkgs-lint
    pkgs.rnix-lsp
    pkgs.docker
    pkgs.postgresql
    pkgs.gzip
  ] ++ platformSpecificInputs;

  shellHook = ''
    # Generic shell variables
    export LANG=en_US.utf-8
    export ERL_AFLAGS="-kernel shell_history enabled"
    export PHX_HOST=localhost
    export FLY_APP_NAME=live_beats
    export RELEASE_COOKIE=UnsecureTestOnlyCookie

    # Postgres
    export DATABASE_URL=ecto://postgres:postgres@localhost:5432/${database_name}
    export POOL_SIZE=15

    # Scope Mix and Hex to the project directory
    mkdir -p .nix-mix
    mkdir -p .nix-hex
    export MIX_PATH=${beamPackages.hex}/lib/erlang/lib/hex/ebin
    export MIX_HOME="$PWD/.nix-mix"
    export HEX_HOME="$PWD/.nix-hex"
    export PATH="$MIX_HOME/bin:$PATH"
    export PATH="$HEX_HOME/bin:$PATH"
  '';
}

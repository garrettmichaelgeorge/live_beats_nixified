{ pkgs, database_name, mixRelease, beamPackages, hex, elixir }:

let
  platformSpecificInputs = with pkgs;
    lib.optional stdenv.isLinux inotify-tools
    ++ lib.optionals stdenv.isDarwin (with darwin.apple_sdk.frameworks; [
      CoreFoundation
      CoreServices
    ]);

  myPostgres = pkgs.postgresql_14;

  # Overmind Procfile
  # https://github.com/DarthSim/overmind#overmind-environment
  overmindProcfile = pkgs.writeText "Procfile" ''
    db: ${myPostgres}/bin/postgres -k /tmp
  '';
in
pkgs.mkShell {
  name = "live-beats-shell";

  inputsFrom = [ mixRelease ];

  buildInputs = [
    beamPackages.elixir_ls
    beamPackages.hex
    beamPackages.rebar3
    elixir
    myPostgres
    pkgs.docker
    pkgs.gzip
    pkgs.mix2nix
    pkgs.nixpkgs-fmt
    pkgs.nixpkgs-lint
    pkgs.overmind
    pkgs.rnix-lsp
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
    export PGDATA="$PWD/pgdata"
    export PG_LOGFILE="$PGDATA/server.log"

    # Scope Mix and Hex to the project directory
    mkdir -p .nix-mix
    mkdir -p .nix-hex
    export MIX_PATH=${beamPackages.hex}/lib/erlang/lib/hex/ebin
    export MIX_HOME="$PWD/.nix-mix"
    export HEX_HOME="$PWD/.nix-hex"
    export PATH="$MIX_HOME/bin:$PATH"
    export PATH="$HEX_HOME/bin:$PATH"

    # Overmind
    export OVERMIND_PROCFILE="${overmindProcfile}"

    cat <<EOF

    Welcome to the LiveBeats development shell! 

    To initialize the database:

        nix run .#initdb

    To start local services in the background, including the database:

        overmind start -D

    To stop local services:

        overmind stop

    To fetch Mix deps:

        mix deps.get

    To start the app in development:
        
        iex -S mix phx.server

    Make sure to set LIVE_BEATS_GITHUB_CLIENT_ID and
    LIVE_BEATS_GITHUB_CLIENT_SECRET before compiling the app in MIX_ENV=prod.

    EOF
  '';
}

{ pkgs }:

pkgs.mkShell {
  name = "live-beats-shell";
  buildInputs = [
    pkgs.beam.packages.erlangR24.elixir_1_12
    pkgs.beam.packages.erlangR24.elixir_ls
    pkgs.mix2nix
    pkgs.postgresql_14
    pkgs.nixpkgs-fmt
    pkgs.nixpkgs-lint
    pkgs.rnix-lsp
  ] ++ pkgs.lib.optional pkgs.stdenv.isLinux pkgs.inotify-tools
  ++ pkgs.lib.optionals pkgs.stdenv.isDarwin
    (with pkgs.darwin.apple_sdk.frameworks; [
      CoreFoundation
      CoreServices
    ]);

  shellHook = ''
    # Generic shell variables
    # Postgres environment variables
    export PGDATA=$PWD/postgres_data
    export PGHOST=$PWD/postgres
    export LOG_PATH=$PWD/postgres/LOG
    export PGDATABASE=postgres
    export DATABASE_URL="postgresql:///postgres?host=$PGHOST"

    if [ ! -d $PWD/postgres ]; then
      mkdir -p $PWD/postgres
    fi

    if [ ! -d $PGDATA ]; then
      echo 'Initializing postgresql database...'
      initdb $PGDATA --auth=trust >/dev/null
    fi

    # As an example, you can run any CLI commands to customize your development shell
    # pg_ctl start -l $LOG_PATH -o "-p 5432 -c listen_addresses='*' -c unix_socket_directories=$PWD/postgres -c unix_socket_permissions=0700"
    # psql -p 5435 postgres -c 'create extension if not exists postgis' || true

    # This creates mix variables and data folders within your project, so as not to pollute your system
    mkdir -p .nix-mix
    mkdir -p .nix-hex
    export MIX_HOME=$PWD/.nix-mix
    export HEX_HOME=$PWD/.nix-hex
    export PATH=$MIX_HOME/bin:$PATH
    export PATH=$HEX_HOME/bin:$PATH
  '';
}

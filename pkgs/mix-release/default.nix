{ self, pkgs }:

with pkgs;
let
  pname = "live-beats";
  version = "0.1.0";

  # `self` refers to the root of the project.
  src = self;

  beamPackages = beam.packages.erlangR25;
  hex = beamPackages.hex.override { inherit elixir; };

  elixir = beamPackages.elixir_1_14;
  # To override the Elixir version, uncomment the following
  # elixir = beamPackages.elixir.override {
  #   version = "1.14.4";
  #   sha256 = "sha256-mV40pSpLrYKT43b8KXiQsaIB+ap+B4cS2QUxUoylm7c=";
  # };

  # Set locale for Erlang VM
  # https://nixos.org/manual/nixpkgs/unstable/#locales
  # https://github.com/NixOS/nixpkgs/blob/fd531dee22c9a3d4336cc2da39e8dd905e8f3de4/pkgs/development/libraries/glibc/locales.nix#L10
  glibcLocalesScoped =
    lib.optional stdenv.isLinux (glibcLocales.override {
      allLocales = false;
      locales = [ "en_US.UTF-8/UTF-8" ];
    });

in
# https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/beam-modules/mix-release.nix
beamPackages.mixRelease {
  inherit pname version src elixir hex;

  mixEnv = "prod";

  mixFodDeps = beamPackages.fetchMixDeps {
    pname = "mix-deps-${pname}";
    inherit src version;
    sha256 = "sha256-JYdArhEP6t0nBchiEwpCxZUeB3M0lRfqVpLu7sy09Uw=";
    # Default is "prod"; an empty string includes all dependencies (dev, test,
    # prod, etc.)
    mixEnv = "test";
  };

  compileFlags = [ "--warnings-as-errors" ];

  nativeBuildInputs = [
    esbuild
    nodePackages.tailwindcss
    makeWrapper
  ] ++ glibcLocalesScoped;

  buildInputs = [
    coreutils
    gnused
    locale
    openssl
  ] ++ glibcLocalesScoped;

  passthru = { inherit beamPackages; };

  MIX_ESBUILD_PATH = esbuild;
  MIX_TAILWIND_PATH = nodePackages.tailwindcss;
  # MIX_PATH = "${beamPackages.hex}/lib/erlang/lib/hex/ebin";

  # FIXME: re-enable this after debugging
  doCheck = false;

  # Starts a PostgreSQL server during the checkPhase
  # https://nixos.org/manual/nixpkgs/unstable/#sec-postgresqlTestHook
  nativeCheckInputs = [ postgresql postgresqlTestHook ];

  # PGHOST = "localhost";
  # PGDATABASE = "postgres";
  # PGUSER = "postgres";

  postgresqlTestSetupSQL = ''
    -- Perform the default setup since we are overwriting the setup SQL
    CREATE ROLE "$PGUSER" $postgresqlTestUserOptions;
    CREATE DATABASE "$PGDATABASE" OWNER '$PGUSER';

    -- Set the default encoding to 'UNICODE' to avoid compatibility errors
    -- See https://stackoverflow.com/a/16737776/12344822

    -- First, we need to drop template1. Templates can’t be dropped, so we first
    -- modify it so it’s an ordinary database
    UPDATE pg_database SET datistemplate = FALSE WHERE datname = 'template1';

    -- Drop template1
    DROP DATABASE template1;

    -- Create a database from template0, with a new default encoding
    CREATE DATABASE template1 WITH TEMPLATE = template0 ENCODING = 'UNICODE';

    -- Modify template1 so it’s actually a template
    UPDATE pg_database SET datistemplate = TRUE WHERE datname = 'template1';

    -- Switch to template1 and VACUUM FREEZE the template:
    \c template1
    VACUUM FREEZE;
  '';

  checkPhase = ''
    runHook preCheck

    set -x
    MIX_ENV=test mix ecto.create
    MIX_ENV=test mix ecto.migrate
    MIX_ENV=test mix test --warnings-as-errors
    set +x

    runHook postCheck
  '';

  # For external task you need a workaround for the no deps check flag.
  # https://github.com/phoenixframework/phoenix/issues/2690
  # You can also add any post-build steps here. It's just bash!
  postBuild = ''
    # TODO: fix tailwind and esbuild
    # mix do deps.loadpaths --no-deps-check, tailwind default --minify
    # mix do deps.loadpaths --no-deps-check, esbuild default --minify

    mix phx.digest --no-deps-check
  '';

  postInstall = ''
    shopt -s extglob
    for script in $out/bin/!(*.bat); do
      echo "Wrapping Mix-generated script $out/bin/$script to include system"
      echo "dependencies in the PATH"

      wrapProgram "$script" \
        --suffix PATH : ${lib.makeBinPath [ coreutils gawk gnused ]}
    done
  '';

  meta = {
    homepage = "https://github.com/fly-apps/live_beats";
    description = "Play music together with Phoenix LiveView!";
    license = lib.licenses.mit;

    mainProgram = "server";
  };
}

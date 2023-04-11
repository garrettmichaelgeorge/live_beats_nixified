{ self, pkgs, mixNixDeps }:

with pkgs;
let
  beamPackages = beam.packages.erlangR24;
  hex = beamPackages.hex.override { inherit elixir; };

  elixir = beamPackages.elixir.override {
    version = "1.14.4";
    sha256 = "sha256-mV40pSpLrYKT43b8KXiQsaIB+ap+B4cS2QUxUoylm7c=";
  };

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
  pname = "live-beats";
  version = "0.1.0";

  # `self` refers to the root of the project.
  src = self;

  MIX_ENV = "prod";

  inherit elixir hex mixNixDeps;

  compileFlags = [ "--warnings-as-errors" ];

  nativeBuildInputs = [
    esbuild
    nodePackages.tailwindcss
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

  # For external task you need a workaround for the no deps check flag.
  # https://github.com/phoenixframework/phoenix/issues/2690
  # You can also add any post-build steps here. It's just bash!
  postBuild = ''
    # TODO: fix tailwind and esbuild
    # mix do deps.loadpaths --no-deps-check, tailwind default --minify
    # mix do deps.loadpaths --no-deps-check, esbuild default --minify

    mix phx.digest --no-deps-check
  '';

  meta = {
    homepage = "https://github.com/fly-apps/live_beats";
    description = "Play music together with Phoenix LiveView!";
    license = lib.licenses.mit;

    mainProgram = "bin/server";
  };
}


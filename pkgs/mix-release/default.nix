{ self, pkgs }:

with pkgs;
let
  beamPackages = beam.packages.erlangR24;
  elixir = beamPackages.elixir.override {
    version = "1.14.4";
    sha256 = "sha256-mV40pSpLrYKT43b8KXiQsaIB+ap+B4cS2QUxUoylm7c=";
  };
  hex = beamPackages.hex.override { inherit elixir; };
in
beamPackages.mixRelease {
  pname = "live-beats";
  version = "0.1.0";

  # `self` refers to the root of the project.
  src = self;

  MIX_ENV = "prod";

  inherit elixir hex;

  compileFlags = [ "--warnings-as-errors" ];

  LANG = "C.utf8";
  LANGUAGE = "en_US:en";
  LC_ALL = "C.utf8";

  mixNixDeps = import ./../deps { inherit lib beamPackages; };

  nativeBuildInputs = [
    esbuild
    nodePackages.tailwindcss
  ];

  buildInputs = [
    coreutils
    gnused
    locale
    openssl
  ];

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


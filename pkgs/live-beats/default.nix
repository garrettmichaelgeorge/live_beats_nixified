{ self, pkgs }:

with pkgs;
let
  # the default beam.interpreters.erlang attribute defaults to the most recent available version in nixpkgs
  # to use a different version, you can use beam.interpreters.erlangR23, for example
  beamPackages = beam.packagesWith beam.interpreters.erlangR24;
in
beamPackages.mixRelease rec {
  pname = "live-beats";
  version = "0.0.0";
  # "self" defaults to the root of your project.
  # amend the path if it is non-standard with `self + "/src";`, for example
  src = self;
  MIX_ENV = "prod";
  mixNixDeps = import ./../deps { inherit lib beamPackages; };

  # flox will create a "fixed output derivation" based on
  # the total package of fetched mix dependencies, identified by a hash
  # mixFodDeps = packages.fetchMixDeps {
  #   inherit version src;
  #   pname = "live-beats";
  #   # nix will complain when you build, since it can't verify the hash of the deps ahead of time.
  #   # In the error message, it will tell you the right value to replace this with
  #   sha256 = lib.fakeSha256;
  #   # sha256 = "sha256-5Fn9K4fhyNp3EeSZrvD/aj++WG3uCqBm3oQrTzA2xhk=";

  #   # If you have build time environment variables, you should add them here
  #   # MY_VAR="value";
  #   buildInputs = [ ];

  #   propagatedBuildInputs = [ ];
  # };

  # For phoenix framework you can uncomment the lines below.
  # For external task you need a workaround for the no deps check flag.
  # https://github.com/phoenixframework/phoenix/issues/2690
  # You can also add any post-build steps here. It's just bash!
  # postBuild = ''
  # mix do deps.loadpaths --no-deps-check, phx.digest
  # mix phx.digest --no-deps-check
  # mix do deps.loadpaths --no-deps-check
  #'';
}


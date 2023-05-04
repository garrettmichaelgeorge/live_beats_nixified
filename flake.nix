{
  description = "Play music together with Phoenix LiveView!";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          imageName = "live-beats-nix";
          dockerNetworkName = "live-beats-net";

          pkgs = import nixpkgs { inherit system; };
          pkgsLinux = import nixpkgs { system = "x86_64-linux"; };

          mixRelease = pkgs.callPackage ./pkgs/mix-release { inherit self; };
          mixReleaseLinux = pkgsLinux.callPackage ./pkgs/mix-release { inherit self; };

          beamPackages = mixRelease.passthru.beamPackages;
          hex = mixRelease.hex;
          elixir = mixRelease.elixir;
        in
        rec {
          packages = {
            inherit mixRelease mixReleaseLinux;
            default = packages.mixRelease;

            image = pkgsLinux.callPackage ./pkgs/image {
              name = imageName;
              mixReleaseLinux = packages.mixReleaseLinux;
            };
          };

          apps =
            let
              # Build image and load it into Docker
              loadImage = pkgs.writeShellApplication {
                name = "load-image";
                runtimeInputs = with pkgs; [ nix docker gzip packages.image ];
                text = ''
                  set -euxo pipefail
                  zcat ${packages.image} | docker load
                '';
              };

              # Run the container on a user-defined Docker bridge network
              runContainer = pkgs.writeShellApplication {
                name = "run-container";
                runtimeInputs = with pkgs; [ docker loadImage ];
                text = ''
                  set -euxo pipefail

                  load-image

                  docker run \
                    --rm \
                    --name ${imageName} \
                    --network ${dockerNetworkName} \
                    --env-file .env \
                    --pull never \
                    --tty \
                    --interactive \
                    --publish 4000:4000 \
                    ${imageName}
                '';
              };

              # Connect to the locally running app container
              connectContainer = pkgs.writeShellApplication {
                name = "connect-container";
                runtimeInputs = with pkgs; [ docker ];
                text = ''
                  set -euxo pipefail
                  containerId="$(docker ps | grep '${imageName} ' | cut -d' ' -f 1)"
                  docker exec -it "$containerId" bash
                '';
              };

              # Initialize local Postgres cluster for development
              # Needed before running `overmind start`
              initdb = pkgs.writeShellApplication {
                name = "initdb";
                runtimeInputs = with pkgs; [ postgresql ];
                text = ''
                  set -eux
                  PGDATA="./pgdata"
                  POSTGRES_USER="postgres"

                  stopDb() {
                    pg_ctl stop
                  }
                  trap stopDb EXIT

                  if [[ ! -d "$PGDATA" ]]; then
                    initdb "$PGDATA"
                  fi

                  pg_ctl start

                  createuser --createdb --superuser "$POSTGRES_USER" || \
                    echo "database user $POSTGRES_USER already exists, skipping"

                  createdb "$PGDATA" || \
                      echo "database $PGDATA already exists, skipping"
                '';
              };

              # Bootstrap local database; like `mix ecto.create` without Mix
              bootstrapdb = pkgs.writeShellApplication {
                name = "bootstrapdb";
                runtimeInputs = with pkgs; [ postgresql ];
                text = builtins.readFile ./bootstrapdb.sh;
              };

              # Start Postgres in a container
              startdbContainer = pkgs.writeShellApplication {
                name = "startdb-container";
                runtimeInputs = with pkgs; [ docker ];
                # FIXME: need to mount bootstrapdb script in a reproducible way 
                text = ''
                  set -euxo pipefail

                  docker run \
                    --name live-beats-db \
                    --publish 5432:5432 \
                    --env-file .env \
                    --rm \
                    --volume pgdata:/var/lib/postgresql/data \
                    --volume bootstrapdb.sh:/docker-entrypoint-initdb.d/bootstrapdb.sh \
                    --network ${dockerNetworkName} \
                    postgres
                '';
              };

              mkApp = program: { inherit program; type = "app"; };
            in
            {
              loadImage = mkApp "${loadImage}/bin/load-image";
              runContainer = mkApp "${runContainer}/bin/run-container";
              connectContainer = mkApp "${connectContainer}/bin/connect-container";
              bootstrapdb = mkApp "${bootstrapdb}/bin/bootstrapdb";
              initdb = mkApp "${initdb}/bin/initdb";
              startdbContainer = mkApp "${startdbContainer}/bin/startdb-container";
            };

          devShells.default = import ./pkgs/dev-shell {
            inherit pkgs beamPackages hex elixir mixRelease;
            database_name = "live_beats_prod";
          };

          checks.mixRelease = packages.mixRelease;
          formatter = pkgs.nixpkgs-fmt;
        });
}

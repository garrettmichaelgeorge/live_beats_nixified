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
          database_name = "live_beats_prod";

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

            bootstrapdb = pkgs.writeShellApplication {
              name = "bootstrapdb.sh";
              runtimeInputs = with pkgs; [ postgresql ];
              text = builtins.readFile ./bootstrapdb.sh;
            };

            # Start Postgres in a container
            startdb = pkgs.writeShellApplication {
              name = "startdb";
              runtimeInputs = with pkgs; [ docker packages.bootstrapdb ];
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

            # Build image and load it into Docker
            loadImage = pkgs.writeShellApplication {
              name = "load-image";
              runtimeInputs = with pkgs; [ nix docker gzip packages.image ];
              text = ''
                set -euxo pipefail
                zcat ${packages.image} | docker load
              '';
            };

            connectContainer = pkgs.writeShellApplication {
              name = "connect-to-container";
              runtimeInputs = with pkgs; [ docker packages.runContainer ];
              text = ''
                set -euxo pipefail
                containerId="$(docker ps | grep '${packages.image.imageName} ' | cut -d' ' -f 1)"
                docker exec -it "$containerId" bash
              '';
            };
          };

          apps = {
            # Run the container on a user-defined Docker bridge network
            runContainer =
              let
                runContainer = pkgs.writeShellApplication {
                  name = "run-container";
                  runtimeInputs = with pkgs; [ docker packages.loadImage ];
                  text = ''
                    set -euxo pipefail

                    load-image

                    docker run \
                      --rm \
                      --name ${packages.image.imageName} \
                      --network ${dockerNetworkName} \
                      --env-file .env \
                      --pull never \
                      --tty \
                      --interactive \
                      --publish 4000:4000 \
                      ${packages.image.imageName}
                  '';
                };
              in
              {
                type = "app";
                program = "${runContainer}/bin/run-container";
              };
          };

          devShells.default = import ./pkgs/dev-shell {
            inherit pkgs beamPackages hex elixir mixRelease database_name;
          };

          checks.mixRelease = packages.mixRelease;
          formatter = pkgs.nixpkgs-fmt;
        }
      );
}




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

          mix-release = pkgs.callPackage ./pkgs/mix-release { inherit self; };
          beamPackages = mix-release.passthru.beamPackages;
          hex = mix-release.hex;
          elixir = mix-release.elixir;
        in
        rec {
          packages = {
            inherit mix-release;
            default = packages.mix-release;

            mix-release-linux = pkgsLinux.callPackage ./pkgs/mix-release { inherit self; };

            image = pkgsLinux.callPackage ./pkgs/image {
              name = imageName;
              mix-release-linux = packages.mix-release-linux;
            };

            # Start Postgres in a container
            startdb = pkgs.writeShellApplication {
              name = "startdb";
              runtimeInputs = with pkgs; [ docker ];
              text = ''
                set -euxo pipefail
                docker run \
                  --name live-beats-db \
                  --publish 5432:5432 \
                  --env-file .env \
                  --rm \
                  -v pgdata:/var/lib/postgresql/data \
                  --network ${dockerNetworkName} \
                  postgres
              '';
            };

            # Build image and load it into Docker
            build-image = pkgs.writeShellApplication {
              name = "build-image";
              runtimeInputs = with pkgs; [ nix docker gzip ];
              text = ''
                set -euxo pipefail
                nix build .#image
                zcat result | docker load
              '';
            };

            # Run the container on a user-defined Docker bridge network
            container = pkgs.writeShellApplication {
              name = "container";
              runtimeInputs = with pkgs; [ docker ];
              text = ''
                set -euxo pipefail
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

            connect-to-container = pkgs.writeShellApplication {
              name = "connect-to-container";
              runtimeInputs = with pkgs; [ docker ];
              text = ''
                set -euxo pipefail
                containerId="$(docker ps | grep '${imageName} ' | cut -d' ' -f 1)"
                docker exec -it "$containerId" bash
              '';
            };
          };

          devShells.default = import ./pkgs/dev-shell {
            inherit pkgs beamPackages hex elixir mix-release;
            database_name = "live_beats_prod";
          };

          checks = { mix-release = packages.mix-release; };

          formatter = pkgs.nixpkgs-fmt;
        });
}

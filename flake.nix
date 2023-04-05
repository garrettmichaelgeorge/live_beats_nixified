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
          containerName = "live-beats-nix";
          dockerNetworkName = "live-beats-net";
          pkgs = import nixpkgs { inherit system; };
          pkgsLinux = import nixpkgs { system = "x86_64-linux"; };
          # lastCommitDate = builtins.substring 0 8 self.lastModifiedDate;

          # needed for container/host resolution
          # nsswitch-conf = pkgs.writeTextFile {
          #   name = "nsswitch.conf";
          #   # text = "hosts: dns files";
          #   text = ''
          #     passwd:         files
          #     group:          files
          #     shadow:         files
          #     gshadow:        files

          #     hosts:          files dns
          #     networks:       files

          #     protocols:      db files
          #     services:       db files
          #     ethers:         db files
          #     rpc:            db files

          #     netgroup:       nis
          #   '';
          #   destination = "/etc/nsswitch.conf";
          # };
        in
        rec {
          packages = {
            default = packages.mix-release;

            mix-release = pkgs.callPackage ./pkgs/mix-release { inherit pkgs self; };
            mix-release-linux = pkgs.callPackage ./pkgs/mix-release { inherit self; pkgs = pkgsLinux; };

            image = pkgsLinux.dockerTools.buildImage {
              name = containerName;
              tag = "latest";
              created = "now";

              config =
                {
                  Env = [
                    "LANG=C.utf8"
                    "LANGUAGE=en_US:en"
                    "LC_ALL=C.utf8"
                  ] ++ pkgs.lib.optional pkgs.stdenv.isLinux [
                    # IPV6 is only supported in Linux-based hosts.
                    # Note this is a limitation of the Docker daemon, not
                    # containers per se.
                    # See https://docs.docker.com/config/daemon/ipv6/
                    "ECTO_IPV6=true"
                    "ERL_AFLAGS='-proto_dist inet6_tcp'"
                  ];
                  Cmd = [ "${packages.mix-release-linux}/bin/server" ];
                  # TODO: symlink the nix store path for the app to a global one like /app
                  # For now, when connecting to the container, Elixir release
                  # commands can be accessed via e.g.
                  #   bin/live_beats remote
                  #   bin/live_beats rpc "IO.inspect(LiveBeats.some_function())"
                  # See https://hexdocs.pm/mix/Mix.Tasks.Release.html#module-running-the-release
                  WorkingDir = "${packages.mix-release-linux}";
                };

              # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/build-support/buildenv/default.nix
              copyToRoot = pkgsLinux.buildEnv {
                name = "image-root";
                paths = with pkgsLinux; [
                  bashInteractive # Provide the BASH shell
                  cacert # X.509 certificates of public CA's
                  coreutils # Basic utilities expected in GNU OS's
                  curl # CLI tool for transferring files via URLs
                  dockerTools.binSh
                  dockerTools.caCertificates
                  dockerTools.fakeNss
                  dockerTools.usrBinEnv
                  glibcLocales # Locale information for the GNU C Library
                  gnused
                  iana-etc # IANA protocol and port number assignments
                  iproute # Utilities for controlling TCP/IP networking
                  iputils # Useful utilities for Linux networking
                  locale
                  openssl
                  utillinux # System utilities for Linux
                  which
                ];
                pathsToLink = [ "/bin" "/etc" "/var" ];
              };

              # Note: runAsRoot requires kvm in the builder system
              # runAsRoot = ''
              #  #!${pkgsLinux.stdenv.shell}
              #  ${pkgsLinux.dockerTools.shadowSetup}
              #  export PATH=/bin:/usr/bin:/sbin:/usr/sbin:$PATH
              #  groupadd -r nobody
              #  useradd -r -g nobody
              #  chown nobody /app
              #  sed -i '/C.utf8/s/^# //g' /etc/locale.gen && locale-gen
              #  ln -s "${packages.mix-release-linux}" /app
              #'';
            };

            # Start Postgres in a container
            startdb = pkgs.writeShellApplication {
              name = "startdb";
              runtimeInputs = [ pkgs.docker ];
              text = ''
                docker run \
                --name live-beats-db \
                --publish 5432:5432 \
                --env-file .env \
                --rm \
                -v pg_data:/var/lib/postgresql/data \
                --network ${dockerNetworkName} \
                postgres
              '';
            };

            connect-to-container = pkgs.writeShellApplication {
              name = "connect-to-container";
              runtimeInputs = [ pkgs.docker ];
              text = ''
                set -euxo pipefail
                containerId="$(docker ps | grep '${containerName} ' | cut -d' ' -f 1)"
                docker exec -it "$containerId" bash
              '';
            };

            # Build image and load it into Docker
            build-image = pkgs.writeShellApplication {
              name = "build-image";
              runtimeInputs = [ pkgs.nix pkgs.docker pkgs.gzip ];
              text = ''
                set -euxo pipefail
                nix build .#image
                zcat result | docker load
              '';
            };

            # Run the container on a user-defined Docker bridge network
            container = pkgs.writeShellApplication {
              name = "container";
              runtimeInputs = [ pkgs.docker ];
              text = ''
                set -euxo pipefail
                docker run \
                  --rm \
                  --name ${containerName} \
                  --network ${dockerNetworkName} \
                  --env-file .env \
                  --pull never \
                  --tty \
                  --interactive \
                  --publish 4000:4000 \
                  ${containerName}
              '';
            };
          };

          devShells = {
            default = devShells.dev;

            dev = import ./pkgs/dev-shell {
              inherit pkgs;
              inputsFrom = [ packages.mix-release ];
              db_name = "live_beats_dev";
              # MIX_ENV = "dev";
            };
            # test = import .pkgs/dev-shell {
            #   inherit pkgs;
            #   db_name = "db_test";
            #   MIX_ENV = "test";
            # };
            # prod = import .pkgs/dev-shell {
            #   inherit pkgs;
            #   db_name = "db_prod";
            #   MIX_ENV = "prod";
            # };
          };

          checks = {
            flake-build = packages.default;

            test = pkgs.runCommandLocal "test-hello" { } ''
              # ${packages.default}/bin/${packages.default.name} > $out
              mix test
            '';
          };

          formatter = pkgs.nixpkgs-fmt;
        });
}

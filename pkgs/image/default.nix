# Build the Phoenix app inside a Docker image
# Note for now, this requires a Linux-based builder.
# Users of macOS Darwin can use a NixOS VM via `nix run nixpkgs#darwin.builder`.
# See https://nixos.org/manual/nixpkgs/unstable/#sec-darwin-builder

{ pkgs, name, mixReleaseLinux }:

# https://nixos.org/manual/nixpkgs/unstable/#sec-pkgs-dockerTools
pkgs.dockerTools.buildImage {
  name = name;
  tag = "latest";
  created = "now";

  # https://github.com/moby/moby/blob/master/image/spec/v1.2.md#image-json-field-descriptions
  config =
    {
      Cmd = [ "${mixReleaseLinux}/bin/server" ];
      Env = [
        "LANG='C.utf8'"
        "LANGUAGE='en_US:en'"
        "LC_ALL='C.utf8'"
      ]
        # FIXME: ipv6 features need to be configured at runtime, not build time
        # ++ pkgs.lib.optional pkgs.stdenv.isLinux [
        #   # IPV6 is only supported in Linux-based hosts.
        #   # Note this is a limitation of the Docker daemon, not
        #   # containers per se.
        #   # See https://docs.docker.com/config/daemon/ipv6/
        #   "ECTO_IPV6='true'"
        #   "ERL_AFLAGS='-proto_dist inet6_tcp'"
        # ]
      ;
      # TODO: symlink the nix store path for the app to a global one like /app
      # For now, when connecting to the container, Elixir release
      # commands can be accessed via e.g.
      #   bin/live_beats remote
      #   bin/live_beats rpc "IO.inspect(LiveBeats.some_function())"
      # See https://hexdocs.pm/mix/Mix.Tasks.Release.html#module-running-the-release
      WorkingDir = "${mixReleaseLinux}";
    };

  # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/build-support/buildenv/default.nix
  copyToRoot = pkgs.buildEnv {
    name = "image-root";
    paths = with pkgs; [
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

  # NOTE: runAsRoot requires kvm in the builder system
  # runAsRoot = ''
  #  #!${pkgs.stdenv.shell}
  #  ${pkgs.dockerTools.shadowSetup}
  #  export PATH=/bin:/usr/bin:/sbin:/usr/sbin:$PATH
  #  groupadd -r nobody
  #  useradd -r -g nobody
  #  chown nobody /app
  #  sed -i '/C.utf8/s/^# //g' /etc/locale.gen && locale-gen
  #  ln -s "${mixReleaseLinux}" /app
  #'';
}

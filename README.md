# LiveBeats Nixified

This is a proof of concept for using Nix in a real-world Phoenix project. Try it out and see what you think!

It adds Nix configuration around a well-known reference Phoenix app called [LiveBeats](https://github.com/fly-apps/live_beats), which you can demo at [livebeats.fly.dev](https://github.com/fly-apps/live_beats).

In this project, Nix is used to:
- Manage a development environment with `nix develop`, including language versions and all system dependencies
  - All standard Elixir project commands should work inside of this environment, e.g. `mix test`
- Manage all CI/CD dependencies (with a couple of exceptions that are specific to GitHub Actions)
- Package a number of utility scripts that can be run with `nix run .#name-of-script`
  - These are essentially Bash scripts with dependencies built in, so they should "just work" on any Unix-based machine
- Build a Mix release of the project with `nix build`
- Build a Docker image with the Mix release inside with `nix build .#image`

Essentially, in this project, Nix is configured to manage things up until the point where a deployable artifact is created. At that point, the image can be deployed using a deployment tool of choice, like Terraform with AWS ECS. For now, deployment is not implemented in this project.

For more on this approach, see [this article](https://determinate.systems/posts/nix-to-kubernetes).

## Prerequisites

- Nix with flakes enabled (I recommend [this installer](https://zero-to-nix.com/start/install)). 
- (Optional) [direnv](https://direnv.net/#getting-started) for convenience when working with Nix
- (Optional) Postgres
  - While this repo's Nix development environment does include Postgres, some developers prefer not to use the Postgres CLI directly. If that is you, you can manage Postgres using an alternate method of your choice (like [this one](https://postgresapp.com/) for macOS).
  - Coming soon, this repo will make using Postgres even easier and more portable

Nix handles the rest – you don't need to install anything.

## Getting set up

After cloning this repo locally:

1. _Optional but recommended:_ Connect to the project's build cache to speed up initial setup:
   - Install [Cachix](https://www.cachix.org/), the cache provider client: `nix profile install nixpkgs#cachix`
   - Connect to the [build cache](https://app.cachix.org/cache/garrettmichaelgeorge-public#pull): `cachix use garrettmichaelgeorge-public`
2. Enter the Nix development environment: `nix develop` 
   - This will take a few minutes the first time but should be very fast thereafter.

Alternatively, you can use direnv to load the environment automatically: `direnv allow`.

Now you should be ready to start developing!
  
## Working with the project

1. Start the database
   - Coming soon, you will be able to run a single command and everything will be handled.
   - For now, you will need to start Postgres yourself. If you're on macOS and don't have Postgres set up, [Postgres.app](https://postgresapp.com/) is a great way to get started. Docker [offers](https://hub.docker.com/_/postgres) another way. LiveBeatsNixified does include a full Postgres package in its development environment, so if you're inclined, you can also run `postgres` CLI commands directly.
1. Run the tests: `mix test`
1. Compile a release: `mix release`
1. Use Nix to compile the release: `nix build`
1. Build the app in a Docker image: `nix build .#image`

_Note:_ if you want to be able to sign in when running the app locally, see the GitHub OAuth instructions below.

---

## Upstream README from the official LiveBeats project

Play music together with Phoenix LiveView!

Visit [livebeats.fly.dev](http://livebeats.fly.dev) to try it out, or run locally:

  * Create a [Github OAuth app](https://docs.github.com/en/developers/apps/building-oauth-apps/creating-an-oauth-app) from [this page](https://github.com/settings/applications/new)
    - Set the app homepage to `http://localhost:4000` and `Authorization callback URL` to `http://localhost:4000/oauth/callbacks/github`
    - After completing the form, click "Generate a new client secret" to obtain your API secret
  * Export your GitHub Client ID and secret:

        export LIVE_BEATS_GITHUB_CLIENT_ID="..."
        export LIVE_BEATS_GITHUB_CLIENT_SECRET="..."

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.setup`
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix

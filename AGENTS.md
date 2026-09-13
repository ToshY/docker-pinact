# AGENTS.md

Guidance for coding agents working in this repository.

## What this repo is

A thin packaging repo: it builds and publishes a Docker image for
[pinact](https://github.com/suzuki-shunsuke/pinact) (a tool that pins GitHub Actions to commit SHAs)
to `ghcr.io/toshy/docker-pinact`.

There is **no application source code here** — only a `Dockerfile`, a bake definition, a `Taskfile`,
and CI workflows. Changes are almost always to the build, the release automation, or the docs.

## Layout

| Path | Purpose |
| --- | --- |
| `Dockerfile` | Two-stage build: `golang` builder runs `go install`, output copied into `gcr.io/distroless/static-debian13:nonroot`. |
| `docker-bake.hcl` | Bake targets: `image` (base), `image-local` (default, `type=docker`), `image-all` (multi-platform: `linux/amd64`, `linux/arm64`). |
| `Taskfile.yml` | Local dev entrypoints (`task build`, `task pinact`, lint tasks, `task git:hooks`). |
| `.githooks/pre-commit` | Runs actionlint, zizmor and pinact on staged workflow files; hadolint on a staged `Dockerfile`. Install via `task git:hooks`. |
| `.github/workflows/release.yml` | Weekly + manual release: detect latest upstream pinact tag → build per-platform → push manifest → smoke test. |
| `.github/workflows/{actionlint,hadolint,zizmor}.yml` | Lint on push/PR to `main`. |
| `.github/workflows/pinact.yml` | Verifies actions in this repo are SHA-pinned (`fix: "false"`). |
| `.github/workflows/security.yml` | Weekly Trivy scan of the published image (`CRITICAL` threshold). |
| `zizmor.yml` | Zizmor config: all `uses:` must be hash-pinned; Dependabot cooldown 3 days. |

## Version handling (most important invariant)

The upstream pinact version is a **build argument**, not a pinned module path.

- The Go module path carries a major-version suffix (`github.com/suzuki-shunsuke/pinact/v5` for
  `v5.x.y`). The `Dockerfile` derives this suffix from `APPLICATION_VERSION` at build time —
  **never hardcode `/vN` again**, or the next upstream major release breaks the scheduled release
  job. Only pinact v4+ is supported, so the suffix is always present (v0/v1 would need it omitted).
- The builder uses `GOTOOLCHAIN=auto` so a bump of upstream's `go` directive doesn't hard-fail the
  build on an older `golang:` base image.
- `release.yml` resolves the newest upstream tag at runtime and passes it via
  `*.args.APPLICATION_VERSION`, so the `ARG` default only affects local/manual builds.

When bumping the default version, update **all** of these together:

1. `Dockerfile` → `ARG APPLICATION_VERSION`
2. `Taskfile.yml` → `APPLICATION_VERSION` in the `build` **and** `pinact` tasks
3. `README.md` → the `docker buildx bake --set *.args.APPLICATION_VERSION=...` example

Spots 1 and 2 carry a `# renovate:` comment so Renovate keeps them current. The shared preset
(`github>ToshY/.github//renovate/default`) uses a **custom regex manager with its own syntax** —
`source=` / `name=`, *not* Renovate's native `datasource=` / `depName=`:

```dockerfile
# renovate: source=github-tags name=suzuki-shunsuke/pinact
ARG APPLICATION_VERSION=5.0.0
```

The comment must sit on the line directly above the `key: value` / `KEY=value` line. Using the wrong
keyword silently disables updates — that is why the `4.1.0` → `4.1.1` bump was never proposed. Note
the preset sets `enabledManagers: ["docker-compose", "custom.regex"]`, so Renovate's native
`dockerfile` manager is off; base images such as `FROM golang:1.27` are handled by Dependabot
(which also ignores `semver-patch` for docker).

## Commands

Requires Docker and [Task](https://taskfile.dev). Run everything from the repo root.

```shell
task build                       # build docker-pinact:local
task pinact -- run --diff        # run the built image against this repo
task hadolint                    # lint Dockerfile
task actionlint                  # lint workflows
task zizmor                      # security-audit workflows
```

Build a specific version directly:

```shell
docker buildx bake --set '*.args.APPLICATION_VERSION=5.0.0'
```

Always verify a `Dockerfile` change by actually building it, then smoke-testing the binary
(`docker run --rm docker-pinact:local run --diff`). A build that resolves the module is not proof
the image works.

## Conventions

- **Pin every action by full commit SHA** with a trailing `# vX.Y.Z` comment. Zizmor enforces
  `hash-pin` for all `uses:`, and the pinact workflow fails otherwise.
- **`persist-credentials: false`** on every `actions/checkout` step.
- **Never interpolate `${{ ... }}` directly inside `run:` blocks.** Pass values through `env:` and
  reference them as shell variables (`"$MY_VAR"`) — this repo consistently does so to avoid
  template-injection findings.
- Runners are pinned to `ubuntu-24.04` (`ubuntu-24.04-arm` for arm builds).
- Job-level `permissions:` are declared explicitly and kept minimal.
- pinact CLI flags: since pinact v5 (cobra), long flags **require two dashes** (`--diff`, not
  `-diff`). Short flags (`-c`, `-u`, `-m`, `-i`, `-e`) are unchanged.
- Commit messages in history use short prefixes like `[ci] ...`, `[dev] ...`, or a plain imperative
  summary.
- There is no `.gitignore`; don't leave scratch files (logs, notes) in the working tree.

## Release flow

`release.yml` runs weekly (Sun 02:00 UTC) or via `workflow_dispatch` (optional
`APPLICATION_VERSION` and `FORCE` inputs):

1. **check** — scrape latest upstream pinact tag, skip if that tag already exists on GHCR (unless
   `FORCE=true`).
2. **prepare** — derive the platform matrix from `bake image-all --print`, generate the
   docker/metadata bake file, upload it as an artifact.
3. **build** — matrix build per platform, push by digest.
4. **merge** — assemble and push the manifest list, tagged `latest` and the version.
5. **test** — pull the published tag and run `run --diff` against this repo.

Changes to any stage must keep the artifact names (`bake-meta`, `digests-<platform-pair>`) in sync
between jobs.

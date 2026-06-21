<h1 align="center"> 🐋 docker-pinact 📚 </h1>

<div align="center">
    <img src="https://img.shields.io/github/actions/workflow/status/toshy/docker-pinact/release.yml?branch=main&label=Release" alt="Release" />
    <br /><br />
    <div>A <a href="https://ghcr.io/toshy/docker-pinact">docker image</a> for <a href="https://github.com/suzuki-shunsuke/pinact">pinact</a>.</div>
</div>

## 📝 Quickstart

```shell
docker run --rm \
  -v $(pwd):/repo \
  -u $(id -u):$(id -g) \
  -e PINACT_GITHUB_TOKEN=$(gh auth token) \
  ghcr.io/toshy/docker-pinact:latest --help
```

> [!NOTE]
> - Make sure to mount your working directory to `/repo` on the container.
> - The `--user $(id -u):$(id -g)` is required when using `--fix` so the container can write back to the mounted files.
> - `PINACT_GITHUB_TOKEN` is required to resolve action SHAs without hitting the unauthenticated API rate limit.

## 📚 Examples

Validate that all GitHub Actions are pinned (fails if any are unpinned, no changes written).

```shell
docker run --rm \
  -v $(pwd):/repo \
  -e PINACT_GITHUB_TOKEN=$(gh auth token) \
  ghcr.io/toshy/docker-pinact:latest run --diff
```

Pin GitHub Actions in-place (resolves tags to commit SHAs and writes the changes).

```shell
docker run --rm \
  -v $(pwd):/repo \
  -u $(id -u):$(id -g) \
  -e PINACT_GITHUB_TOKEN=$(gh auth token) \
  ghcr.io/toshy/docker-pinact:latest run --fix
```

## 🧰 Build

Build docker image from [`docker-bake.hcl`](./docker-bake.hcl) with the `APPLICATION_VERSION` argument set to the desired pinact version.

```shell
docker buildx bake --set *.args.APPLICATION_VERSION=4.1.0
```

The built image will be available with the default tag `docker-pinact:local`.

## ❕ License

This repository comes with a [MIT license](./LICENSE).

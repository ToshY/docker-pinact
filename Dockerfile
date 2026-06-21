# syntax=docker/dockerfile:1

FROM golang:1.26 AS builder

# renovate: datasource=github-tags depName=suzuki-shunsuke/pinact
ARG APPLICATION_VERSION=4.1.0
ARG TARGETARCH
ARG TARGETVARIANT

RUN CGO_ENABLED=0 GOARCH=${TARGETARCH} GOARM=${TARGETVARIANT#v} \
    go install github.com/suzuki-shunsuke/pinact/v4/cmd/pinact@v${APPLICATION_VERSION}

FROM gcr.io/distroless/static-debian13:nonroot AS release

LABEL \
    org.opencontainers.image.title="pinact" \
    org.opencontainers.image.description="pinact in docker" \
    org.opencontainers.image.url="https://github.com/toshy/docker-pinact" \
    org.opencontainers.image.source="https://github.com/toshy/docker-pinact" \
    org.opencontainers.image.vendor="ToshY" \
    org.opencontainers.image.licenses="MIT"

WORKDIR /repo

COPY --from=builder /go/bin/pinact /pinact

USER nonroot:nonroot

ENTRYPOINT ["/pinact"]

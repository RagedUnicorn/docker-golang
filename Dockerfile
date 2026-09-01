############################################
# Download + verify stage
############################################
FROM alpine:3.24.1 AS build

# renovate: datasource=golang-version depName=go
ARG GO_VERSION=1.27.0
# Provided automatically by buildx (linux/amd64 -> amd64, linux/arm64 -> arm64)
ARG TARGETARCH

# Build stage labels
LABEL org.opencontainers.image.authors="Michael Wiesendanger <michael.wiesendanger@gmail.com>" \
      org.opencontainers.image.source="https://github.com/ragedunicorn/docker-golang" \
      org.opencontainers.image.licenses="MIT"

# Tools needed to download and verify the release. GNU tar is preferred over
# the busybox applet for the release archive, matching the upstream golang
# images. None of this reaches the runtime stage.
RUN apk add --no-cache --update curl gnupg tar

WORKDIR /tmp/build

# Download the official Go toolchain and verify it against Google's release
# signatures before extracting it.
#
# Go's tarball architecture names match TARGETARCH one to one, so no mapping
# table is needed -- only a guard for values the image does not publish.
#
# Verification is by GPG rather than a pinned SHA-256 because the signing keys
# are version independent: Renovate bumps GO_VERSION on its own and there is no
# checksum left to maintain by hand. Both fingerprints published upstream are
# requested so a signer rotation does not break the build; today they resolve
# to the same key, Google Inc. (Linux Packages Signing Authority).
RUN set -eux; \
    case "$TARGETARCH" in \
      amd64|arm64) ;; \
      *) echo "unsupported architecture: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    file="go${GO_VERSION}.linux-${TARGETARCH}.tar.gz"; \
    base="https://dl.google.com/go"; \
    curl -fsSL -o go.tgz "${base}/${file}"; \
    curl -fsSL -o go.tgz.asc "${base}/${file}.asc"; \
    GNUPGHOME="$(mktemp -d)"; export GNUPGHOME; \
    gpg --batch --keyserver keyserver.ubuntu.com \
      --recv-keys 'EB4C1BFD4F042F6DDDCCEC917721F63BD38B4796'; \
    gpg --batch --keyserver keyserver.ubuntu.com \
      --recv-keys '2F528D36D67B69EDF998D85778BD65473CB3BD13'; \
    gpg --batch --verify go.tgz.asc go.tgz; \
    gpgconf --kill all; \
    rm -rf "$GNUPGHOME" go.tgz.asc; \
    tar -C /usr/local -xzf go.tgz; \
    rm go.tgz; \
    /usr/local/go/bin/go version

############################################
# Runtime stage
############################################
FROM alpine:3.24.1

ARG BUILD_DATE
ARG VERSION

LABEL org.opencontainers.image.title="Go on Alpine Linux" \
      org.opencontainers.image.description="Go toolchain Docker image built on Alpine Linux with a pinned upstream Go release" \
      org.opencontainers.image.vendor="ragedunicorn" \
      org.opencontainers.image.authors="Michael Wiesendanger <michael.wiesendanger@gmail.com>" \
      org.opencontainers.image.source="https://github.com/ragedunicorn/docker-golang" \
      org.opencontainers.image.documentation="https://github.com/ragedunicorn/docker-golang/blob/master/README.md" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.base.name="docker.io/library/alpine:3.24.1"

# ca-certificates: TLS trust store for module downloads (family convention).
# git: the go command shells out to it to resolve VCS module paths.
# gcc + musl-dev: the C toolchain cgo and the race detector require; without
# them CGO_ENABLED=1 builds and `go test -race` fail with "gcc: not found".
# make: near-universal in Go project build scripts.
RUN apk add --no-cache \
    ca-certificates \
    git \
    gcc \
    musl-dev \
    make

COPY --from=build /usr/local/go /usr/local/go

# Every Go path is set explicitly rather than left to default off $HOME. Go
# aborts with "neither GOCACHE nor HOME is defined" when HOME is unset, which
# is exactly how container-structure-test invokes command tests. Keeping the
# whole cache tree under a single GOPATH also means one named volume covers
# both the module cache and the build cache.
#
# GOTOOLCHAIN=local matches the upstream golang images: a pinned image stays
# pinned, and a go.mod demanding a newer toolchain fails loudly instead of
# silently downloading one. Override it with -e GOTOOLCHAIN=auto if you want
# the download behaviour.
ENV PATH="/usr/local/go/bin:/go/bin:$PATH" \
    GOPATH=/go \
    GOMODCACHE=/go/pkg/mod \
    GOCACHE=/go/cache \
    GOTOOLCHAIN=local

# Create non-root user for running Go. A home directory is created
# deliberately (no -H): the go command writes ~/.config/go/env on the first
# `go env -w`. The GOPATH tree is pre-created with golang ownership so a named
# volume mounted at /go is initialized owned by the golang user instead of
# root.
RUN adduser -D -h /home/golang -s /sbin/nologin golang && \
    mkdir -p /go/src /go/bin /go/pkg/mod /go/cache && \
    chown -R golang:golang /go

WORKDIR /app

RUN chown -R golang:golang /app

USER golang

ENTRYPOINT ["go"]

CMD ["version"]

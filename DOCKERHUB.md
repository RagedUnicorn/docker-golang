# Go Alpine Docker Image

![Docker Go](https://raw.githubusercontent.com/ragedunicorn/docker-golang/master/docs/docker_golang_banner.png)

The Go toolchain on Alpine Linux, shipping a pinned upstream Go release decoupled from the Alpine version.

## Quick Start

```bash
# Pull latest version
docker pull ragedunicorn/golang:latest

# Or pull specific version
docker pull ragedunicorn/golang:1.27.0-alpine3.24.1-1

# Print the Go version
docker run --rm ragedunicorn/golang:latest

# Build the code in the current directory
docker run --rm -v $(pwd):/app ragedunicorn/golang:latest build ./...
```

## Features

- 🚀 **Small footprint**: compact toolchain image built on Alpine Linux
- 🐹 **Go 1.27.0**: pinned upstream release, verified by GPG at build time
- 🔧 **Cgo ready**: gcc and musl-dev included, so cgo and `go test -race` work out of the box
- 📦 **Module aware**: git for VCS module paths, pre-created cache tree at `/go`
- 🔒 **Security**: non-root user, minimal attack surface
- 🏗️ **Multi-platform**: supports linux/amd64 and linux/arm64

## Usage Examples

### Run a Go program
```bash
docker run --rm -v $(pwd):/app ragedunicorn/golang:latest run main.go
```

### Build a module
```bash
docker run --rm -v $(pwd):/app -v gocache:/go ragedunicorn/golang:latest build ./...
```

### Run tests, with and without the race detector
```bash
docker run --rm -v $(pwd):/app -v gocache:/go ragedunicorn/golang:latest test ./...
docker run --rm -v $(pwd):/app -v gocache:/go ragedunicorn/golang:latest test -race ./...
```

### Produce a portable static binary
```bash
docker run --rm -v $(pwd):/app -v gocache:/go \
  -e CGO_ENABLED=0 \
  ragedunicorn/golang:latest build -o app ./cmd/app
```

### Build a custom image
```dockerfile
FROM ragedunicorn/golang:latest AS build

WORKDIR /app
COPY --chown=golang:golang . .
RUN CGO_ENABLED=0 go build -o /go/bin/app ./cmd/app

FROM alpine:3.24.1
COPY --from=build /go/bin/app /usr/local/bin/app
ENTRYPOINT ["app"]
```

## Tags

This image uses semantic versioning that includes all component versions:

**Format:** `{go_version}-alpine{alpine_version}-{build_number}`

### Version Examples

- `1.27.0-alpine3.24.1-1` - Go 1.27.0 on Alpine 3.24.1, build 1
- `1.27.0-alpine3.24.1-2` - Rebuild of same versions (bug fixes, security patches)
- `1.27.0` - Bare Go version, tracking the most recent build of that release
- `latest` - Most recent stable release

The Go version is pinned per release and updated independently of Alpine. When updates are available through automated dependency management, new releases are created with appropriate version tags.

## Environment Variables

- `GOPATH=/go` - Pre-created and owned by the golang user
- `GOMODCACHE=/go/pkg/mod` - Downloaded modules
- `GOCACHE=/go/cache` - Build cache
- `GOTOOLCHAIN=local` - No implicit toolchain downloads

The whole cache tree lives under `GOPATH`, so a single named volume mounted at `/go` covers both the module cache and the build cache.

## Working Directory

The default working directory is `/app`. Mount your code here:

```bash
docker run --rm -v $(pwd):/app ragedunicorn/golang:latest build ./...
```

## A Note on musl

The image is Alpine based, so cgo builds link against musl rather than glibc and will not run on a glibc host. Set `CGO_ENABLED=0` for a fully static binary that runs anywhere.

## Links

- **GitHub**: [https://github.com/ragedunicorn/docker-golang](https://github.com/ragedunicorn/docker-golang)
- **Issues**: [https://github.com/ragedunicorn/docker-golang/issues](https://github.com/ragedunicorn/docker-golang/issues)
- **Releases**: [https://github.com/ragedunicorn/docker-golang/releases](https://github.com/ragedunicorn/docker-golang/releases)

## License

MIT License - See [GitHub repository](https://github.com/ragedunicorn/docker-golang) for details.

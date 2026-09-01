# Go Docker Examples

This directory contains a simple example to get you started with the Go Docker image.

## Hello World Example

The `hello-world.go` program demonstrates basic Go functionality in the Docker container.

### Running the Example

#### Using Docker Compose (recommended)

```bash
# From the examples directory
docker compose run --rm hello-world

# Compile it to ./hello instead of running it
docker compose run --rm build-hello

# Or get an interactive shell with the toolchain on PATH
docker compose run --rm go-shell

# Run any go subcommand
docker compose run --rm golang vet ./...
```

#### Using Docker directly

```bash
# From the repository root
docker run --rm -v "$(pwd)/examples:/app" ragedunicorn/golang:latest run hello-world.go
```

### Expected Output

```
Hello, World from Docker Go!
Go version: go1.27.0
Platform: linux/amd64
```

## Creating Your Own Program

1. Create a Go file:

```go
// my-program.go
package main

import "fmt"

func main() {
	fmt.Println("Hello from my custom program!")
}
```

2. Run it with Docker:

```bash
docker run --rm -v "$(pwd):/app" ragedunicorn/golang:latest run my-program.go
```

## Working with Modules

For a real project with a `go.mod`, mount the module root and keep the module
cache in a named volume so dependencies are not re-downloaded on every run:

```bash
docker run --rm -v "$(pwd):/app" -v gocache:/go ragedunicorn/golang:latest mod download
docker run --rm -v "$(pwd):/app" -v gocache:/go ragedunicorn/golang:latest build ./...
docker run --rm -v "$(pwd):/app" -v gocache:/go ragedunicorn/golang:latest test ./...
```

## Building a Portable Binary

The image is Alpine based, so a `CGO_ENABLED=1` build links against musl and
will not run on a glibc host. Set `CGO_ENABLED=0` for a fully static binary
that runs anywhere:

```bash
docker run --rm -v "$(pwd):/app" -v gocache:/go \
  -e CGO_ENABLED=0 \
  ragedunicorn/golang:latest build -o app ./cmd/app
```

## Building a Custom Image

```dockerfile
FROM ragedunicorn/golang:latest

# Install additional packages
USER root
RUN apk add --no-cache g++
USER golang

WORKDIR /app
COPY --chown=golang:golang . .

RUN go build -o /go/bin/app ./cmd/app

ENTRYPOINT ["/go/bin/app"]
```

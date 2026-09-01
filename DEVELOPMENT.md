# Development Guide

This document provides information for developers working on the Go Docker image.

## Development Environment

### Prerequisites

- Docker installed and running
- Docker Compose installed
- Git for version control
- Text editor or IDE

### Project Structure

```
docker-golang/
├── Dockerfile              # Main image definition
├── docker-compose.yml      # Basic usage configuration
├── docker-compose.dev.yml  # Development environment
├── docker-compose.test.yml # Test orchestration
├── .env                    # Default environment variables
├── examples/               # Example Docker Compose configurations
│   ├── docker-compose.yml  # Hello world example
│   └── hello-world.go      # Example program
├── test/                   # Container Structure Tests
│   ├── golang_test.yml
│   ├── golang_command_test.yml
│   └── golang_metadata_test.yml
└── docs/                   # Documentation assets
```

## Development Workflow

### 1. Local Development Mode

The `docker-compose.dev.yml` file provides an interactive development environment:

```bash
# Build the image locally
docker compose -f docker-compose.dev.yml build

# Run in development mode (interactive shell with the toolchain on PATH)
docker compose -f docker-compose.dev.yml run --rm golang-dev

# Inside the container
go version
go env
```

The development mode:

- Mounts the current directory to `/app` for testing files
- Keeps the module and build cache in a named volume
- Uses interactive mode with STDIN open and TTY allocated
- Overrides the entrypoint with a shell rather than `go`

### 2. Building the Image

```bash
# Basic build
docker build -t ragedunicorn/golang:dev .

# Build with specific versions
docker build \
  --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
  --build-arg VERSION=1.27.0-alpine3.24.1-1 \
  -t ragedunicorn/golang:1.27.0-alpine3.24.1-1 .

# Build a different Go release without editing the Dockerfile
docker build --build-arg GO_VERSION=1.26.7 -t ragedunicorn/golang:1.26 .

# Multi-platform build (requires buildx)
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ragedunicorn/golang:dev .
```

### 3. Testing Your Changes

After making changes, always build and test locally:

```bash
# Build your changes locally
docker buildx build --load --provenance=false -t ragedunicorn/golang:test .
```

#### Running Tests (Cross-Platform)

**Linux/macOS:**

```bash
# Run all tests against your local build
GOLANG_TEST_VERSION=test docker compose -f docker-compose.test.yml run --rm test-all

# Run specific tests during development
GOLANG_TEST_VERSION=test docker compose -f docker-compose.test.yml up container-test-command
```

**Windows Command Prompt:**

```cmd
set GOLANG_TEST_VERSION=test && docker compose -f docker-compose.test.yml run --rm test-all
```

**Windows PowerShell:**

```powershell
$env:GOLANG_TEST_VERSION="test"; docker compose -f docker-compose.test.yml run --rm test-all
```

`GOLANG_TEST_VERSION` already defaults to `test`, so the bare command works too — it is spelled out above to match the CI invocation.

**Important:** Never test against remote images - they may have different labels or configurations due to CI/CD overrides.

See [TEST.md](TEST.md) for detailed testing information.

## Making Changes

### Version Updates

This project uses [Renovate](https://docs.renovatebot.com/) to automatically manage dependency updates:

- **Alpine Linux**: Renovate monitors Docker Hub and creates PRs for new Alpine versions. Every Alpine reference is kept in sync from a single grouped PR — the `FROM` lines (Renovate built-in dockerfile manager), the `org.opencontainers.image.base.name` OCI label, and the Alpine version asserted in `test/golang_metadata_test.yml` (both via regex `customManagers` in `renovate.json`).
- **Go**: The Go release is pinned via the `GO_VERSION` build arg, tracked through the `# renovate:` comment above it with the `golang-version` datasource. It is grouped with the exact version asserted in `test/golang_command_test.yml`, so a bump lands as one PR with the test already updated. Patch releases automerge; minor bumps are reviewed by hand.

When Renovate creates a PR:

1. Review the changes in the PR
2. Check the CI/CD pipeline passes all tests
3. Test the build locally if it is a minor version update
4. Merge the PR if everything looks good

Manual version updates are rarely needed. Because the Go version is pinned independently of Alpine, an Alpine bump does not change the Go version. If you must update manually:

```dockerfile
# renovate: datasource=golang-version depName=go
ARG GO_VERSION=1.27.0
```

When manually updating the Go version:

1. Update `GO_VERSION` in the Dockerfile
2. Update the expected version in `test/golang_command_test.yml` (`expectedOutput: ['go1.27.0']`)
3. Test the build thoroughly
4. Update version numbers in documentation

When manually updating the Alpine version, update only the `FROM alpine:X.X.X` lines — Renovate keeps the `base.name` label and metadata test aligned on its next run.

### Why the Go toolchain is downloaded rather than installed with apk

Alpine ships Go in its community repository, but the version is coupled to the Alpine release: Alpine 3.24 carries Go 1.26.3 while upstream is at 1.27.0. Go publishes a new minor every six months and supports only the last two, so an apk-pinned image would spend long stretches a full minor behind. The build stage therefore downloads the official tarball from `dl.google.com` and verifies it.

Verification is by GPG rather than a pinned SHA-256. The signing keys are version independent, so Renovate can bump `GO_VERSION` on its own with no checksum left to maintain by hand — contrast `docker-apktool`, where a self-pinned hash has to be refreshed manually on every bump. Two keys are fetched because the signer has rotated between releases; the current one is Google Inc. (Linux Packages Signing Authority).

### Why git trusts every directory

`go build` defaults to `-buildvcs=auto`, so it shells out to git to stamp the revision whenever the package directory is a checkout. A bind-mounted source tree is owned by the host user, not by the `golang` user in the container, and git rejects that with `detected dubious ownership in repository at '/app'` — which makes `go build ./...` fail outright on essentially every real project.

The Dockerfile therefore runs `git config --system --add safe.directory '*'`. Trusting all directories is the right trade for a single-user build container that only ever sees what the caller explicitly mounts, and it is what CI images do; the safe.directory guard exists to protect against another local user's repository on a shared machine, which is not the situation here. The alternative would be pushing `-buildvcs=false` onto every user for every build.

This is covered by a regression test in `test/golang_command_test.yml`, since the failure mode is invisible until someone mounts a real checkout.

### Adding Packages

To add Alpine packages to the base image (discouraged - users should extend the image):

```dockerfile
RUN apk add --no-cache \
    ca-certificates \
    git \
    gcc \
    musl-dev \
    make \
    your-new-package
```

**Note:** This image is intentionally a toolchain image. Users should extend it:

```dockerfile
FROM ragedunicorn/golang:latest

USER root
RUN apk add --no-cache g++
USER golang
```

Linters and other independently versioned Go tooling do not belong here — that would tie their release cadence to the Go release cadence and break the one-tool-per-image rule the family follows.

## Code Style and Best Practices

### Dockerfile Best Practices

1. **Minimal installation**: Only the Go toolchain and what it shells out to
2. **Layer optimization**: Group related commands to minimize layers
3. **Cache efficiency**: Order commands from least to most frequently changed
4. **Security**: Run as non-root user, verify every downloaded artifact
5. **Labels**: Follow OCI naming conventions

### Documentation

1. **README.md**: Keep focused on user-facing information
2. **Comments**: Add comments in Dockerfile for complex operations
3. **Examples**: Provide working examples for new features
4. **Commit messages**: Use conventional format (feat:, fix:, docs:, etc.)

### Testing

1. **Test everything**: New features must include tests
2. **Test edge cases**: Include negative tests where appropriate
3. **Keep tests fast**: Avoid long-running operations in tests
4. **Test organization**: Group related tests together

## Debugging

### Common Issues

**Build failures:**

```bash
# Verbose build output
docker buildx build --no-cache --progress=plain -t ragedunicorn/golang:debug .

# Inspect the extracted toolchain
docker run --rm --entrypoint sh ragedunicorn/golang:debug -c "ls /usr/local/go/bin && go version"
```

**GPG verification failures:**

The build fetches the Go signing keys from `keyserver.ubuntu.com`. A keyserver outage surfaces as a failing `gpg --recv-keys` step, not as a bad signature. Re-run the build; if the outage persists, the keys can be fetched from another keyserver by editing the `--keyserver` flag. A genuine `BAD signature` means the download was corrupted or tampered with and must not be worked around.

**Go not working:**

```bash
# Check the installation
docker run --rm --entrypoint sh ragedunicorn/golang:dev -c "which go && go version"

# Check the environment
docker run --rm --entrypoint sh ragedunicorn/golang:dev -c "go env"
```

**Cgo or race detector failures:**

```bash
# Confirm the C toolchain is present and reachable
docker run --rm --entrypoint sh ragedunicorn/golang:dev -c "gcc --version && go env CGO_ENABLED"
```

**Permission errors writing to the cache:**

```bash
# The GOPATH tree must be owned by the golang user (uid/gid 1000)
docker run --rm --entrypoint sh ragedunicorn/golang:dev -c "ls -ld /go /go/pkg/mod /go/cache"
```

## Contributing

### Before Submitting Changes

1. Run the full test suite
2. Update documentation if needed
3. Add tests for new features
4. Ensure your code follows the existing style

### Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes using conventional commits
4. Push to your fork
5. Open a Pull Request with a clear description

### Release Process

See [RELEASE.md](RELEASE.md) for information about creating releases.

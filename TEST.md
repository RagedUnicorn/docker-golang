# Testing Guide

This document describes how to test the Go Docker image using Container Structure Tests.

## Quick Start

```bash
# Run all tests
docker compose -f docker-compose.test.yml run --rm test-all

# Run individual test suites
docker compose -f docker-compose.test.yml up container-test          # File structure tests
docker compose -f docker-compose.test.yml up container-test-command  # Command execution tests
docker compose -f docker-compose.test.yml up container-test-metadata # Metadata validation tests
```

## Test Structure

The test suite consists of three main test files:

### 1. File Structure Tests (`test/golang_test.yml`)

Validates:

- The `go` and `gofmt` binaries exist with correct permissions
- The standard library source tree is present
- `gcc`, `git` and `make` are installed (the tools the go command shells out to)
- The system gitconfig exists (it marks bind-mounted checkouts as safe)
- The GOPATH tree (`/go`, `/go/pkg/mod`, `/go/cache`, `/go/bin`) exists and is owned by uid/gid 1000
- Working directory `/app` exists and is accessible
- SSL certificates are present for module downloads

### 2. Command Execution Tests (`test/golang_command_test.yml`)

Validates:

- Go and gofmt version output and PATH resolution
- The Go environment (`GOPATH`, `GOMODCACHE`, `GOCACHE`, `GOTOOLCHAIN`, `CGO_ENABLED`)
- `gcc` and `git` are runnable, and git trusts bind-mounted repositories
- Compiling and running a real program with `go run`
- A cgo build (importing `"C"`), which fails unless gcc and musl-dev are wired up
- `gofmt` reporting an unformatted file
- Non-root user functionality
- Working directory configuration and writability of `/app` and `/go/cache`

### 3. Metadata Tests (`test/golang_metadata_test.yml`)

Validates:

- OCI-compliant labels are present and correct
- The four Go environment variables baked into the image
- Container entrypoint and default command
- Working directory configuration
- User context (runs as non-root golang user)

## Running Tests

### Prerequisites

1. Docker must be installed and running
2. Build the Go image locally before testing

### Important: Always Test Local Builds

**⚠️ Always build and test locally to ensure consistency:**

```bash
# Build the image locally with a test tag
docker buildx build --load --provenance=false -t ragedunicorn/golang:test .
```

**Linux/macOS:**

```bash
# Run tests against your local build
GOLANG_TEST_VERSION=test docker compose -f docker-compose.test.yml run --rm test-all
```

**Windows (PowerShell):**

```powershell
$env:GOLANG_TEST_VERSION="test"; docker compose -f docker-compose.test.yml run --rm test-all
```

**Windows (Command Prompt):**

```cmd
set GOLANG_TEST_VERSION=test && docker compose -f docker-compose.test.yml run --rm test-all
```

**Why local testing is important:**
- Remote images (Docker Hub, GHCR) may have different labels due to CI/CD overrides
- Ensures you are testing exactly what you built
- Avoids false positives/negatives from version mismatches
- Guarantees consistent test results

**Never pull remote images for testing:**

**❌ DON'T DO THIS - may have different labels/settings:**

```bash
docker pull ragedunicorn/golang:latest
GOLANG_TEST_VERSION=latest docker compose -f docker-compose.test.yml run --rm test-all
```

**✅ DO THIS - test your local build:**

```bash
docker buildx build --load --provenance=false -t ragedunicorn/golang:test .
GOLANG_TEST_VERSION=test docker compose -f docker-compose.test.yml run --rm test-all
```

### Why `GOLANG_TEST_VERSION` and not `GOLANG_VERSION`

`docker-compose.test.yml` reads its own variable, `GOLANG_TEST_VERSION`, which defaults to `test`. The runtime compose file and the examples read `GOLANG_VERSION`, which `.env` pins to `latest`.

Keeping them separate matters. If both files read the same variable, the `latest` value in `.env` silently wins over the `:-test` fallback in the test compose file, and a bare `docker compose -f docker-compose.test.yml run --rm test-all` quietly validates the **published** image instead of the one you just built — exactly the failure mode this document warns about. With two variables, the bare command always tests the local build.

### Test Execution

Run all tests against your local build:

```bash
# Ensure you have built locally first!
docker compose -f docker-compose.test.yml run --rm test-all
```

Run specific test categories:

```bash
# File structure and toolchain layout tests
docker compose -f docker-compose.test.yml up container-test

# Command execution and functionality tests
docker compose -f docker-compose.test.yml up container-test-command

# Metadata and label tests
docker compose -f docker-compose.test.yml up container-test-metadata
```

### Testing Different Versions

When testing different versions, always build locally first:

```bash
# Build a specific version locally
docker buildx build --load --provenance=false -t ragedunicorn/golang:1.27.0-alpine3.24.1-1 .
```

**Linux/macOS:**

```bash
GOLANG_TEST_VERSION=1.27.0-alpine3.24.1-1 docker compose -f docker-compose.test.yml run --rm test-all
```

**Windows (PowerShell):**

```powershell
$env:GOLANG_TEST_VERSION="1.27.0-alpine3.24.1-1"; docker compose -f docker-compose.test.yml run --rm test-all
```

## Troubleshooting Test Failures

### Go Version Mismatches

`test/golang_command_test.yml` asserts the exact release:

```yaml
- name: 'Go version check'
  command: 'go'
  args: ['version']
  expectedOutput: ['go1.27.0']
```

Renovate keeps this in step with the `GO_VERSION` build arg through a regex `customManager`, so a routine bump arrives as one PR with both already updated. If you change `GO_VERSION` by hand, update this assertion too or the command tests will fail.

To find the version actually in the image:

```bash
docker run --rm ragedunicorn/golang:test version
```

### No `HOME` in Command Tests

container-structure-test does not populate `HOME` when it runs command tests. Go aborts with `neither GOCACHE nor HOME is defined` if it has to derive its cache location. This image sets `GOPATH`, `GOMODCACHE`, `GOCACHE` and `GOTOOLCHAIN` explicitly as ENV so nothing depends on `HOME` — which is also why any shell probe added to the command tests must use absolute paths rather than `$HOME` or `~`.

### Cgo or Race Detector Failures

The `Cgo build works` test compiles a program importing `"C"`. If it fails with `gcc: not found` or a missing header, the `gcc`/`musl-dev` packages are missing from the runtime stage. Confirm with:

```bash
docker run --rm --entrypoint sh ragedunicorn/golang:test -c "gcc --version && go env CGO_ENABLED"
```

Note that cgo builds produced by this image link against musl, not glibc. That is expected on an Alpine base and is documented in [README.md](README.md#cgo-and-portable-binaries); it is not a test failure.

### Cache Ownership Failures

`GOPATH is owned by golang` and the writability probes fail if the `chown -R golang:golang /go` step is removed or a volume is mounted over `/go` by something running as root. Inspect with:

```bash
docker run --rm --entrypoint sh ragedunicorn/golang:test -c "ls -ld /go /go/pkg/mod /go/cache"
```

### Metadata Test Failures

**Common causes:**

1. **Testing remote images instead of local builds**
   - Remote images (Docker Hub, GHCR) have labels overridden by CI/CD
   - Always test your local builds with `GOLANG_TEST_VERSION=test`

2. **Label value mismatches**
   - CI/CD systems may capitalize values (e.g., "RagedUnicorn" vs "ragedunicorn")
   - GitHub Actions may override labels during build

3. **Version-specific labels**
   - The `org.opencontainers.image.version` label changes with each build
   - Build date labels are dynamic

**Solution:** Always build and test locally before pushing.

### Permission Errors

If you encounter Docker socket permission errors:

```bash
sudo docker compose -f docker-compose.test.yml run --rm test-all
```

Or ensure your user is in the `docker` group:

```bash
sudo usermod -aG docker $USER
# Log out and back in for changes to take effect
```

## Writing New Tests

To add new tests, follow the Container Structure Test schema:

1. **File tests**: Add to `test/golang_test.yml`
2. **Command tests**: Add to `test/golang_command_test.yml`
3. **Metadata tests**: Add to `test/golang_metadata_test.yml`

Example of adding a new command test:

```yaml
- name: 'Go vet runs'
  setup: [['sh', '-c', 'printf "package main\nfunc main() {}\n" > /app/vet.go']]
  command: 'go'
  args: ['vet', '/app/vet.go']
  exitCode: 0
```

Keep command tests cheap. Anything that downloads modules from the network belongs in the workflow, not here.

## CI/CD Integration

These tests are automatically run in GitHub Actions:

- **On every push** to master branches
- **On every pull request** to master branches
- **Before releases** to ensure quality

The test workflow (`.github/workflows/test.yml`):
1. Builds the Docker image
2. Runs all Container Structure Tests
3. Verifies basic Go functionality, including a `go test -race` smoke test on a throwaway module — the end-to-end check that the cgo toolchain is wired up
4. Blocks releases if tests fail

Every test step declares `shell: bash` so `set -o pipefail` is active. Without it a failing command piped through `tee` reports the exit code of `tee` and the step passes even though the test failed.

Manual integration example:

```yaml
- name: Run Container Structure Tests
  shell: bash
  env:
    GOLANG_TEST_VERSION: test
  run: docker compose -f docker-compose.test.yml run --rm test-all
```

The `test-all` service returns:
- Exit code 0: All tests passed
- Exit code 1: One or more tests failed

## Test Maintenance

When updating the Docker image:

1. **Go version updates**: Renovate updates the `expectedOutput` assertion in `golang_command_test.yml` alongside the `GO_VERSION` build arg, so no manual edit is needed; a hand-rolled bump needs both
2. **Alpine version updates**: Renovate keeps the `base.name` label and `golang_metadata_test.yml` in sync with the `FROM` version, so no manual edit is needed for the drift to resolve
3. **New functionality**: Add corresponding tests to verify behavior
4. **Label or ENV changes**: Update metadata tests to match

Always run the full test suite before creating a release.

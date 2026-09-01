# Release Process

This document describes how to create a new release for the Docker Go project.

## Quick Start

```bash
# Tag format: v{go_version}-alpine{alpine_version}-{build_number}
git tag -a v1.27.0-alpine3.24.1-1 -m "v1.27.0-alpine3.24.1-1"
git push origin v1.27.0-alpine3.24.1-1
```

This automatically triggers the release process via GitHub Actions.

## Version Tag Format

See [README.md](README.md#versioning) for the complete versioning documentation.

**Format:** `v{go_version}-alpine{alpine_version}-{build_number}`

Examples:
- `v1.27.0-alpine3.24.1-1` - Initial release
- `v1.27.0-alpine3.24.1-2` - Rebuild with same versions
- `v1.27.1-alpine3.24.1-1` - Go patch update (build resets to 1)
- `v1.27.0-alpine3.25.0-1` - Alpine update (build resets to 1)

One git tag produces three image tags per registry: the full tag as written (minus the `v`), the bare Go version, and `latest`.

## Release Workflow

When you push a tag, GitHub Actions automatically:

1. **Builds Docker images** (`.github/workflows/docker_release.yml`)
   - Runs the full Container Structure Test suite first; the push job does not start unless it passes
   - Multi-platform: linux/amd64 and linux/arm64
   - Pushes to both GitHub Container Registry and Docker Hub

2. **Creates GitHub Release** (`.github/workflows/github_release.yml`)
   - Generates changelog from commit history
   - Adds Docker pull commands
   - Links to the release

## Before the First Release

The very first tag push publishes to two registries, so make sure the repository is ready:

1. `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` exist under Settings → Secrets and variables → Actions
2. GitHub Actions is enabled and workflows have package write permission
3. The `Test` workflow is green on master

After the first release, check the produced tag list on both registries: you should see `1.27.0-alpine3.24.1-1`, `1.27.0` and `latest`.

## When to Create a Release

Create a new release when:

1. **Renovate updates dependencies** - After merging Renovate PRs for Go or Alpine updates
2. **Bug fixes** - After fixing issues in the Dockerfile or build process
3. **Feature additions** - After adding new functionality
4. **Security patches** - Immediately after security-related updates

### Build Number Guidelines

- **Reset to 1**: When the Go or Alpine version changes
- **Increment**: When rebuilding with the same versions (fixes, optimizations)

## Post-Release Tasks

### Update Docker Hub Documentation

After creating a release, manually update the Docker Hub repository description:

1. Go to [Docker Hub](https://hub.docker.com/r/ragedunicorn/golang)
2. Click "Manage Repository" → "Description"
3. Copy the contents of `DOCKERHUB.md`
4. Update any version numbers in the examples to match the latest release
5. Save the changes

**Note**: The `DOCKERHUB.md` file is maintained in the repository as the source of truth for Docker Hub documentation.

## Best Practices

### Commit Messages

Use conventional commit format for better changelogs:

- `feat:` New features
- `fix:` Bug fixes
- `docs:` Documentation changes
- `chore:` Maintenance tasks
- `refactor:` Code refactoring
- `test:` Test additions/changes
- `perf:` Performance improvements

Example:
```bash
git commit -m "feat: add support for additional build tooling"
git commit -m "fix: resolve cache permission issue in container"
git commit -m "docs: update usage examples"
```

### Pre-release Testing

Before creating a release:

1. Test the Docker image locally with your version changes
2. Verify `go build`, `go test` and `go test -race` all work against a real module
3. Check that multi-platform builds work (especially arm64)

## Troubleshooting

### Release did not trigger

- Ensure tag starts with `v` and follows the format (e.g., `v1.27.0-alpine3.24.1-1`)
- Check GitHub Actions tab for workflow runs
- Verify you have push permissions

### Docker build failed

- Check the Docker workflow logs
- Ensure Dockerfile builds locally
- Verify multi-platform compatibility
- A failing `gpg --recv-keys` step is a keyserver outage, not a bad artifact; re-run the job

### The bare version tag is missing

`docker/metadata-action` reads the `-alpine…` suffix as a semver prerelease, so a `type=semver` pattern renders the full tag instead of the bare version. The workflow uses `type=match,pattern=v(\d+\.\d+\.\d+)-alpine,group=1` for this reason — do not switch it to `type=semver`.

### Missing permissions

Ensure your repository has:
- GitHub Actions enabled
- Package write permissions for workflows
- Proper secrets configuration (GITHUB_TOKEN is automatic)

### Docker Hub Configuration

To enable Docker Hub deployment, you need to add these secrets to your GitHub repository:

1. Go to Settings → Secrets and variables → Actions
2. Add the following secrets:
   - `DOCKERHUB_USERNAME`: Your Docker Hub username
   - `DOCKERHUB_TOKEN`: Your Docker Hub access token (not password)

To create a Docker Hub access token:
1. Log in to Docker Hub
2. Go to Account Settings → Security
3. Click "New Access Token"
4. Give it a descriptive name (e.g., "GitHub Actions")
5. Copy the token and add it as `DOCKERHUB_TOKEN` secret

## Manual Release (if needed)

If automation fails, you can create a release manually:

1. Go to the repository's "Releases" page
2. Click "Create a new release"
3. Choose your tag (must follow format: `v1.27.0-alpine3.24.1-1`)
4. Add release notes
5. Include Docker pull commands:
   ```
   docker pull ghcr.io/ragedunicorn/docker-golang:1.27.0-alpine3.24.1-1
   docker pull ragedunicorn/golang:1.27.0-alpine3.24.1-1
   ```

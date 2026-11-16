# Contributing

## Prerequisites

- Docker with buildx support
- Bash 4.0+
- AWS CLI (for testing with real S3)
- An instance of Home Assistant running locally (for integration testing)

## Development Workflow

### Building

The `build` script runs all stages: lint → build → test → scan → push.

```bash
./build              # Local build and test
./build --push       # Push to Docker Hub
./build --help       # See all options
```

### Testing

Run the test suite against a locally built image:

```bash
./build --no-scan
```

Or manually:

```bash
docker buildx build -t ha-offsite-backups:test .
test/run-all
```

### Code Style

All shell scripts must pass:

```bash
shellcheck src/ha-offsite-backups src/startup src/healthcheck
hadolint Dockerfile
```

The `./build --no-test` stage runs these automatically.

### Submitting Changes

1. Create a branch from `dev`
2. Make your changes
3. Run `./build` to lint, test, and scan
4. Submit a pull request to the `dev` branch

## Protected branches and tags

`main` cannot be force-pushed or deleted. The required GitHub Actions checks
are listed in **Settings > Rules > Rulesets > Require main checks**. Missing
or failed checks block updates; GitHub also accepts skipped and neutral
results. The repository owner is the only actor allowed to create, update,
or delete `v*` tags.

Inspect and fix failed Actions runs before retrying. If a check is missing,
verify that its workflow runs on the source branch. After renaming a check,
verify the new name on a branch and update the ruleset before promoting that
change to `main`.

## Release Process

Releases are tagged with semantic versions:

```bash
./build --push --version 1.2.3
```

Tags trigger a multi-platform build and push to Docker Hub, plus SLSA provenance and SBOM generation.

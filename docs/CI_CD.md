# CI/CD Documentation

ExFlowGraph uses GitHub Actions for continuous integration and deployment, following Elixir community best practices.

## Overview

The CI pipeline runs automatically on:
- **Push** to `main` or `develop` branches
- **Pull Requests** targeting `main` or `develop` branches

## CI Jobs

### 1. Test Matrix

Runs tests across multiple Elixir/OTP version combinations to ensure compatibility.

**Matrix:**
- Elixir 1.17.3 + OTP 27.1 (latest, with coverage)
- Elixir 1.16.3 + OTP 26.2 (previous stable)
- Elixir 1.15.8 + OTP 26.2 (minimum supported)

**Steps:**
1. Checkout code
2. Set up Elixir/OTP
3. Restore dependency cache
4. Install dependencies
5. Compile with warnings as errors
6. Run tests with trace output
7. Generate coverage report (latest version only)

**Database:**
- PostgreSQL 16 service container
- Automatic health checks
- Test database created per run

### 2. Code Quality

Ensures code meets quality standards.

**Checks:**
- **Format Check**: `mix format --check-formatted`
- **Credo**: Static code analysis with strict mode
- **Unused Dependencies**: `mix deps.unlock --check-unused`
- **Security Audit**: `mix deps.audit` for known vulnerabilities

### 3. Assets & Frontend

Validates frontend build process.

**Steps:**
1. Set up Node.js 20
2. Install npm dependencies (with caching)
3. Build assets
4. Verify build output

### 4. Dialyzer (Type Checking)

Performs static type analysis using Dialyzer.

**Features:**
- PLT (Persistent Lookup Table) caching
- GitHub-formatted output for PR annotations
- Checks for type inconsistencies and potential bugs

### 5. All Checks Passed

Final job that depends on all others. Only succeeds if all checks pass.

## Local Development

### Running CI Checks Locally

```bash
# Run all precommit checks
mix precommit

# Individual checks
mix format --check-formatted
mix credo --strict
mix test
mix dialyzer
mix deps.audit
```

### Installing Dependencies

```bash
# Install all dependencies including dev/test tools
mix deps.get

# Build PLT for Dialyzer (first time only, ~5-10 minutes)
mix dialyzer --plt
```

### Test Coverage

```bash
# Generate HTML coverage report
mix coveralls.html

# Open coverage report
open cover/excoveralls.html

# Generate detailed coverage
mix coveralls.detail
```

### Code Quality Tools

#### Credo

```bash
# Run with strict mode
mix credo --strict

# Explain an issue
mix credo explain lib/my_file.ex:42

# List all issues
mix credo list
```

#### Dialyzer

```bash
# Run type checking
mix dialyzer

# Update PLT after dependency changes
mix dialyzer --plt

# Format output for GitHub
mix dialyzer --format github
```

## Configuration Files

### `.github/workflows/ci.yml`

Main CI workflow configuration. Defines all jobs, matrix, and steps.

### `.credo.exs`

Credo configuration with enabled/disabled checks. Configured for:
- Strict mode enabled
- Max line length: 120 characters
- Module documentation required
- TODO comments allowed (exit status 0)

### `mix.exs`

Project configuration includes:
- Test coverage tool: ExCoveralls
- Dialyzer PLT location: `priv/plts/dialyzer.plt`
- Preferred CLI environments for coverage tasks

## Caching Strategy

### Dependency Cache

**Key:** `os-mix-otp-elixir-mix.lock`

Caches:
- `deps/` - Downloaded dependencies
- `_build/` - Compiled artifacts

**Benefits:**
- Faster CI runs (~2-3 minutes saved)
- Reduced network usage
- Consistent builds

### PLT Cache

**Key:** `os-plt-otp-elixir-mix.lock`

Caches:
- `priv/plts/` - Dialyzer PLT files

**Benefits:**
- Dialyzer runs in ~1 minute instead of ~10 minutes
- Only rebuilds when dependencies change

### NPM Cache

**Key:** `node-version-package-lock.json`

Caches:
- `node_modules/` - NPM dependencies

**Benefits:**
- Faster asset builds
- Consistent frontend dependencies

## Best Practices

### Before Committing

1. **Run precommit checks:**
   ```bash
   mix precommit
   ```

2. **Fix formatting issues:**
   ```bash
   mix format
   ```

3. **Address Credo warnings:**
   ```bash
   mix credo --strict
   ```

4. **Ensure tests pass:**
   ```bash
   mix test
   ```

### Writing Tests

1. **Use descriptive test names:**
   ```elixir
   test "creates node with valid attributes" do
   ```

2. **Test edge cases:**
   - Empty inputs
   - Invalid data
   - Boundary conditions

3. **Use setup blocks for common data:**
   ```elixir
   setup do
     graph = FlowGraph.new()
     {:ok, graph: graph}
   end
   ```

### Code Quality

1. **Add module documentation:**
   ```elixir
   @moduledoc """
   Handles graph operations and transformations.
   """
   ```

2. **Keep functions focused:**
   - Single responsibility
   - Max 20-30 lines
   - Extract complex logic

3. **Use typespecs:**
   ```elixir
   @spec add_node(t(), String.t(), atom()) :: {:ok, t()} | {:error, term()}
   ```

## Troubleshooting

### CI Failing on Format Check

```bash
# Fix locally
mix format

# Commit changes
git add .
git commit -m "Fix formatting"
```

### CI Failing on Credo

```bash
# See all issues
mix credo list

# Fix issues or add inline exceptions
# credo:disable-for-next-line
```

### CI Failing on Dialyzer

```bash
# Run locally to see issues
mix dialyzer

# Common fixes:
# - Add typespecs
# - Fix return types
# - Add @dialyzer ignore for false positives
```

### CI Failing on Tests

```bash
# Run tests with more detail
mix test --trace

# Run specific test file
mix test test/path/to/test.exs

# Run specific test line
mix test test/path/to/test.exs:42
```

### Dependency Audit Failures

```bash
# See vulnerable dependencies
mix deps.audit

# Update dependencies
mix deps.update dependency_name

# Or update all
mix deps.update --all
```

## Performance

### Typical CI Run Times

- **Test Matrix**: ~3-5 minutes per version
- **Code Quality**: ~1-2 minutes
- **Assets**: ~1-2 minutes
- **Dialyzer**: ~1-2 minutes (with cache)

**Total**: ~5-8 minutes for full pipeline

### Optimization Tips

1. **Use caching** - Already configured
2. **Parallel jobs** - Already configured
3. **Fail fast** - Set to false for test matrix
4. **Minimal dependencies** - Only install what's needed

## Security

### Dependency Auditing

Automatically checks for:
- Known security vulnerabilities
- Outdated dependencies
- License issues

### Best Practices

1. **Keep dependencies updated:**
   ```bash
   mix deps.update --all
   ```

2. **Review security advisories:**
   - Check GitHub Security tab
   - Monitor Elixir security mailing list

3. **Use lock file:**
   - Always commit `mix.lock`
   - Ensures reproducible builds

## Future Enhancements

### Planned Improvements

1. **Deploy Job**: Automatic deployment on main branch
2. **Release Automation**: Semantic versioning and changelog
3. **Performance Benchmarks**: Track performance over time
4. **E2E Tests**: Browser-based integration tests
5. **Docker Build**: Container image creation
6. **Dependency Updates**: Automated PR for updates

### Optional Additions

1. **Code Coverage Badges**: Display coverage in README
2. **Slack Notifications**: Alert on failures
3. **Staging Deployments**: Deploy PRs to staging
4. **Load Testing**: Performance under load
5. **Security Scanning**: SAST/DAST tools

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Credo Documentation](https://hexdocs.pm/credo)
- [Dialyzer Documentation](https://hexdocs.pm/dialyxir)
- [ExCoveralls Documentation](https://hexdocs.pm/excoveralls)
- [Elixir CI Best Practices](https://github.com/dwyl/learn-elixir#continuous-integration)

## Support

For CI/CD issues:
1. Check this documentation
2. Review GitHub Actions logs
3. Run checks locally to reproduce
4. Check dependency compatibility
5. Open an issue if needed

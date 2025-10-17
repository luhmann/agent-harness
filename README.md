# Claude Code Docker Sandbox

A secure, hardened Docker environment for running Claude Code autonomously in "yolo mode" (full permissions) while maintaining isolation from your host system.

## Features

- **Isolated Sandbox**: Claude Code runs with full permissions inside a Docker container, keeping your host system safe
- **Mise Integration**: Flexible runtime management with per-project version control (Node.js, Python, Elixir, and more)
- **Hybrid Authentication**: Login once, credentials persist across container restarts
- **Security Hardened**: Non-root user, dropped capabilities, resource limits, network isolation options
- **Project Management**: Easy creation and management of multiple sandboxed projects
- **Yolo Mode**: Claude Code runs with `--dangerously-skip-permissions` for autonomous operation

## Quick Start

### 1. Prerequisites

- **Docker Desktop** (or Docker Engine + Docker Compose)
- At least 4GB RAM available for Docker
- Claude Code account (claude.ai or Claude Console API)

### 2. Clone or Create Project

```bash
# If you cloned this repository, you're already here!
cd agent-harness-claude
```

### 3. Create Your First Project

```bash
./scripts/init-project.sh my-first-project
```

This creates a new project in `./projects/my-first-project` with:
- `.mise.toml` for runtime configuration
- Git repository initialized
- README with usage instructions

### 4. Run Claude Code

```bash
./scripts/run-claude.sh my-first-project
```

On first run, this will:
1. Build the Docker image (takes 5-10 minutes)
2. Start the container
3. Initialize authentication (copy from host or prompt for login)
4. Launch Claude Code in yolo mode

### 5. Start Building

Once Claude Code launches, you're ready to go! Try asking:

> "Create a simple Express.js web server with a health check endpoint"

Claude will autonomously write code, install dependencies, and run the project - all safely sandboxed.

## Project Structure

```
agent-harness-claude/
├── Dockerfile                 # Multi-stage build with mise + Claude Code
├── docker-compose.yml         # Service definition with security configs
├── .mise.toml.template       # Runtime version template
├── .env.example              # Environment configuration template
├── .dockerignore             # Build context exclusions
├── projects/                 # Your sandboxed projects live here
│   ├── project-1/
│   ├── project-2/
│   └── ...
├── scripts/
│   ├── run-claude.sh        # Main entry point - start Claude Code
│   ├── init-project.sh      # Create new project
│   ├── attach.sh            # Direct shell access to container
│   ├── cleanup.sh           # Stop/remove container and volumes
│   └── init-auth.sh         # Authentication initialization (internal)
└── README.md                # This file
```

## Usage

### Creating Projects

```bash
# Create a new project
./scripts/init-project.sh <project-name>

# Example
./scripts/init-project.sh my-api
```

### Running Claude Code

```bash
# Run Claude Code for a specific project
./scripts/run-claude.sh <project-name>

# Example
./scripts/run-claude.sh my-api

# Run default project (sandbox)
./scripts/run-claude.sh
```

### Managing Runtimes with Mise

Each project has a `.mise.toml` file that defines which runtime versions to use:

```toml
[tools]
node = "22"        # Node.js 22.x
python = "3.12"    # Python 3.12.x
erlang = "27"      # Erlang 27.x (required for Elixir)
elixir = "1.17"    # Elixir 1.17.x
```

**Change versions**: Edit `.mise.toml` in your project directory

**Available runtimes**: node, python, erlang, elixir, go, rust, ruby, java, and [many more](https://mise.jdx.dev/lang/)

**Apply changes**: Restart Claude Code - mise will automatically install new versions

### Container Management

```bash
# Get shell access to container (for debugging)
./scripts/attach.sh

# Stop container (keeps data)
./scripts/cleanup.sh

# Full cleanup (removes everything except project files)
./scripts/cleanup.sh --full
```

### Resource Configuration

Create `.env` from template:

```bash
cp .env.example .env
```

Customize resource limits:

```bash
# .env
MEMORY_LIMIT=8g      # Increase memory to 8GB
CPU_LIMIT=4.0        # Use 4 CPU cores
```

Restart container for changes to take effect.

## Authentication

### Hybrid Authentication Strategy

This setup uses a "hybrid" authentication approach:

1. **First Run**: If you have Claude Code installed on your host and are logged in, credentials are copied to the container automatically
2. **Manual Login**: If no host credentials exist, you'll be prompted to login once inside Claude Code using `/login`
3. **Persistence**: After successful login, credentials are stored in a Docker volume and persist across container restarts

### Logging In

If you need to manually authenticate:

1. When Claude Code starts, run: `/login`
2. Choose your account type:
   - **Claude.ai** (recommended) - Use your Claude subscription
   - **Claude Console** - Use API credits
3. Complete authentication in your browser
4. Credentials are automatically saved

### Switching Accounts

To switch accounts or re-authenticate:

```bash
# Inside Claude Code
/login
```

## Security Model

### What's Protected

✅ **Host filesystem** - Only `./projects/` is accessible
✅ **Host processes** - Completely isolated from container
✅ **Other containers** - No access to other Docker containers
✅ **System configuration** - Host system settings are protected
✅ **Resource exhaustion** - CPU and memory limits prevent overuse

### What's NOT Protected

❌ **Internet access** - Container has full network access for package installation
❌ **Docker daemon** - Not mounted (preventing container escapes)
❌ **Project files** - Claude has full read/write access to your project directory

### Security Features

- **Non-root execution**: Container runs as user `claudedev` (UID 1000)
- **Dropped capabilities**: All Linux capabilities dropped by default
- **Resource limits**: Configurable CPU, memory, and process limits
- **No privilege escalation**: `no-new-privileges` security option enabled
- **Read-only scripts**: Helper scripts mounted read-only

### Yolo Mode Implications

Claude Code runs with `--dangerously-skip-permissions`, meaning:

- **Instant execution**: No approval prompts for commands
- **Full autonomy**: Claude can install packages, modify files, run servers
- **Sandboxed**: But everything happens inside the container

**Recommendation**: Review what Claude is building periodically, especially before deploying code.

## Advanced Topics

### Adding More Languages

Edit `.mise.toml` in your project:

```toml
[tools]
node = "22"
python = "3.12"
go = "1.22"          # Add Go
rust = "1.75"        # Add Rust
ruby = "3.3"         # Add Ruby
```

Mise will install them automatically on next run.

### Custom Environment Variables

Add to your project's `.mise.toml`:

```toml
[env]
DATABASE_URL = "postgresql://localhost/mydb"
API_KEY = "dev-key-123"
NODE_ENV = "development"
```

### Running Multiple Projects

Each project is isolated:

```bash
# Terminal 1
./scripts/run-claude.sh project-a

# Terminal 2
./scripts/attach.sh
cd /workspace/project-b
claude --dangerously-skip-permissions
```

### Debugging

**Get shell access**:
```bash
./scripts/attach.sh
```

**Check mise installations**:
```bash
mise list
```

**Verify authentication**:
```bash
cat ~/.claude/.credentials.json | jq .
```

**Check container resources**:
```bash
docker stats claude-agent-sandbox
```

### Limiting Network Access

To restrict network access, modify `docker-compose.yml`:

```yaml
services:
  claude-sandbox:
    # Add network mode
    network_mode: none  # Complete isolation
    # OR
    networks:
      - limited-network

networks:
  limited-network:
    driver: bridge
    # Add firewall rules as needed
```

## Troubleshooting

### Build Fails

**Issue**: Docker build fails with error
**Solution**: Ensure you have at least 10GB free disk space and good internet connection

```bash
# Clean Docker cache
docker system prune -a

# Rebuild
./scripts/run-claude.sh
```

### Authentication Not Persisting

**Issue**: Have to login every time
**Solution**: Check volume is created correctly

```bash
# Verify volume exists
docker volume ls | grep claude-config

# If missing, recreate
./scripts/cleanup.sh --full
./scripts/run-claude.sh
```

### Mise Can't Install Runtimes

**Issue**: mise fails to install Node/Python/etc.
**Solution**: Check internet connectivity and mise cache

```bash
# Inside container
./scripts/attach.sh

# Clear mise cache
rm -rf ~/.local/share/mise/cache/*

# Try manual install
mise install node@22
```

### Container Out of Memory

**Issue**: Container crashes or becomes unresponsive
**Solution**: Increase memory limit

```bash
# Edit .env
echo "MEMORY_LIMIT=8g" >> .env

# Restart
./scripts/cleanup.sh
./scripts/run-claude.sh
```

### Permission Denied Errors

**Issue**: Can't write files inside container
**Solution**: Check volume permissions

```bash
# Ensure project directory exists
mkdir -p ./projects/your-project

# If on Linux, check ownership
ls -la ./projects/
# Should be writable by your user
```

## FAQ

**Q: How much does this cost?**
A: The Docker setup is free. You need a Claude Code account (Claude.ai subscription or Claude Console API credits).

**Q: Can I use this in production?**
A: This is designed for development/testing. For production, review security settings carefully and consider additional hardening.

**Q: Does this work on Windows?**
A: Yes, with Docker Desktop for Windows. WSL2 is recommended for best performance.

**Q: Can Claude access my other projects?**
A: No, only the specific project directory you're working in is mounted in the container.

**Q: How do I update Claude Code?**
A: Rebuild the image:
```bash
./scripts/cleanup.sh --full
./scripts/run-claude.sh
```

**Q: Can I run this on a remote server?**
A: Yes, but you'll need to handle authentication differently (web-based login may not work on headless servers).

**Q: What if I need root access inside the container?**
A: Use `docker exec -it --user root claude-agent-sandbox bash`, but understand this weakens security.

## Performance Tips

1. **Resource allocation**: Allocate at least 4GB RAM and 2 CPU cores
2. **SSD recommended**: Use SSD storage for better mise performance
3. **Mise cache**: Persistent mise cache (via volume) speeds up repeated installs
4. **Project size**: Keep projects focused; split large codebases into multiple projects

## References

- [Claude Code Documentation](https://docs.claude.com/claude-code)
- [Mise Documentation](https://mise.jdx.dev/)
- [Docker Security Best Practices](https://docs.docker.com/develop/security-best-practices/)
- [Claude Code GitHub](https://github.com/anthropics/claude-code)

## Contributing

Found an issue or have an improvement? Feel free to:

1. Open an issue describing the problem
2. Submit a pull request with fixes
3. Share your use cases and configurations

## License

This project structure is provided as-is for use with Claude Code. Refer to Claude Code's license for the actual CLI tool.

---

**Happy autonomous coding!** 🚀

Remember: Claude Code in yolo mode is powerful but sandboxed. Review generated code before deploying to production.

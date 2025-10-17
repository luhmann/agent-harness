# AI Agent Harness

A secure, hardened Docker environment for running AI coding agents (Claude Code & Codex CLI) autonomously in "yolo mode" (full permissions) while maintaining isolation from your host system.

## Features

- **Multi-Agent Support**: Choose between Claude Code (Anthropic) or Codex CLI (OpenAI) interchangeably
- **Isolated Sandbox**: AI agents run with full permissions inside a Docker container, keeping your host system safe
- **Mise Integration**: Flexible runtime management with per-project version control (Node.js, Python, Elixir, and more)
- **Hybrid Authentication**: Login once for each agent, credentials persist across container restarts
- **Security Hardened**: Non-root user, dropped capabilities, resource limits, network isolation options
- **Project Management**: Easy creation and management of multiple sandboxed projects
- **Yolo Mode**: Both agents run in full autonomous mode (`--dangerously-skip-permissions` / `full-access`)

## Quick Start

### 1. Prerequisites

- **Docker Desktop** (or Docker Engine + Docker Compose)
- At least 4GB RAM available for Docker
- **At least one** of the following:
  - Claude Code account (claude.ai or Claude Console API)
  - ChatGPT Plus/Pro/Team/Enterprise account (for Codex CLI)

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

### 4. Run an AI Agent

```bash
./scripts/run-agent.sh my-first-project
```

This will:
1. Build the Docker image (takes 5-10 minutes on first run)
2. Start the container
3. Initialize authentication for both agents
4. Show an interactive menu to select your agent:
   - **Claude Code** (Anthropic) - Surgical edits, multi-step tasks
   - **Codex CLI** (OpenAI) - Fast, open-source, community-driven

Or launch a specific agent directly:
```bash
./scripts/run-claude.sh my-first-project  # Claude Code
./scripts/run-codex.sh my-first-project   # Codex CLI
```

### 5. Start Building

Once your chosen agent launches, you're ready to go! Try asking:

> "Create a simple Express.js web server with a health check endpoint"

The AI agent will autonomously write code, install dependencies, and run the project - all safely sandboxed.

### 6. Global Installation (Optional)

For convenience, you can install the agent commands globally so they're available from any directory:

```bash
# Run the installer
./scripts/install.sh
```

This creates symlinks in `~/.local/bin` and adds it to your PATH. After installation, you can use commands from anywhere:

```bash
# From any project directory
cd ~/my-existing-project
spawn-agent auth feature/auth claude
list-agents
attach-agent auth
kill-agent auth
```

**Uninstall:**
```bash
./scripts/install.sh --uninstall
```

**Available global commands:**
- `spawn-agent` - Spawn parallel agents on feature branches
- `list-agents` - List all running agents
- `attach-agent` - Attach to an agent's terminal
- `kill-agent` - Stop and cleanup agents
- `logs-agent` - View agent container logs

See the [Parallel Development Workflow](#parallel-development-workflow) section for details on using these commands.

## Project Structure

```
agent-harness/
├── Dockerfile                 # Multi-stage build with mise + both agents
├── docker-compose.yml         # Service definition with security configs
├── .mise.toml.template       # Runtime version template
├── .env.example              # Environment configuration template
├── .dockerignore             # Build context exclusions
├── projects/                 # Your sandboxed projects live here
│   ├── project-1/
│   ├── project-2/
│   └── ...
├── scripts/
│   ├── run-agent.sh         # Interactive agent selector (main entry)
│   ├── run-claude.sh        # Direct Claude Code launcher
│   ├── run-codex.sh         # Direct Codex CLI launcher
│   ├── init-project.sh      # Create new project
│   ├── spawn-agent.sh       # Spawn parallel agents (git worktrees)
│   ├── list-agents.sh       # List all parallel agents
│   ├── attach-agent.sh      # Attach to parallel agent session
│   ├── kill-agent.sh        # Stop and cleanup parallel agents
│   ├── logs-agent.sh        # View parallel agent logs
│   ├── install.sh           # Install commands globally
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

### Running an AI Agent

```bash
# Interactive menu to select agent
./scripts/run-agent.sh <project-name>

# Example
./scripts/run-agent.sh my-api

# Or launch a specific agent directly
./scripts/run-claude.sh <project-name>  # Claude Code
./scripts/run-codex.sh <project-name>   # Codex CLI

# Run default project (sandbox)
./scripts/run-agent.sh
```

**Choosing Your Agent:**

| Feature | Claude Code | Codex CLI |
|---------|-------------|-----------|
| Provider | Anthropic | OpenAI |
| Auth | Claude.ai account | ChatGPT Plus/Pro/Team |
| License | Proprietary | Open Source (Apache 2) |
| Strengths | Surgical edits, multi-step tasks | Fast, simple tasks |
| Mode | `--dangerously-skip-permissions` | `--approval full-access` |

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

**Apply changes**: Restart your agent - mise will automatically install new versions

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

This setup uses a "hybrid" authentication approach for **both agents**:

1. **First Run**: If you have the agent installed on your host and are logged in, credentials are copied to the container automatically
2. **Manual Login**: If no host credentials exist, you'll be prompted to login once inside the agent
3. **Persistence**: After successful login, credentials are stored in Docker volumes and persist across container restarts

### Logging In

**Claude Code:**
1. When Claude Code starts, run: `/login`
2. Choose your account type:
   - **Claude.ai** (recommended) - Use your Claude subscription
   - **Claude Console** - Use API credits
3. Complete authentication in your browser
4. Credentials saved in `claude-config` volume

**Codex CLI:**
1. When Codex CLI starts, run: `codex login`
2. Authenticate with your **ChatGPT Plus/Pro/Team/Enterprise** account
3. Complete OAuth flow in your browser
4. Credentials saved in `codex-config` volume

### Switching Accounts

To switch accounts or re-authenticate:

```bash
# Inside Claude Code
/login

# Inside Codex CLI
codex login
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
❌ **Project files** - AI agents have full read/write access to your project directory

### Security Features

- **Non-root execution**: Container runs as user `claudedev` (UID 1000)
- **Dropped capabilities**: All Linux capabilities dropped by default
- **Resource limits**: Configurable CPU, memory, and process limits
- **No privilege escalation**: `no-new-privileges` security option enabled
- **Read-only scripts**: Helper scripts mounted read-only

### Autonomous Mode Implications

Both agents run in autonomous mode:
- **Claude Code**: `--dangerously-skip-permissions`
- **Codex CLI**: `--approval full-access`

This means:
- **Instant execution**: No approval prompts for commands
- **Full autonomy**: Agents can install packages, modify files, run servers
- **Sandboxed**: But everything happens inside the container

**Recommendation**: Review what AI agents are building periodically, especially before deploying code.

## Advanced Topics

### Parallel Development Workflow

The agent harness supports spawning multiple AI agents in parallel, each working on different features/branches in isolation using **git worktrees**. This allows you to:

- Work on multiple features simultaneously with different agents
- Keep each agent isolated in its own branch and container
- Avoid conflicts between parallel development efforts
- Test different approaches to the same problem

#### What are Git Worktrees?

Git worktrees allow you to check out multiple branches simultaneously in different directories. Each worktree:
- Has its own working directory
- Is connected to the same repository
- Can be on a different branch
- Shares the same git history and configuration

Perfect for parallel AI agent development!

#### Spawning a Parallel Agent

**Note:** After running `./scripts/install.sh`, you can use these commands from anywhere without the `./scripts/` prefix. Examples below show both forms.

Create a new agent working on a feature in isolation:

```bash
# Basic usage - creates new branch
./scripts/spawn-agent.sh feature-auth
# or if globally installed:
spawn-agent feature-auth

# Specify existing branch and agent type
./scripts/spawn-agent.sh api-endpoints feature/api-endpoints claude

# With a task to start immediately
./scripts/spawn-agent.sh bugfix-123 main codex --task "Fix the login timeout bug"

# With a task from a file, in detached mode
./scripts/spawn-agent.sh refactor feature/refactor --task-file tasks/db-refactor.txt --detach
```

**What happens:**
1. Creates git worktree in `.worktrees/<feature-name>`
2. Checks out specified branch (or creates new one)
3. Starts a Docker container named `agent-harness-<feature-name>`
4. Copies `.mise.toml.template` if needed
5. Launches agent in a tmux session named `agent-<feature-name>`
6. Optionally sends a task to the agent

**Arguments:**
- `<feature-name>` - Required. Name for this agent instance
- `[branch]` - Optional. Git branch to use (default: `feature/<feature-name>`)
- `[agent-type]` - Optional. 'claude' or 'codex' (shows menu if not specified)

**Options:**
- `--task "text"` - Send task to agent after startup
- `--task-file FILE` - Send task from file to agent
- `--detach` - Start in background (don't attach to tmux session)

#### Managing Parallel Agents

**List all agents:**
```bash
./scripts/list-agents.sh
```

Output shows:
- Feature name
- Container status (running/stopped)
- Git branch
- Agent type (if running)
- Uptime

**Attach to an agent:**
```bash
./scripts/attach-agent.sh feature-auth
```

Attaches to the tmux session. Press `Ctrl+B` then `D` to detach.

**View agent logs:**
```bash
# View all logs
./scripts/logs-agent.sh feature-auth

# Last 100 lines
./scripts/logs-agent.sh feature-auth --tail 100

# Follow logs in real-time
./scripts/logs-agent.sh feature-auth --follow

# Combine options
./scripts/logs-agent.sh feature-auth --tail 50 --follow
```

**Stop an agent:**
```bash
# Stop agent but keep worktree
./scripts/kill-agent.sh feature-auth

# Stop agent and remove worktree
./scripts/kill-agent.sh feature-auth --remove-worktree
```

The script will:
1. Stop and remove the Docker container
2. Kill the tmux session
3. Optionally remove the git worktree (with confirmation)
4. Warn if worktree has uncommitted changes

#### Example Workflow

**Scenario:** Work on authentication and API endpoints simultaneously

```bash
# Terminal 1 - Spawn agent for authentication feature
./scripts/spawn-agent.sh auth feature/auth claude --task "Implement JWT authentication"
# Agent starts working on auth in .worktrees/auth

# Terminal 2 - Spawn agent for API endpoints
./scripts/spawn-agent.sh api feature/api-endpoints codex --task "Create REST API for user management"
# Agent starts working on API in .worktrees/api

# Terminal 3 - Monitor both agents
./scripts/list-agents.sh

# Check logs from auth agent
./scripts/logs-agent.sh auth --tail 50

# Attach to API agent to provide more guidance
./scripts/attach-agent.sh api
# (work with agent, then Ctrl+B D to detach)

# When auth is done, review and merge
cd .worktrees/auth
git status
git add .
git commit -m "Implement JWT authentication"
git push origin feature/auth

# Stop the auth agent
./scripts/kill-agent.sh auth --remove-worktree

# Merge to main
git checkout main
git merge feature/auth

# Continue working with API agent...
./scripts/attach-agent.sh api
```

#### Merging Work Back to Main Branch

After an agent completes work on a feature:

**1. Review the changes:**
```bash
cd .worktrees/<feature-name>
git status
git diff
```

**2. Commit and push:**
```bash
cd .worktrees/<feature-name>
git add .
git commit -m "Implement feature X"
git push origin <branch-name>
```

**3. Merge to main:**
```bash
# Go back to main repo
cd ../..

# Merge the branch
git checkout main
git merge <branch-name>
git push
```

**4. Clean up:**
```bash
# Remove the agent and worktree
./scripts/kill-agent.sh <feature-name> --remove-worktree

# Delete remote branch if needed
git push origin --delete <branch-name>
```

#### Tips for Parallel Development

**Best Practices:**
- Use descriptive feature names: `auth`, `api-v2`, `bugfix-login`, `refactor-db`
- Keep features focused and independent to avoid conflicts
- Regularly commit and push from worktrees
- Review work before merging to main
- Clean up completed agents to save resources

**Resource Management:**
- Each container uses memory (default 4GB) and CPU (default 2 cores)
- Monitor with: `docker stats`
- Adjust limits in `.env` if needed: `MEMORY_LIMIT=2g`, `CPU_LIMIT=1.0`

**Handling Conflicts:**
- Worktrees share the same git repository
- If branches conflict, resolve before merging
- Use `git status` in each worktree to check state

**Debugging:**
- Container not starting? Check: `docker logs agent-harness-<feature-name>`
- Tmux session gone? Container might have crashed, check logs
- Worktree issues? Use: `git worktree list` and `git worktree repair`

**Limitations:**
- Cannot checkout the same branch in multiple worktrees
- Worktrees share git configuration and hooks
- Container names must be unique (feature names must differ)

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
# Terminal 1 - Claude Code on project-a
./scripts/run-claude.sh project-a

# Terminal 2 - Codex CLI on project-b
./scripts/run-codex.sh project-b

# Or attach and launch manually
./scripts/attach.sh
cd /workspace/project-b
codex --approval full-access
```

### Connecting to Host Databases

The container is configured to access databases and services running on your **host machine** using the special hostname `host.docker.internal`.

#### Connection Examples

**PostgreSQL on host:**
```bash
# Inside container (in your AI agent project)
postgresql://username:password@host.docker.internal:5432/dbname
```

**MySQL on host:**
```bash
mysql://username:password@host.docker.internal:3306/dbname
```

**MongoDB on host:**
```bash
mongodb://username:password@host.docker.internal:27017/dbname
```

**Redis on host:**
```bash
redis://host.docker.internal:6379
```

**HTTP services on host:**
```bash
http://host.docker.internal:8080
```

#### Usage in Code

**Node.js example:**
```javascript
const { Client } = require('pg');
const client = new Client({
  host: 'host.docker.internal',
  port: 5432,
  database: 'mydb',
  user: 'myuser',
  password: 'mypass'
});
```

**Python example:**
```python
import psycopg2

conn = psycopg2.connect(
    host="host.docker.internal",
    port=5432,
    database="mydb",
    user="myuser",
    password="mypass"
)
```

**Environment Variables:**

Store connection strings in your project's `.mise.toml`:

```toml
[env]
DATABASE_URL = "postgresql://user:pass@host.docker.internal:5432/mydb"
REDIS_URL = "redis://host.docker.internal:6379"
API_URL = "http://host.docker.internal:8080"
```

**Note**: Make sure your host database is configured to accept connections from Docker containers (typically listening on `0.0.0.0` or allowing connections from the Docker network).

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
# Claude Code
cat ~/.claude/.credentials.json | jq .

# Codex CLI
cat ~/.codex/config.toml
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
./scripts/run-agent.sh
```

### Authentication Not Persisting

**Issue**: Have to login every time
**Solution**: Check volumes are created correctly

```bash
# Verify volumes exist
docker volume ls | grep -E "(claude|codex)-config"

# If missing, recreate
./scripts/cleanup.sh --full
./scripts/run-agent.sh
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
./scripts/run-agent.sh
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
A: The Docker setup is free. You need at least one of: Claude Code account (Claude.ai subscription or Claude Console API) OR ChatGPT Plus/Pro/Team account (for Codex CLI).

**Q: Which agent should I use?**
A: **Claude Code** excels at surgical edits and complex multi-step tasks. **Codex CLI** is faster for simple tasks and is open-source. Try both and see which fits your workflow!

**Q: Can I use both agents on the same project?**
A: Yes! You can switch between agents or even run them in parallel in different terminals on different projects.

**Q: Can I use this in production?**
A: This is designed for development/testing. For production, review security settings carefully and consider additional hardening.

**Q: Does this work on Windows?**
A: Yes, with Docker Desktop for Windows. WSL2 is recommended for best performance.

**Q: Can agents access my other projects?**
A: No, only the specific project directory you're working in is mounted in the container.

**Q: Can agents connect to databases on my host machine?**
A: Yes! Use `host.docker.internal` as the hostname. For example: `postgresql://user:pass@host.docker.internal:5432/dbname`. See the "Connecting to Host Databases" section for details.

**Q: How do I update the agents?**
A: Rebuild the image:
```bash
./scripts/cleanup.sh --full
./scripts/run-agent.sh
```

**Q: Can I run this on a remote server?**
A: Yes, but you'll need to handle authentication differently (web-based login may not work on headless servers).

**Q: What if I need root access inside the container?**
A: Use `docker exec -it --user root claude-agent-sandbox bash`, but understand this weakens security.

**Q: Do I need accounts for both agents?**
A: No, you only need an account for the agent(s) you want to use.

## Performance Tips

1. **Resource allocation**: Allocate at least 4GB RAM and 2 CPU cores
2. **SSD recommended**: Use SSD storage for better mise performance
3. **Mise cache**: Persistent mise cache (via volume) speeds up repeated installs
4. **Project size**: Keep projects focused; split large codebases into multiple projects

## References

- [Claude Code Documentation](https://docs.claude.com/claude-code)
- [Claude Code GitHub](https://github.com/anthropics/claude-code)
- [Codex CLI Documentation](https://developers.openai.com/codex/cli)
- [Codex CLI GitHub](https://github.com/openai/codex)
- [Mise Documentation](https://mise.jdx.dev/)
- [Docker Security Best Practices](https://docs.docker.com/develop/security-best-practices/)

## Contributing

Found an issue or have an improvement? Feel free to:

1. Open an issue describing the problem
2. Submit a pull request with fixes
3. Share your use cases and configurations

## License

This project structure is provided as-is for use with AI coding agents. Refer to each agent's license:
- Claude Code: Proprietary (Anthropic)
- Codex CLI: Apache 2.0 (OpenAI)

---

**Happy autonomous coding!** 🚀

Remember: AI agents in autonomous mode are powerful but sandboxed. Review generated code before deploying to production.

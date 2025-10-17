# Dockerfile for Claude Code Sandbox with Mise-managed Runtimes
# Multi-stage build for minimal final image size

# ============================================================================
# Stage 1: Builder - Install mise and pre-install runtimes
# ============================================================================
FROM ubuntu:24.04 AS builder

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    ca-certificates \
    build-essential \
    libssl-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Install mise as root for builder stage
RUN curl https://mise.run | sh

# Set mise environment for builder
ENV MISE_DATA_DIR=/usr/local/share/mise
ENV MISE_CACHE_DIR=/usr/local/share/mise/cache
ENV PATH="/root/.local/bin:$PATH"

# Create mise directory
RUN mkdir -p /usr/local/share/mise

# Pre-install runtimes with mise
# This speeds up container startup significantly
RUN mise use --global node@22 && \
    mise use --global python@3.12 && \
    mise use --global erlang@27 && \
    mise use --global elixir@1.17

# Install Claude Code globally via npm
RUN mise exec node@22 -- npm install -g @anthropic-ai/claude-code

# Install Codex CLI globally via npm
RUN mise exec node@22 -- npm install -g @openai/codex

# Verify both CLIs are installed
RUN mise exec node@22 -- claude --version && \
    mise exec node@22 -- codex --version

# ============================================================================
# Stage 2: Runtime - Minimal production image
# ============================================================================
FROM ubuntu:24.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies only (no build tools)
RUN apt-get update && apt-get install -y \
    curl \
    git \
    ca-certificates \
    gnupg \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user (claudedev with UID 1000)
RUN useradd -m -u 1000 -s /bin/bash claudedev

# Copy mise and installed runtimes from builder
COPY --from=builder /root/.local/bin/mise /usr/local/bin/mise
COPY --from=builder /usr/local/share/mise /home/claudedev/.local/share/mise
COPY --from=builder /root/.local/share/mise/installs /home/claudedev/.local/share/mise/installs

# Set up mise environment for claudedev user
ENV MISE_DATA_DIR=/home/claudedev/.local/share/mise
ENV MISE_CACHE_DIR=/home/claudedev/.local/share/mise/cache
ENV PATH="/home/claudedev/.local/share/mise/shims:/home/claudedev/.local/bin:/usr/local/bin:$PATH"

# Create directory structure
RUN mkdir -p /workspace && \
    mkdir -p /home/claudedev/.claude && \
    mkdir -p /home/claudedev/.codex && \
    mkdir -p /home/claudedev/.local/share/mise && \
    mkdir -p /home/claudedev/.local/bin && \
    mkdir -p /scripts

# Set ownership to claudedev
RUN chown -R claudedev:claudedev /workspace && \
    chown -R claudedev:claudedev /home/claudedev

# Switch to non-root user
USER claudedev

# Set working directory
WORKDIR /workspace

# Default command (will be overridden by docker-compose)
CMD ["/bin/bash"]

# Labels for documentation
LABEL maintainer="AI Agent Harness"
LABEL description="Hardened Docker sandbox for running Claude Code and Codex CLI autonomously with mise-managed runtimes"
LABEL version="1.1"
LABEL agents="claude-code,codex-cli"

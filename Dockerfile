# Build stage
FROM elixir:1.17-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    nodejs \
    npm \
    openssl-dev \
    ncurses-dev

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build environment
ENV MIX_ENV=prod

# Create app directory
WORKDIR /app

# Copy mix files
COPY mix.exs mix.lock ./
COPY config config

# Install dependencies
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy application code
COPY lib lib
COPY priv priv

# Compile application
RUN mix compile

# Build release
RUN mix release

# Runtime stage
FROM alpine:3.19 AS runtime

# Install runtime dependencies
RUN apk add --no-cache \
    openssl \
    ncurses-libs \
    libstdc++ \
    libgcc \
    curl

# Create app user
RUN addgroup -g 1000 vsmcp && \
    adduser -u 1000 -G vsmcp -s /bin/sh -D vsmcp

# Create app directory
WORKDIR /app

# Copy release from builder
COPY --from=builder --chown=vsmcp:vsmcp /app/_build/prod/rel/vsmcp ./

# Create data directory
RUN mkdir -p /app/data && chown -R vsmcp:vsmcp /app/data

# Switch to app user
USER vsmcp

# Set environment
ENV HOME=/app
ENV MIX_ENV=prod
ENV REPLACE_OS_VARS=true
ENV POOL_SIZE=10

# Expose ports
# 4010 - MCP server
# 9568 - Metrics/Health endpoint
# 4369 - Erlang Port Mapper Daemon (epmd)
# 9100-9105 - Erlang distribution
EXPOSE 4010 9568 4369 9100-9105

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:9568/health || exit 1

# Set entrypoint
ENTRYPOINT ["bin/vsmcp"]

# Default command
CMD ["start"]
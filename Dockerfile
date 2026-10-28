# --- Build stage: compile TypeScript ---
FROM node:22-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npm run build && npm prune --omit=dev

# --- Runtime stage ---
FROM node:22-slim

ARG CLAUDE_CODE_VERSION=latest
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} \
    && npm cache clean --force

WORKDIR /app
COPY --from=build /app/package.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist

# Empty, isolated working directory for the Claude CLI subprocesses
RUN mkdir -p /workspace /home/node/.claude && chown -R node:node /workspace /home/node

ENV NODE_ENV=production \
    HOST=0.0.0.0 \
    HOME=/home/node \
    CLAUDE_CONFIG_DIR=/home/node/.claude \
    DISABLE_AUTOUPDATER=1

# Claude CLI refuses --dangerously-skip-permissions as root
USER node
WORKDIR /workspace

EXPOSE 3456
CMD ["node", "/app/dist/server/standalone.js", "3456"]

# ─────────────────────────────────────────────
# Stage 1: builder — install deps + run tests
# ─────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /build

COPY app/package*.json ./
RUN npm ci --include=dev

COPY app/ ./
RUN npm test

# Prune dev deps for the runtime image
RUN npm prune --omit=dev


# ─────────────────────────────────────────────
# Stage 2: runtime — minimal alpine image
# ─────────────────────────────────────────────
FROM node:20-alpine AS runtime

RUN apk add --no-cache tini curl \
    && addgroup -S app && adduser -S app -G app

WORKDIR /app

COPY --from=builder --chown=app:app /build/node_modules ./node_modules
COPY --from=builder --chown=app:app /build/package*.json ./
COPY --from=builder --chown=app:app /build/server.js ./
COPY --from=builder --chown=app:app /build/routes ./routes

USER app

ARG BUILD_SHA=local
ARG APP_VERSION=dev
ENV BUILD_SHA=${BUILD_SHA} \
    APP_VERSION=${APP_VERSION} \
    NODE_ENV=production \
    PORT=3000

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -fsS http://localhost:3000/health/live || exit 1

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "server.js"]

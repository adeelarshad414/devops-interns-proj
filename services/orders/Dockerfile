# syntax=docker/dockerfile:1

# ---------- deps ----------
FROM node:22-alpine AS deps
WORKDIR /app
COPY services/orders/package.json services/orders/package-lock.json ./services/orders/
COPY services/_shared/package.json ./services/_shared/
WORKDIR /app/services/orders
# npm ci installs from the committed lockfile: reproducible, and it fails loudly
# if package.json and the lock have drifted. Never `npm install` in a build.
RUN npm ci --omit=dev --no-audit --no-fund

# ---------- runtime base ----------
FROM node:22-alpine AS base
ENV NODE_ENV=production
WORKDIR /app
RUN addgroup -S daig && adduser -S daig -G daig
COPY --from=deps /app/services/orders/node_modules ./services/orders/node_modules
COPY services/_shared ./services/_shared
COPY services/orders  ./services/orders
USER daig
EXPOSE 3001
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:3001/healthz',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"
WORKDIR /app/services/orders
CMD ["node", "src/index.js"]

# ---------- normal image ----------
# Carries a dev default so `docker run` works out of the box.
FROM base AS runtime
ENV DATABASE_URL=postgresql://daig:CHANGE_ME_DEV_ONLY@postgres:5432/daig

# ---------- the kickoff exercise ----------
# Identical code. No DATABASE_URL default. Run it bare and it exits 78 with a
# log line naming the missing variable. That log is the whole exercise.
#   docker build --target broken -t tkxel/daig-orders:broken -f services/orders/Dockerfile .
FROM base AS broken
LABEL org.opencontainers.image.description="Deliberately misconfigured. Teaching artifact - never deploy."
LABEL dev.tkxel.teaching-defect="missing DATABASE_URL, exits 78"

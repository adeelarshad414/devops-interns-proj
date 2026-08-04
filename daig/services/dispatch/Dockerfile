# syntax=docker/dockerfile:1
FROM node:22-alpine AS deps
WORKDIR /app/services/dispatch
COPY services/dispatch/package.json ./
RUN npm install --omit=dev --no-audit --no-fund

FROM node:22-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app
RUN addgroup -S daig && adduser -S daig -G daig
COPY --from=deps /app/services/dispatch/node_modules ./services/dispatch/node_modules
COPY services/_shared ./services/_shared
COPY services/dispatch ./services/dispatch
USER daig
EXPOSE 3003
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:3003/healthz',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"
WORKDIR /app/services/dispatch
CMD ["node", "src/index.js"]

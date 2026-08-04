# syntax=docker/dockerfile:1
FROM node:22-alpine AS deps
WORKDIR /app/services/kitchen
COPY services/kitchen/package.json ./
RUN npm install --omit=dev --no-audit --no-fund

FROM node:22-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app
RUN addgroup -S daig && adduser -S daig -G daig
COPY --from=deps /app/services/kitchen/node_modules ./services/kitchen/node_modules
COPY services/_shared ./services/_shared
COPY services/kitchen ./services/kitchen
USER daig
EXPOSE 3002
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:3002/healthz',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"
WORKDIR /app/services/kitchen
CMD ["node", "src/index.js"]

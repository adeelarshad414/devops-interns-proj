# syntax=docker/dockerfile:1
# TIER 1 - presentation. Deliberately build-step-free.
#
# A Vite/React build is more realistic, and it is also one more thing that can
# fail at 09:30 on a Tuesday and derail the day. The teaching subject this week
# is DevOps, not frontend tooling, so this tier is static assets behind nginx.
# To swap in React later: add a `FROM node:22-alpine AS build` stage that runs
# `npm ci && npm run build`, then COPY --from=build /app/dist to the html dir.
# Nothing else in the repo changes.
FROM nginx:1.27-alpine
COPY services/web/nginx.conf /etc/nginx/conf.d/default.conf
COPY services/web/public /usr/share/nginx/html
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1

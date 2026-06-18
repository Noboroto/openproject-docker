# Dockerfile.app
# Extends the official OpenProject 17-slim image with our custom plugins.
ARG TAG=17-slim

# -- Stage 1: Angular build --
# Standalone Team Planner CE Angular app (FullCalendar resource-timeline).
# Output: dist/teamplanner_ce/browser/{main.js,polyfills.js}
# Served as static files from /app/public/teamplanner_ce/.
FROM node:24.16.0-alpine AS angular-build
WORKDIR /build

# Install pnpm
RUN npm install -g pnpm@9 --quiet

# Copy lockfile + package.json for layer caching
COPY plugins/openproject-team-planner/frontend/package.json ./
COPY plugins/openproject-team-planner/frontend/pnpm-lock.yaml ./

# Allow native scripts (esbuild needs postinstall to download its alpine binary)
RUN pnpm config set unsafe-perm true
RUN pnpm install --frozen-lockfile

# Copy source and build
COPY plugins/openproject-team-planner/frontend/ ./
RUN pnpm run build

# -- Stage 2: Production image --
FROM openproject/openproject:${TAG}
USER root

# Angular static assets
COPY --from=angular-build /build/dist/teamplanner_ce/browser/ /app/public/teamplanner_ce/
RUN chown -R app:app /app/public/teamplanner_ce/

# Plugin sources
COPY plugins/        /app/plugins/
COPY Gemfile.plugins /app/Gemfile.plugins

# Re-resolve Bundler to pick up path-gems
WORKDIR /app
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential git \
    && bundle config unset --local deployment \
    && bundle config unset --local frozen \
    && bundle config set --local path '/app/vendor/bundle' \
    && BUNDLE_WITHOUT="" bundle install --jobs 4 --retry 3 \
    && chown -R app:app /app/vendor/bundle /app/Gemfile.lock /app/plugins 2>/dev/null || true

USER app

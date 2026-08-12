# syntax=docker/dockerfile:1

ARG RUBY_VERSION=3.3.6

# Shared base: runtime dependencies only.
FROM ruby:${RUBY_VERSION}-slim AS base

ENV LANG=C.UTF-8 \
  RAILS_ENV=production \
  BUNDLE_DEPLOYMENT=1 \
  BUNDLE_FROZEN=1 \
  BUNDLE_JOBS=4 \
  BUNDLE_PATH=/usr/local/bundle \
  BUNDLE_RETRY=3 \
  BUNDLE_WITHOUT="development test"

WORKDIR /usr/src/app

RUN apt-get update -qq \
  && apt-get install -yq --no-install-recommends libpq5 libvips42 \
  && rm -rf /var/lib/apt/lists/*

# Build stage: compilers and headers live here and are thrown away.
FROM base AS build

RUN apt-get update -qq \
  && apt-get install -yq --no-install-recommends \
    build-essential \
    libpq-dev \
  && rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle install \
  && rm -rf "${BUNDLE_PATH}"/ruby/*/cache

COPY . .

ARG SECRET_KEY_BASE=fakekeyforassets
RUN bundle exec rails assets:precompile

# Final image: gems and app only.
FROM base

COPY --from=build ${BUNDLE_PATH} ${BUNDLE_PATH}
COPY --from=build /usr/src/app /usr/src/app

ARG GIT_COMMIT
ENV GIT_COMMIT=$GIT_COMMIT

# Run as an unprivileged user. Only the directories written at runtime are
# owned by it, the code itself stays read-only.
RUN groupadd --system --gid 1000 rails \
  && useradd --system --uid 1000 --gid rails --create-home rails \
  && mkdir -p log tmp storage \
  && chown -R rails:rails log tmp storage
USER rails:rails

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]

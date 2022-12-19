FROM ruby:3.1.2-slim

RUN apt-get update -qq && apt-get install -yq --no-install-recommends \
    build-essential \
    gnupg2 \
    libpq-dev \
    git \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV LANG=C.UTF-8 \
  BUNDLE_JOBS=4 \
  BUNDLE_RETRY=3 \
  RAILS_ENV=production

RUN gem update --system && gem install bundler

WORKDIR /usr/src/app

COPY Gemfile* ./

RUN bundle config frozen true \
 && bundle config jobs 4 \
 && bundle config deployment true \
 && bundle config without 'development test' \
 && bundle install

COPY . .

ARG SECRET_KEY_BASE=fakekeyforassets
RUN bin/rails assets:clobber && bundle exec rails assets:precompile

ARG GIT_COMMIT
ENV GIT_COMMIT=$GIT_COMMIT

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]

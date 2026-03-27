# Ruby 2.7 is required: rspec ~> 2.8.0 and activerecord ~> 5.2.8 are
# incompatible with Ruby 3.x keyword argument changes.
FROM ruby:2.7-slim

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      libpq-dev \
      git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy only dependency files first so gem layer is cached separately from code
COPY Gemfile Gemfile.lock piggly.gemspec ./
# gemspec requires version.rb to be loadable at install time
COPY lib/piggly/version.rb lib/piggly/version.rb

ENV BUNDLE_PATH=/bundle

RUN bundle config set --local without '' && \
    bundle install

# Copy full source (used in image-only mode; in dev, code is volume-mounted)
COPY . .

CMD ["bundle", "exec", "rake", "spec"]

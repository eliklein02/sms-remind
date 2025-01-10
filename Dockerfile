# # syntax = docker/dockerfile:1

# # This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# # docker build -t my-app .
# # docker run -d -p 80:80 -p 443:443 --name my-app -e RAILS_MASTER_KEY=<value from config/master.key> my-app

# # Make sure RUBY_VERSION matches the Ruby version in .ruby-version
# ARG RUBY_VERSION=3.3.5
# FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# # Rails app lives here
# WORKDIR /rails

# # Install base packages
# RUN apt-get update -qq && \
#     apt-get install --no-install-recommends -y curl libjemalloc2 libvips sqlite3 && \
#     rm -rf /var/lib/apt/lists /var/cache/apt/archives

# # Set production environment
# ENV RAILS_ENV="production" \
#     BUNDLE_DEPLOYMENT="1" \
#     BUNDLE_PATH="/usr/local/bundle" \
#     BUNDLE_WITHOUT="development"

# # Throw-away build stage to reduce size of final image
# FROM base AS build

# # Install packages needed to build gems and node modules
# RUN apt-get update -qq && \
#     apt-get install --no-install-recommends -y build-essential git libpq-dev node-gyp pkg-config python-is-python3 && \
#     rm -rf /var/lib/apt/lists /var/cache/apt/archives

# # Install JavaScript dependencies
# ARG NODE_VERSION=23.5.0
# ARG YARN_VERSION=1.22.22
# ENV PATH=/usr/local/node/bin:$PATH
# RUN curl -sL https://github.com/nodenv/node-build/archive/master.tar.gz | tar xz -C /tmp/ && \
#     /tmp/node-build-master/bin/node-build "${NODE_VERSION}" /usr/local/node && \
#     npm install -g yarn@$YARN_VERSION && \
#     rm -rf /tmp/node-build-master

# # Install application gems
# COPY Gemfile Gemfile.lock ./
# RUN bundle install

# # Install node modules
# COPY package.json yarn.lock ./
# RUN yarn install --frozen-lockfile

# # Copy application code
# COPY . .

# # Precompile bootsnap code for faster boot times
# RUN bundle exec bootsnap precompile app/ lib/

# # Precompiling assets for production without requiring secret RAILS_MASTER_KEY
# RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile


# RUN rm -rf node_modules


# # Final stage for app image
# FROM base

# # Copy built artifacts: gems, application
# COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
# COPY --from=build /rails /rails

# # Run and own only the runtime files as a non-root user for security
# RUN groupadd --system --gid 1000 rails && \
#     useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
#     chown -R rails:rails db log storage tmp
# USER 1000:1000

# # Entrypoint prepares the database.
# ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# # Start the server by default, this can be overwritten at runtime
# EXPOSE 3000
# CMD ["./bin/rails", "server"]


# Use an official Ruby image as the base
FROM ruby:3.3.5

# Set environment variables
ENV RAILS_ENV=production
ENV RACK_ENV=production
ENV SECRET_KEY_BASE=1056788230cb26f98428a5a28ecb230c5da5fd96eb113ffc54dee4efb12f4f8dcb79ef43e2d8b047e2b8595e4cf50cf0e31a22841db0fef6e8e5bf7e0ab6ab12

# Install dependencies
RUN apt-get update -qq && apt-get install -y \
  build-essential \
  nodejs \
  yarn \
  git \
  libpq-dev \
  node-gyp \
  pkg-config \
  python-is-python3\
  postgresql-client

# Set the working directory
WORKDIR /app

# Copy Gemfile and Gemfile.lock to install dependencies
COPY Gemfile Gemfile.lock ./

# Install Ruby gems
RUN bundle install --without development test

# Copy the project files
COPY . .

# Precompile assets
#RUN bundle exec rake assets:precompile

# Expose port 3000
EXPOSE 3050

# Start the Rails server, ensuring the server.pid file is removed
CMD ["bash", "-c", "rm -f /app/tmp/pids/server.pid && bundle exec rails server -b 0.0.0.0 -p 3001"]
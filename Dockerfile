# Make sure it matches the Ruby version in .ruby-version and Gemfile
ARG RUBY_VERSION=3.3.5
FROM ruby:$RUBY_VERSION

# Install libvips for Active Storage preview support
RUN apt-get update -qq && \
    apt-get install -y build-essential libvips bash bash-completion libffi-dev tzdata postgresql nodejs npm ca-certificates && \
    npm config set strict-ssl false && \
    npm install -g yarn && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man

# Rails app lives here
WORKDIR /rails

# Set production environment
ENV RAILS_LOG_TO_STDOUT="1" \
    RAILS_SERVE_STATIC_FILES="true" \
    RAILS_ENV="production" \
    BUNDLE_WITHOUT="development" \
    SECRET_KEY_BASE="1056788230cb26f98428a5a28ecb230c5da5fd96eb113ffc54dee4efb12f4f8dcb79ef43e2d8b047e2b8595e4cf50cf0e31a22841db0fef6e8e5bf7e0ab6ab12"

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy application code
COPY . .

# Add wait-for-it script
COPY wait-for-it.sh /usr/bin/wait-for-it.sh
RUN chmod +x /usr/bin/wait-for-it.sh

RUN yarn config set strict-ssl false

# Install JavaScript dependencies
RUN yarn install

RUN RAILS_ENV=production bundle exec rake assets:precompile

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile --gemfile app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start the server by default, this can be overwritten at runtime
EXPOSE 3500

# CMD ["wait-for-it.sh", "db:5432", "--", "./bin/rails", "server", "-p", "3500"]
CMD ["foreman", "start"]
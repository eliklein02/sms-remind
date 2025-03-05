# Make sure it matches the Ruby version in .ruby-version and Gemfile
ARG RUBY_VERSION=3.3.5
FROM ruby:$RUBY_VERSION

# Install libvips for Active Storage preview support
RUN DEBIAN_FRONTEND=noninteractive \
    TERM=dumb \
    apt-get update -qq && \
    apt-get install -y --force-yes build-essential libvips bash bash-completion libffi-dev tzdata postgresql nodejs npm ca-certificates && \
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
    BUNDLE_WITHOUT="development" 

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
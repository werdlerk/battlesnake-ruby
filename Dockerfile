# See https://github.com/phusion/passenger-docker/blob/master/CHANGELOG.md for
FROM phusion/passenger-ruby34:3.1.4

# New signing key for Passenger since February 2026 (https://blog.phusion.nl/important-new-signing-key-for-passenger/)
# Please remove when this Dockerfile uses version 3.1.6 or newer.
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys D870AB033FB45BD1

# Set correct environment variables.
ENV HOME /root

# Use baseimage-docker's init process.
CMD ["/sbin/my_init"]

# Upgrade Ubuntu
RUN apt-get update && apt-get upgrade -y -o Dpkg::Options::="--force-confold"
# Clean up APT when done
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Enable Nginx and Passenger
RUN rm -f /etc/service/nginx/down

# Nginx virtual host entry
RUN rm /etc/nginx/sites-enabled/default
ADD deploy/webapp.conf /etc/nginx/sites-enabled/webapp.conf

# Create directory
RUN setuser app mkdir /home/app/webapp

WORKDIR /home/app/webapp

# Install gems
COPY --chown=app:app Gemfile Gemfile.lock /home/app/webapp
RUN setuser app gem install bundler --no-document \
   && setuser app bundle config set --local without 'development test' \
   && setuser app bundle config set --local deployment 'true' \
   && setuser app bundle config set --local jobs $(nproc) \
   && setuser app bundle install

# Install application
COPY --chown=app:app . /home/app/webapp

# Reset workdir
WORKDIR /home/app

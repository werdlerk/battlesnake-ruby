# See https://github.com/phusion/passenger-docker/blob/master/CHANGELOG.md for
FROM phusion/passenger-ruby31:2.3.1

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

RUN setuser app gem install bundler --no-document \
   && setuser app bundle config set --local without 'development test' \
   && setuser app bundle config set --local deployment 'true' \
   && setuser app bundle config set --local jobs $(nproc) \
   && setuser app bundle install

# Deploy application
RUN setuser app mkdir /home/app/webapp
COPY --chown=app:app . /home/app/webapp
WORKDIR /home/app/webapp

# Reset workdir
WORKDIR /home/app

HEALTHCHECK --start-period=10s \
  CMD curl -f -s http://localhost/ || exit 1

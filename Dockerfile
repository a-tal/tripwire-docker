FROM debian:latest
MAINTAINER Adam Talsma <se-adam.talsma@ccpgames.com>

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update -qqy
RUN apt-get install -qqy php5 php5-cli php5-mcrypt php5-intl php5-mysql php5-curl php5-gd curl git mysql-client mysql-server expect

RUN git clone https://bitbucket.org/daimian/tripwire.git /var/www/tripwire
RUN curl -L https://bitbucket.org/daimian/tripwire/downloads/tripwire.sql > /tmp/tripwire.sql
RUN curl -L https://bitbucket.org/daimian/tripwire/downloads/eve_api.sql > /tmp/eve_api.sql

RUN chown -R www-data:www-data /var/www/tripwire

COPY entrypoint.sh /entrypoint.sh

EXPOSE 80
WORKDIR /var/www/tripwire

CMD /entrypoint.sh

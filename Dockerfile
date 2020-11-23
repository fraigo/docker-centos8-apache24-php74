# Based on https://github.com/tonyclemmey/docker-centos8-httpd-php74
FROM centos:centos8

ENV PHP_VERSION=7.4 \
    PHP_VER_SHORT=74 \
    NAME=php

ENV PATH=$PATH:/opt/rh/php${PHP_VER_SHORT}/root/usr/bin

ENV SUMMARY="Platform for building and running PHP $PHP_VERSION applications" \
    DESCRIPTION="Centos8/PHP-FPM/PHP$PHP_VERSION server"

LABEL summary="${SUMMARY}" \
      description="${DESCRIPTION}" \
      name="centos8-${NAME}-${PHP_VER_SHORT}" \
      version="${PHP_VERSION}" \
      help="For more information visit https://hub.docker.com/r/centos/httpd-24-centos7" \
      usage="docker image build -t php-apache ./" \
      maintainer="Francisco Igor <franciscoigor@gmail.com>"

# CentOS8 systemd integration 
# https://developers.redhat.com/blog/2014/05/05/running-systemd-within-docker-container/
# https://developers.redhat.com/blog/2016/09/13/running-systemd-in-a-non-privileged-container/
RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == \
systemd-tmpfiles-setup.service ] || rm -f $i; done); \
rm -f /lib/systemd/system/multi-user.target.wants/*;\
rm -f /etc/systemd/system/*.wants/*;\
rm -f /lib/systemd/system/local-fs.target.wants/*; \
rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
rm -f /lib/systemd/system/basic.target.wants/*;\
rm -f /lib/systemd/system/anaconda.target.wants/*;

VOLUME [ "/sys/fs/cgroup" ]

# Replacing the internal user/group (https://jtreminio.com/blog/running-docker-containers-as-current-host-user/#ok-so-what-actually-works)
ARG USER_ID=1000
ARG GROUP_ID=1000
RUN if getent group apache ; then groupdel apache; fi && \
    groupadd -g ${GROUP_ID} apache && \
    useradd -l -u ${USER_ID} -g apache apache && \
    install -d -m 0755 -o apache -g apache /home/apache


# Install 3rd party repos, httpd ffmpeg & remi php
RUN yum update -y && \
 	dnf install epel-release dnf-utils nano -y && \
	dnf install http://rpms.remirepo.net/enterprise/remi-release-8.rpm -y && \
	dnf install --nogpgcheck https://download1.rpmfusion.org/free/el/rpmfusion-free-release-8.noarch.rpm -y && \
	dnf install http://rpmfind.net/linux/epel/7/x86_64/Packages/s/SDL2-2.0.10-1.el7.x86_64.rpm -y && \
	dnf config-manager --set-enabled PowerTools && \
	dnf install httpd httpd-tools mod_ssl ffmpeg -y && \
	dnf module enable php:remi-7.4 -y && \
	systemctl enable httpd && \
	dnf clean all

# Install php extentions
RUN dnf install -y php php-bcmath php-cli php-common php-mbstring php-mcrypt \
	php-mysqlnd php-gd php-dom php-pecl-imagick php-pear php-intl php-ldap php-zip && \
    dnf clean all

# Update Apache / MPM Configuration & Php ini
COPY ./00-mpm.conf /etc/httpd/conf.modules.d/00-mpm.conf
COPY ./httpd.conf /etc/httpd/conf/httpd.conf
COPY ./php.ini /etc/php.ini

# Creat missing Apache DIR and set proper permissions
RUN mkdir -p /var/log/httpd && \
	chmod 700 /var/log/httpd/

# Remove & replace default webroot dir
RUN rm -rf /var/www/html && \
	mkdir /var/www/web


# Create SSL / SimpleSAML certs
# Set the domain
ARG URL=localhost
ENV DOMAIN_URL $URL
RUN dnf install openssl -y
RUN openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj \
    "/C=GB/ST=state/L=city/O=organization/CN=$DOMAIN_URL" \
    -keyout ./$DOMAIN_URL.key -out ./$DOMAIN_URL.crt && \
	mv ./$DOMAIN_URL.crt /etc/pki/tls/certs/$DOMAIN_URL.crt && \
	mv ./$DOMAIN_URL.key /etc/pki/tls/private/$DOMAIN_URL.key

# Set Permissions
RUN chown -Rf apache:apache /var/www

# Simple startup script to avoid some issues observed with container restart
ADD run-httpd.sh /run-httpd.sh
RUN chmod -v +x /run-httpd.sh


# php composer
WORKDIR /usr/bin
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
RUN php composer-setup.php
RUN rm composer-setup.php
RUN echo 'alias composer="php /usr/bin/composer.phar"' >> ~/.bashrc

EXPOSE 80

WORKDIR /var/www/html

CMD ["/run-httpd.sh"]



ENV PHP_INI=/etc/php.ini

# RUN sed -i 's/^short_open_tag = Off/short_open_tag = On/g' $PHP_INI
RUN sed -i 's/^upload_max_filesize = 2M/upload_max_filesize = 50M/' $PHP_INI
RUN sed -i 's/^post_max_size = 8M/post_max_size = 50M/' $PHP_INI
RUN sed -i 's/^;date.timezone =/date.timezone = UTC/' $PHP_INI
# RUN sed -i 's/^default_socket_timeout = 60/default_socket_timeout = 120/' $PHP_INI


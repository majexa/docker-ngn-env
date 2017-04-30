FROM phusion/baseimage

CMD ["/sbin/my_init"]

RUN apt-get update
RUN locale-gen "ru_RU.UTF-8"

RUN apt-get -y install \
  mc \
  nginx

RUN apt-get -y install \
  sudo \
  git-core \
  memcached \
  imagemagick

RUN useradd -m -s /bin/bash -p `openssl passwd -1 CHANGE_IT` user
RUN echo '%user ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

RUN echo 'SELECTED_EDITOR="/usr/bin/mcedit"' > /root/.selected_editor
RUN echo 'SELECTED_EDITOR="/usr/bin/mcedit"' > /home/user/.selected_editor

#RUN sed -i "s/^\s*#.*$//g" /etc/nginx/nginx.conf
#RUN sed -i "/^\s*$/d" /etc/nginx/nginx.conf
RUN sed -i "s|www-data|user|g" /etc/nginx/nginx.conf
RUN sed -i "s|^\s*include /etc/nginx/sites-enabled/\*;|\tserver_names_hash_bucket_size  64;\n\tinclude /home/user/ngn-env/config/nginx/all.conf;\n|g" /etc/nginx/nginx.conf

RUN apt-get update -y && apt-get install -y software-properties-common language-pack-en-base

RUN LC_ALL=en_US.UTF-8 add-apt-repository ppa:ondrej/php

RUN apt-get -y update && apt-get install -y \
    php5.6 \
    php5.6-fpm \
    php5.6-curl \
    php5.6-mbstring \
    php5.6-memcached \
    php5.6-gd \
    php5.6-mysql

RUN mkdir /run/php
RUN sed -i "s|;daemonize = yes|daemonize = no|g" /etc/php/5.6/fpm/php-fpm.conf
RUN sed -i "s|www-data|user|g" /etc/php/5.6/fpm/pool.d/www.conf

RUN sed -i "s/short_open_tag = Off/short_open_tag = On/g" /etc/php/5.6/cli/php.ini
RUN sed -i "s/display_errors = Off/display_errors = On/g" /etc/php/5.6/cli/php.ini
RUN sed -i "s/short_open_tag = Off/short_open_tag = On/g" /etc/php/5.6/fpm/php.ini
RUN sed -i "s/display_errors = Off/display_errors = On/g" /etc/php/5.6/fpm/php.ini

RUN bash -c 'debconf-set-selections <<< "server-5.5 mysql-server/root_password password 123"'
RUN bash -c 'debconf-set-selections <<< "server-5.5 mysql-server/root_password_again password 123"'
RUN apt-get -y install mysql-server
RUN echo "[mysqld]\nsql_mode=IGNORE_SPACE,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION" > /etc/mysql/conf.d/disable_strict_mode.cnf


# Prevent of git clone caching (heavy development stage)
ADD https://api.github.com/repos/majexa/ngn/git/refs/heads/master version-ngn.json
ADD https://api.github.com/repos/majexa/run/git/refs/heads/master version-run.json
ADD https://api.github.com/repos/majexa/ci/git/refs/heads/master version-ci.json
ADD https://api.github.com/repos/majexa/pm/git/refs/heads/master version-pm.json
ADD https://api.github.com/repos/majexa/dummyProject/git/refs/heads/master version-dummyProject.json
ADD https://api.github.com/repos/majexa/tst/git/refs/heads/master version-dummyProject.json

# clone all of needed
RUN mkdir /home/user/ngn-env && \
mkdir /home/user/ngn-env/logs && \
cd /home/user/ngn-env && \
  git clone https://github.com/majexa/ngn.git && \
  git clone https://github.com/majexa/run.git && \
  git clone https://github.com/majexa/issue.git && \
  git clone https://github.com/majexa/ci.git && \
  git clone https://github.com/majexa/scripts.git && \
  git clone https://github.com/majexa/pm.git && \
  git clone https://github.com/majexa/dummyProject.git && \
  git clone https://github.com/majexa/tst.git && \
  git clone https://github.com/mootools/mootools-core.git && \
  git clone https://github.com/mootools/mootools-more.git

RUN chown -R user:user /home/user/ngn-env
RUN sudo -u user mkdir /home/user/ngn-env/config
RUN sudo -u user printf "<?php\n\nreturn [\n'baseDomain' => 't.majexa.ru',\n'maintaner' => 'majexa@gmail.com',\n'git' => 'git@github.com:majexa',\n'dbPass' => '123'\n,'dns' => 'devLinux'\n];" > /home/user/ngn-env/config/server.php
RUN sudo -u user php /home/user/ngn-env/pm/pm.php localServer createDatabaseConfig
RUN chown -R user:user /home/user/ngn-env

ADD startup/nginx.sh /etc/service/nginx/run
RUN chmod +x /etc/service/nginx/run

ADD startup/php.sh /etc/service/php5.6-fpm/run
RUN chmod +x /etc/service/php5.6-fpm/run

# Preparation for mysql-service
RUN mkdir /var/run/mysqld
RUN chown mysql:mysql /var/run/mysqld

ADD startup/mysql.sh /etc/service/mysql/run
RUN chmod +x /etc/service/mysql/run

# Prepare bin executables
RUN cd /home/user/ngn-env/ci && ./ci _updateBin
RUN rm -rf /home/user/ngn-env/run/logs/*
RUN pm localServer updateHosts

#!/bin/bash
PASS=${1:-d0wnstream}
debconf-set-selections <<< "mysql-server mysql-server/root_password password ${PASS}"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password ${PASS}"
apt-get -y -q install mysql-server mysql-client

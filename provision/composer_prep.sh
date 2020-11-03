#!/bin/bash
cd ~
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php --install-dir=/usr/local/bin --filename=composer --version=1.10.17
php -r "unlink('composer-setup.php');"
composer self-update
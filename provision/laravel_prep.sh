#!/bin/bash
cd ~/current
php artisan key:generate
php artisan module:migrate
php artisan module:seed
npm install
npm run build
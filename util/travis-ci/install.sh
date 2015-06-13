#!/bin/bash

DIR=$(dirname "$0")
export OUT=/tmp/nginx_build

bash $DIR/build.sh

export PATH=/usr/sbin/:$PATH

# nginx required base directories
sudo mkdir /var/tmp/nginx
sudo mkdir /var/lib/nginx
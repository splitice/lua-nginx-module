#!/bin/bash

DIR=$(dirname "$0")
export OUT=/tmp/nginx_build

bash $DIR/build.sh

export PATH=/usr/sbin/:$PATH
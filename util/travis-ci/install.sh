#!/bin/bash

export OUT=/tmp/nginx_build

bash build.sh

export PATH=$OUT:$PATH

cpan Test::Nginx
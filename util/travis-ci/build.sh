#!/bin/sh

WHOAMI=$(whoami)
ORIGDIR=$(pwd)
BASEDIR=$(dirname $0)
BASEDIR=`cd "${BASEDIR}";pwd`
OPENSSL_URL=http://www.openssl.org/source/$BUILD_OPENSSL_VERSION.tar.gz
ADDITIONAL_CONFIGURE=""

mkdir $OUT
echo "Compiling into $OUT as $WHOAMI";

# $1 = author
# $2 = project
# $3 = tag
# $4 = if set dont add config options
function install_github {
	wget https://github.com/$1/$2/archive/$3.tar.gz
	tar -zxvf $3.tar.gz
	if [[ "z$4" != "z" ]]; then
		ADDITIONAL_CONFIGURE="$ADDITIONAL_CONFIGURE --add-module=$OUT/$3"
	fi
}

function install_luajit {
	git clone http://luajit.org/git/luajit-2.0.git
	cd $OUT/luajit-2.0
	make
	make install
}

cd $OUT

install_luajit

cd $OUT

wget $OPENSSL_URL
tar -zxvf $OPENSSL_VERSION.tar.gz

install_github simpl ngx_devel_kit "v$BUILD_NGXDEVKIT_VERSION"
install_github openresty set-misc-nginx-module "v$BUILD_SETMISC_VERSION"
install_github openresty echo-nginx-module "v$BUILD_ECHO_VERSION"
install_github openresty memc-nginx-module "v$BUILD_MEMC_VERSION"
install_github openresty srcache-nginx-module "v$BUILD_SRCACHE_VERSION"
install_github openresty lua-upstream-nginx-module "v$BUILD_LUAUPSTREAM_VERSION"
install_github openresty headers-more-nginx-module "v$BUILD_HEADERSMORE_VERSION"
install_github openresty drizzle-nginx-module "v$BUILD_DRIZZLE_VERSION"
install_github openresty rds-json-nginx-module "v$BUILD_RDSJSON_VERSION"
install_github FRiCKLE ngx_coolkit "v$BUILD_COOLKIT_VERSION"
install_github openresty redis2-nginx-module "v$BUILD_REDIS2_VERSION"

cd "$BASEDIR/../../"

make clean

export LUAJIT_LIB=/usr/local/lib/
export LUAJIT_INC=/usr/local/include/luajit-2.0

./configure --prefix=/usr --conf-path=/etc/nginx/nginx.conf --sbin-path=/usr/sbin \
        --http-log-path=/var/log/nginx/access.log --error-log-path=/var/log/nginx/error.log \
        --pid-path=/var/run/nginx.pid --lock-path=/var/lock/nginx.lock --http-client-body-temp-path=/var/lib/nginx/body \
        --http-proxy-temp-path=/var/lib/nginx/proxy --http-fastcgi-temp-path=/var/tmp/nginx/fastcgi --with-ipv6 \
        --with-http_ssl_module --with-http_stub_status_module --with-openssl=$OUT/$OPENSSL_VERSION/ \
        --without-http_uwsgi_module --without-http_scgi_module --without-http_memcached_module \
        --with-http_dav_module --with-http_spdy_module --with-http_gunzip_module \
		--with-pcre-jit --add-module="$ORIGDIR" $ADDITIONAL_CONFIGURE

make

luarocks install lua-cjson
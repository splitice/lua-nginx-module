#!/bin/bash

WHOAMI=$(whoami)
ORIGDIR=$(pwd)
BASEDIR=$(dirname $0)
BASEDIR=`cd "${BASEDIR}";pwd`
NGINX_URL=http://nginx.org/download/$BUILD_NGINX_VERSION.tar.gz
OPENSSL_URL=http://www.openssl.org/source/$BUILD_OPENSSL_VERSION.tar.gz

if [[ "$BUILD_PCRE_VERSION" == "8.33" ]]; then
	PCRE_URL=http://linux.stanford.edu/pub/exim/pcre/pcre-$BUILD_PCRE_VERSION.tar.bz2 #version too old!
else
	PCRE_URL=ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-$BUILD_PCRE_VERSION.tar.bz2
fi
ADDITIONAL_CONFIGURE=""

mkdir $OUT
echo "Compiling into $OUT as $WHOAMI";

# $1 = author
# $2 = project
# $3 = tag
# $4 = if set dont add config options
function install_github {
	if [[ ! -d $OUT/$2-$4 ]]; then
		wget https://github.com/$1/$2/archive/$3$4.tar.gz
		tar -zxvf $3$4.tar.gz
		if [[ "z$5" == "z" ]]; then
			ADDITIONAL_CONFIGURE="$ADDITIONAL_CONFIGURE --add-module=$OUT/$2-$4"
		fi
	fi
}

function install_luajit {
	if [[ ! -d $OUT/luajit-2.0 ]]; then
		git clone http://luajit.org/git/luajit-2.0.git
		cd $OUT/luajit-2.0
		make
		sudo make install
		sudo ldconfig 
	fi
}


cd $OUT

install_luajit

cd $OUT
wget $NGINX_URL
tar -zxvf $BUILD_NGINX_VERSION.tar.gz

wget $OPENSSL_URL
tar -zxvf $BUILD_OPENSSL_VERSION.tar.gz

wget $PCRE_URL
tar jxf pcre-$BUILD_PCRE_VERSION.tar.bz2

install_github simpl ngx_devel_kit v "$BUILD_NGXDEVKIT_VERSION"
install_github openresty set-misc-nginx-module v "$BUILD_SETMISC_VERSION"
install_github openresty echo-nginx-module v "$BUILD_ECHO_VERSION"
install_github openresty memc-nginx-module v "$BUILD_MEMC_VERSION"
install_github openresty srcache-nginx-module v "$BUILD_SRCACHE_VERSION"
ADDITIONAL_CONFIGURE="$ADDITIONAL_CONFIGURE --add-module=$BASEDIR/../../"
install_github openresty lua-upstream-nginx-module v "$BUILD_LUAUPSTREAM_VERSION"
install_github openresty headers-more-nginx-module v "$BUILD_HEADERSMORE_VERSION"
install_github openresty drizzle-nginx-module v "$BUILD_DRIZZLE_VERSION"
install_github openresty rds-json-nginx-module v "$BUILD_RDSJSON_VERSION"
install_github FRiCKLE ngx_coolkit "" "$BUILD_COOLKIT_VERSION"
install_github openresty redis2-nginx-module v "$BUILD_REDIS2_VERSION"

git clone https://github.com/openresty/ngx_openresty.git

cd $BUILD_NGINX_VERSION

for i in ../ngx_openresty/patches/$BUILD_NGINX_VERSION-*.patch; do
	patch -p1  < "$i"
done

export LUAJIT_LIB=/usr/local/lib/
export LUAJIT_INC=/usr/local/include/luajit-2.0

set -o xtrace
env LIBDRIZZLE_LIB=/usr/lib/ LIBDRIZZLE_INC=/usr/include/libdrizzle-1.0 ./configure --prefix=/usr --conf-path=/etc/nginx/nginx.conf --sbin-path=/usr/sbin \
        --http-log-path=/var/log/nginx/access.log --error-log-path=/var/log/nginx/error.log \
        --pid-path=/var/run/nginx.pid --lock-path=/var/lock/nginx.lock --http-client-body-temp-path=/var/lib/nginx/body \
        --http-proxy-temp-path=/var/lib/nginx/proxy --http-fastcgi-temp-path=/var/tmp/nginx/fastcgi --with-ipv6 \
        --with-http_ssl_module --with-http_stub_status_module --with-openssl=$OUT/$BUILD_OPENSSL_VERSION/ \
        --without-http_uwsgi_module --without-http_scgi_module --with-select_module --with-poll_module \
        --with-http_dav_module --with-http_spdy_module --with-http_gunzip_module --with-http_realip_module \
		--with-http_auth_request_module --with-http_image_filter_module \
		--with-pcre=$OUT/pcre-$BUILD_PCRE_VERSION --with-pcre-conf-opt="--enable-utf8 --enable-unicode-properties --enable-jit" --with-pcre-jit \
		$ADDITIONAL_CONFIGURE --with-debug
set +o xtrace

sudo make install

sudo luarocks install lua-cjson
git clone https://github.com/openresty/mockeagain.git
cd mockeagain
make
strip mockeagain.so
cp -i mockeagain.so /usr/lib/
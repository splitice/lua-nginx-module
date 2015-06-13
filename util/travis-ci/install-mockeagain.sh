git clone https://github.com/openresty/mockeagain.git
cd mockeagain
make
strip mockeagain.so
sudo cp -i mockeagain.so /usr/lib/
cd ..
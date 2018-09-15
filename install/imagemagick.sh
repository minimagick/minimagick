set -e

curl -O "http://www.imagemagick.org/download/ImageMagick-$IM_VERSION.tar.gz"
tar xzf "ImageMagick-$IM_VERSION.tar.gz"
cd ImageMagick-*
./configure --prefix=/usr
sudo make install

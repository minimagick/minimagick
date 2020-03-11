set -ex

im_download_path=$(curl -sf https://www.imagemagick.org/download/releases/ | grep -o "ImageMagick-$IM_VERSION-.*.tar.xz" -m 1)
curl -f "https://www.imagemagick.org/download/releases/$im_download_path" > ImageMagick.tar.xz
tar xf ImageMagick.tar.xz
cd ImageMagick-*
./configure --prefix=/usr
sudo make install

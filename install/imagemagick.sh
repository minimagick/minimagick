set -e

case "$IM_VERSION" in
  6)
    sudo apt-get install imagemagick libmagickcore-dev libmagickwand-dev
    ;;
  7)
    curl -O "http://www.imagemagick.org/download/ImageMagick.tar.gz"
    tar xzf "ImageMagick.tar.gz"
    cd ImageMagick-7*
    ./configure --prefix=/usr
    sudo make install
    ;;
esac

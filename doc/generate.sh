DIR=$(dirname $BASH_SOURCE[0])

freeze $DIR/header.sh \
	--language fish \
	--output $DIR/header.png \
	--padding 20,200,0,30

magick $DIR/header.png -resize 1270x $DIR/header.png

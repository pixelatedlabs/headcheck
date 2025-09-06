# This is free and unencumbered software released into the public domain.

FILE="$(dirname $BASH_SOURCE[0])/header.png"

read -r -d '' CODE <<-'EOF'
	#  _                    _      _               _
	# | |                  | |    | |             | |
	# | |__   ___  __ _  __| | ___| |__   ___  ___| | __
	# | '_ \ / _ \/ _` |/ _` |/ __| '_ \ / _ \/ __| |/ /
	# | | | |  __/ (_| | (_| | (__| | | |  __/ (__|   <
	# |_| |_|\___|\__,_|\__,_|\___|_| |_|\___|\___|_|\_\

	headcheck http://localhost/status
EOF

echo "$CODE" | freeze --language fish --output $FILE --padding 20,200,0,30

magick $FILE -resize 1280x $FILE

optipng $FILE

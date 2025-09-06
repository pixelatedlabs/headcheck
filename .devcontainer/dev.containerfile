# This is free and unencumbered software released into the public domain.

FROM quay.io/fedora/fedora:42

ARG FREEZE=0.2.2

RUN <<EOF
	ARCH=$(uname -m)

	dnf --assumeyes --setopt=install_weak_deps=false install \
		git ImageMagick upx zig zip \
		https://github.com/charmbracelet/freeze/releases/download/v$FREEZE/freeze-$FREEZE-1.$ARCH.rpm
EOF

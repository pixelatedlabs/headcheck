# This is free and unencumbered software released into the public domain.

FROM quay.io/fedora/fedora:42

RUN dnf --assumeyes --setopt=install_weak_deps=false install \
	git ImageMagick upx zig zip \
	https://github.com/charmbracelet/freeze/releases/download/v0.2.2/freeze-0.2.2-1.x86_64.rpm

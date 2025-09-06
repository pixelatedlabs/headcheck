# This is free and unencumbered software released into the public domain.

FROM quay.io/fedora/fedora:42

RUN dnf --assumeyes --setopt=install_weak_deps=false install \
	git ImageMagick upx zig zip

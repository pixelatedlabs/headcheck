# This is free and unencumbered software released into the public domain.

FROM quay.io/fedora/fedora:42

ARG FREEZE=0.2.2
ARG ZIG=0.15.1

ENV PATH=/opt/zig:$PATH

RUN <<EOF
	ARCH=$(uname -m)

	dnf --assumeyes --setopt=install_weak_deps=false install \
		git ImageMagick optipng upx zip \
		https://github.com/charmbracelet/freeze/releases/download/v$FREEZE/freeze-$FREEZE-1.$ARCH.rpm

	mkdir /opt/zig
	curl --output /tmp/zig.tar.xz https://ziglang.org/download/$ZIG/zig-$ARCH-linux-$ZIG.tar.xz
	tar --directory /opt/zig --extract --file /tmp/zig.tar.xz --strip-components 1 --xz
EOF

FROM debian:sid AS bootstrapper
ARG TARGETARCH
COPY pacstrap-docker /pacstrap-docker
RUN \
	apt-get update && \
	apt-get install -y --no-install-recommends pacman-package-manager curl ca-certificates zstd && \
	sed -i "s/^CheckSpace/#CheckSpace/" /etc/pacman.conf && \
	sed -i "s/#\(SigLevel =\).*/\1 Required DatabaseOptional/" /etc/pacman.conf && \
	sed -i "s/#\(LocalFileSigLevel =\).*/\1 Optional/" /etc/pacman.conf && \
	mkdir -p /etc/pacman.d && \
	case "$TARGETARCH" in \
		amd64) \
			printf '\n[core]\nInclude = /etc/pacman.d/mirrorlist\n\n[extra]\nInclude = /etc/pacman.d/mirrorlist\n' >> /etc/pacman.conf && \
			MIRRORLIST_URL="https://gitlab.archlinux.org/archlinux/packaging/packages/pacman-mirrorlist/-/raw/main/mirrorlist" \
			;; \
		arm) \
			printf '\n[core]\nInclude = /etc/pacman.d/mirrorlist\n\n[extra]\nInclude = /etc/pacman.d/mirrorlist\n\n[alarm]\nInclude = /etc/pacman.d/mirrorlist\n\n[aur]\nInclude = /etc/pacman.d/mirrorlist\n' >> /etc/pacman.conf && \
			MIRRORLIST_URL="https://raw.githubusercontent.com/archlinuxarm/PKGBUILDs/master/core/pacman-mirrorlist/mirrorlist" && \
			MIRRORLIST_ARCH="armv7h" \
			;; \
		arm64) \
			printf '\n[core]\nInclude = /etc/pacman.d/mirrorlist\n\n[extra]\nInclude = /etc/pacman.d/mirrorlist\n\n[alarm]\nInclude = /etc/pacman.d/mirrorlist\n\n[aur]\nInclude = /etc/pacman.d/mirrorlist\n' >> /etc/pacman.conf && \
			MIRRORLIST_URL="https://raw.githubusercontent.com/archlinuxarm/PKGBUILDs/master/core/pacman-mirrorlist/mirrorlist" && \
			MIRRORLIST_ARCH="aarch64" \
			;; \
		riscv64) \
			printf '\n[core]\nInclude = /etc/pacman.d/mirrorlist\n\n[extra]\nInclude = /etc/pacman.d/mirrorlist\n\n[unsupported]\nInclude = /etc/pacman.d/mirrorlist\n' >> /etc/pacman.conf && \
			MIRRORLIST_URL="https://raw.githubusercontent.com/felixonmars/archriscv-packages/master/pacman-mirrorlist/mirrorlist" \
			;; \
	esac && \
	curl -L "$MIRRORLIST_URL" | sed -E 's/^\s*#\s*Server\s*=/Server =/g' > /etc/pacman.d/mirrorlist && \
	if [ -n "$MIRRORLIST_ARCH" ]; then \
		sed -i 's/\$arch/'$MIRRORLIST_ARCH'/g' /etc/pacman.d/mirrorlist; \
	fi && \
	BOOTSTRAP_EXTRA_PACKAGES="" && \
	if case "$TARGETARCH" in arm*) true;; *) false;; esac; then \
			EXTRA_KEYRING_FILES=" \
				archlinuxarm-revoked \
				archlinuxarm-trusted \
				archlinuxarm.gpg \
			" && \
			EXTRA_KEYRING_URL="https://raw.githubusercontent.com/archlinuxarm/PKGBUILDs/master/core/archlinuxarm-keyring/" && \
			for EXTRA_KEYRING_FILE in $EXTRA_KEYRING_FILES; do \
				curl "$EXTRA_KEYRING_URL$EXTRA_KEYRING_FILE" -o /usr/share/keyrings/$EXTRA_KEYRING_FILE -L; \
			done && \
			BOOTSTRAP_EXTRA_PACKAGES="archlinuxarm-keyring"; \
	else \
			mkdir /tmp/archlinux-keyring && \
			curl -L https://archlinux.org/packages/core/any/archlinux-keyring/download | unzstd | tar -C /tmp/archlinux-keyring -xv && \
			mv /tmp/archlinux-keyring/usr/share/pacman/keyrings/* /usr/share/keyrings/; \
	fi && \
	pacman-key --init && \
	pacman-key --populate && \
	mkdir /rootfs && \
	/pacstrap-docker /rootfs base $BOOTSTRAP_EXTRA_PACKAGES && \
	cp /etc/pacman.d/mirrorlist /rootfs/etc/pacman.d/mirrorlist && \
	echo "en_US.UTF-8 UTF-8" > /rootfs/etc/locale.gen && \
	echo "LANG=en_US.UTF-8" > /rootfs/etc/locale.conf && \
	chroot /rootfs locale-gen && \
	rm -rf /rootfs/var/lib/pacman/sync/*

FROM scratch
COPY --from=bootstrapper /rootfs/ /
ENV LANG=en_US.UTF-8
RUN \
	ln -sf /usr/lib/os-release /etc/os-release && \
	pacman-key --init && \
	pacman-key --populate && \
	rm -rf /etc/pacman.d/gnupg/{openpgp-revocs.d/,private-keys-v1.d/,pubring.gpg~,gnupg.S.}*

CMD ["/usr/bin/bash"]

FROM archlinux:base
RUN curl -Lo /etc/pacman.conf https://nashcentral.duckdns.org/autobuildres/linux/pacman.conf
RUN curl -LO https://nashcentral.duckdns.org/autobuildres/linux/pkg.base
RUN sed -i "s|pacstrap \/mnt|pacman -Syu --noconfirm|g" /pkg.base
RUN chmod 755 /pkg.base
RUN pacman-key --init
RUN pacman-key --populate
RUN pacman --needed -Syu archlinux-keyring --noconfirm
RUN pacman --noconfirm -Rdd iptables
RUN /pkg.base
RUN rm /pkg.base
COPY . /build
WORKDIR /build/jenux-build
ENV docker_phase rootfs
RUN ./build.sh
ENV docker_phase iso
cmd ["./build.sh"]

FROM dnlnash/jenuxos:jenux-base-rootfs
COPY . /build
WORKDIR /build/jenux-build
RUN pacman-key --init
RUN pacman-key --populate
CMD ["./build.sh"]

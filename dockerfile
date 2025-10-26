FROM dnlnash/jenuxos:jenux-base-rootfs
COPY . /build
WORKDIR /build/jenux-build
CMD ["./build.sh"]

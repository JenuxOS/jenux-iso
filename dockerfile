FROM dnlnash/jenuxos:jenux-base-rootfs
RUN sh -c "while true;do if pacman --needed --noconfirm -Syu qemu-img squashfuse;then break;else continue;fi;done"
COPY . /build
WORKDIR /build/jenux-build
CMD ["./build.sh"]

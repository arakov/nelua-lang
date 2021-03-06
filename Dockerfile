# AlpineLinux
FROM alpine:3.10
RUN apk update
RUN apk upgrade
RUN apk add bash sudo curl build-base git
RUN apk add lua5.3 lua5.3-dev lua5.1 lua5.1-dev luajit luajit-dev luarocks5.1 luarocks5.3 sdl2-dev

# ArchLinux alternative
#FROM archlinux/base
#RUN pacman -Syu --noconfirm
#RUN pacman -S --noconfirm --needed base-devel git gcc clang
#RUN pacman -S --noconfirm lua lua51 luajit luarocks luarocks5.1 sdl2

COPY rockspecs/nelua-dev-1.rockspec .

# nelua lua dependencies (5.1)
RUN sudo luarocks-5.1 install --only-deps nelua-dev-1.rockspec

# nelua lua dependencies (5.3)
RUN sudo luarocks-5.3 install --only-deps nelua-dev-1.rockspec

# nelua global config (to force testing it)
RUN mkdir -p /.config/nelua
RUN echo "return {}" >> /.config/nelua/neluacfg.lua

WORKDIR /nelua

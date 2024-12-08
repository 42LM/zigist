# TODO: When tag with v0.12.0 exists use official zig docker image
# FROM ziglang/static-base:llvm15-aarch64-3 as ziggy
# ENTRYPOINT ./deps/local/bin/zig version

FROM jedisct1/minisign:latest AS minisign
FROM alpine:3.10 AS build-zig

RUN apk update
RUN apk add curl

COPY --from=minisign /usr/local/bin/minisign /usr/local/bin/minisign
COPY ./zig-linux-x86_64-0.13.0.tar.xz.minisig .

RUN curl https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz -O
# Verify the signature from zig tarball before installing/using
# Public key from https://ziglang.org/download/
RUN minisign -Vm zig-linux-x86_64-0.13.0.tar.xz -P RWSGOq2NVecA2UPNdBUZykf1CCb147pkmdtYxgb3Ti+JO/wCYvhbAb/U
RUN tar xf zig-linux-x86_64-0.13.0.tar.xz
ENV PATH="/zig-linux-x86_64-0.13.0:${PATH}"
COPY . /zigist
WORKDIR /zigist
RUN zig build

FROM alpine:3.10

COPY --from=build-zig /zig-linux-x86_64-0.13.0 /zig-linux-x86_64-0.13.0
COPY --from=build-zig /zigist /zigist
WORKDIR /github/workspace
ENTRYPOINT ["../../zigist/zig-out/bin/zigist"]

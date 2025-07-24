FROM jedisct1/minisign:latest AS minisign

FROM alpine:3.10 AS builder

RUN apk update
RUN apk add curl

ARG ZIGVER=0.14.1

COPY --from=minisign /usr/local/bin/minisign /usr/local/bin/minisign
RUN curl https://ziglang.org/download/$ZIGVER/zig-x86_64-linux-$ZIGVER.tar.xz.minisig -O


RUN curl https://ziglang.org/download/$ZIGVER/zig-x86_64-linux-$ZIGVER.tar.xz -O
# Verify the signature from zig tarball before installing/using
# Public key from https://ziglang.org/download/
RUN minisign -Vm zig-x86_64-linux-$ZIGVER.tar.xz -P RWSGOq2NVecA2UPNdBUZykf1CCb147pkmdtYxgb3Ti+JO/wCYvhbAb/U
RUN tar xf zig-x86_64-linux-$ZIGVER.tar.xz
ENV PATH=$PATH:/zig-x86_64-linux-$ZIGVER

COPY . /zigist
WORKDIR /zigist
RUN zig build

FROM alpine:3.10

COPY --from=builder /zigist /zigist

ENTRYPOINT ["/zigist/zig-out/bin/zigist"]

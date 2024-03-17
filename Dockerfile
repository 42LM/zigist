FROM alpine:3.10 as build-zig

RUN apk update
RUN apk add curl
RUN curl https://ziglang.org/download/0.11.0/zig-linux-x86_64-0.11.0.tar.xz -O && \
    tar xf zig-linux-x86_64-0.11.0.tar.xz
ENV PATH="/zig-linux-x86_64-0.11.0:${PATH}"
COPY . /zigist
WORKDIR /zigist
RUN zig build

FROM alpine:3.10

COPY --from=build-zig /zig-linux-x86_64-0.11.0 /zig-linux-x86_64-0.11.0
COPY --from=build-zig /zigist /zigist
WORKDIR /github/workspace
ENTRYPOINT ["../../zigist/zig-out/bin/zigist"]

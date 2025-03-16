ARG PYTHON_VERSION=3.8.20

FROM ubuntu:24.04 AS base

# Install depends
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  mv /etc/apt/apt.conf.d/docker-clean /tmp/docker-clean \
  && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache \
  && apt-get update \
  && apt-get install -y --no-install-recommends build-essential libssl-dev zlib1g-dev \
  libbz2-dev libreadline-dev libsqlite3-dev curl ca-certificates \
  libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev \
  && mv /tmp/docker-clean /etc/apt/apt.conf.d/docker-clean \
  && rm -f /etc/apt/apt.conf.d/keep-cache \
  && mkdir /tmp/python-source

FROM base AS build

# Download Python source
WORKDIR /tmp
ARG PYTHON_VERSION
RUN \
  --mount=type=cache,target=/tmp/python-source,sharing=locked \
  curl -Lo /tmp/python-source/Python-${PYTHON_VERSION}.tar.xz https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz \
  && tar axf /tmp/python-source/Python-${PYTHON_VERSION}.tar.xz

# Build Python
WORKDIR /tmp/Python-${PYTHON_VERSION}
RUN \
  ./configure --prefix=/usr/local \
    --enable-shared \
    --enable-optimizations \
    --with-ensurepip=install \
    --enable-loadable-sqlite-extensions \
    --enable-ipv6 \
    --with-lto \
  && make -j$(nproc)

FROM ubuntu:24.04 AS final

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  mv /etc/apt/apt.conf.d/docker-clean /tmp/docker-clean \
  && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache \
  && apt-get update \
  && apt-get install -y --no-install-recommends make \
  && rm -f /etc/apt/apt.conf.d/keep-cache

ARG PYTHON_VERSION
RUN --mount=type=bind,from=build,source=/tmp/Python-${PYTHON_VERSION},target=/tmp/Python-${PYTHON_VERSION},rw \
  cd /tmp/Python-${PYTHON_VERSION} \
  && make install
ENV LD_LIBRARY_PATH=/usr/local/lib

CMD [ "/usr/local/bin/python3" ]

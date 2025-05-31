# ---------------------------------------
# Stage 1: P4SpecTec dependencies
# ---------------------------------------
FROM ubuntu:20.04 AS opambase

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y opam curl make libgmp-dev pkg-config && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Initialize opam
RUN opam init --disable-sandboxing --auto-setup && \
    opam switch create 4.14.0 && \
    eval $(opam env) && \
    opam install dune menhir bignum core.v0.15.1 core_unix.v0.15.2 bisect_ppx -y

# Set opam environment permanently
ENV OPAM_SWITCH_PREFIX=/root/.opam/4.14.0
ENV PATH=$OPAM_SWITCH_PREFIX/bin:$PATH
ENV CAML_LD_LIBRARY_PATH=$OPAM_SWITCH_PREFIX/lib/stublibs:$OPAM_SWITCH_PREFIX/lib/ocaml/stublibs:$OPAM_SWITCH_PREFIX/lib/ocaml

# ---------------------------------------
# Stage 2: Build P4SpecTec
# ---------------------------------------
FROM opambase AS p4specbase

COPY . /home/p4spectec
WORKDIR /home/p4spectec
RUN make build-spec && \
    chmod a+x ./p4spectec

# --------------------------------------
# Stage 3: Fuzzer & Reducer dependencies
# --------------------------------------
FROM p4specbase AS reducebase

RUN apt-get update && \
    apt-get install -y clang creduce python3 pip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install psutil
COPY patches/creduce /usr/bin/creduce
RUN chmod +x /usr/bin/creduce

ENV P4CHERRY_PATH=/home/p4spectec

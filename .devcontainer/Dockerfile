FROM mcr.microsoft.com/devcontainers/rust:1-1-bookworm
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends libvirt-daemon qemu-kvm qemu-system-gui
USER vscode
WORKDIR /workspaces
RUN rustup install nightly && rustup default nightly
RUN rustup component add rust-src --toolchain nightly-x86_64-unknown-linux-gnu
RUN rustup component add llvm-tools-preview
RUN cargo install bootimage
ENV DISPLAY host.docker.internal:0.0

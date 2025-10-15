#!/bin/bash
set -euo pipefail

echo "[prebuild] Installing system packages required to build Python wheels"

# Update packages and install development toolchain and libs
dnf -y update || true

# Install development tools group and common build deps
dnf -y groupinstall "Development Tools" || true
dnf -y install \
  python3 \
  python3-devel \
  python3-pip \
  gcc \
  gcc-c++ \
  make \
  openssl-devel \
  libffi-devel \
  openblas-devel \
  lapack-devel \
  rust \
  cargo || true

echo "[prebuild] Upgrading pip, setuptools, wheel"
python3 -m pip install --upgrade pip setuptools wheel

echo "[prebuild] System packages installed"

echo "[prebuild] Diagnostic info: python and pip versions"
python3 --version || true
python3 -m pip --version || true
echo "[prebuild] List installed system packages (short):"
dnf list installed | head -n 40 || true

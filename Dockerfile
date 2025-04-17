# Use Ubuntu as the base image
FROM ubuntu:24.04

# Set non-interactive frontend for apt
ENV DEBIAN_FRONTEND=noninteractive

# Update & install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    wget \
    ca-certificates \
    software-properties-common \
    gnupg \
    git \
    vim \
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    r-base \
    cdo \
    nco \
    libnetcdf-dev \
    netcdf-bin \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install common Python scientific packages
RUN pip3 install --no-cache-dir numpy pandas xarray netCDF4 matplotlib

# Create working directory
WORKDIR /workspace

# Default command
CMD ["bash"]


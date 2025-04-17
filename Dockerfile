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
    gfortran \
    liblapack-dev \
    libblas-dev \
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

# Upgrade pip and install Python scientific stack
#RUN pip3 install --no-cache-dir --upgrade pip \
#    && pip3 install --no-cache-dir --break-system-packages numpy pandas xarray netCDF4 matplotlib

# Install R packages (CRAN + GitHub)
RUN Rscript -e "install.packages(c('dplyr', 'ncdf4', 'data.table', 'climate', 'thunder'), repos='https://cloud.r-project.org')"


# Create working directory
WORKDIR /workspace

# Default command
CMD ["bash"]


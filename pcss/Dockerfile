# Use rocker/rstudio as the base image for interactive RStudio
FROM rocker/rstudio:4.5.0

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
    libarchive-dev \
    libxml2-dev \
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
RUN pip3 install --no-cache-dir --break-system-packages numpy pandas xarray netCDF4 

# Install R packages (CRAN + GitHub)
RUN Rscript -e "install.packages(c('tidyverse', 'ncdf4', 'data.table', 'climate', 'thunder', 'reticulate'))"
RUN Rscript -e "install.packages('climate', repos='https://cloud.r-project.org')" #default repo is outdated
# Set up RStudio Server configuration
# Set password for existing rstudio user and add to sudo group
RUN echo "rstudio:rstudio" | chpasswd && \
    adduser rstudio sudo

# Set working directory
WORKDIR /home/rstudio

# Expose RStudio Server port
EXPOSE 8787

# Start RStudio Server
CMD ["/init"]

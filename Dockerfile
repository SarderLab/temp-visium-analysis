
FROM satijalab/seurat:5.0.0

LABEL maintainer="Anish Tatke CMI Lab <anish.tatke@medicine.ufl.edu>"

ENV PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python
ENV PYTHONBUFFERED=TRUE

RUN apt-get update && \
    apt-get install --yes --no-install-recommends software-properties-common gpg-agent && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get --yes --no-install-recommends -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    git wget curl ca-certificates unzip \
    build-essential cmake autoconf automake \
    libcurl4-openssl-dev libexpat1-dev libhdf5-dev \
    libpython3-dev libssl-dev libffi-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev \
    liblzma-dev tk-dev uuid-dev \
    # Standard build tools \
    libtool pkg-config \
    # useful later \
    libmemcached-dev && \
    #apt-get autoremove && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Python 3.12 from source into /opt/python312
ENV PY312_PREFIX=/opt/python312
RUN curl -sSLO https://www.python.org/ftp/python/3.12.8/Python-3.12.8.tgz && \
    tar -xzf Python-3.12.8.tgz && \
    cd Python-3.12.8 && \
    ./configure --prefix=$PY312_PREFIX --with-ensurepip=install && \
    make -j"$(nproc)" && \
    make install && \
    cd / && rm -rf Python-3.12.8 Python-3.12.8.tgz

# Update PATH to include Python 3.12
ENV PATH="$PY312_PREFIX/bin:$PATH"
RUN python3.12 -m ensurepip --upgrade && \
    python3.12 -m pip install --upgrade pip setuptools wheel && \
    ln -sfn /opt/python312/bin/python3.12 /usr/local/bin/python && \
    ln -sfn /opt/python312/bin/pip3.12 /usr/local/bin/pip && \
    python -V && python -m pip -V

RUN apt-get update ##[edited]

WORKDIR /

RUN which  python && \
    python --version


# Required for R package installations
RUN apt-get update && apt-get install -y libv8-dev \
    libbz2-dev liblzma-dev libglpk-dev libgsl-dev \
    libpcre2-dev libudunits2-dev libgdal-dev libpq-dev \
    unixodbc unixodbc-dev libfontconfig1-dev libcairo2-dev \
    libharfbuzz-dev libfribidi-dev libmagick++-dev

## Taken from Azimuth Dockerfile
RUN mkdir lzf
WORKDIR /lzf
RUN wget https://raw.githubusercontent.com/h5py/h5py/3.0.0/lzf/lzf_filter.c https://raw.githubusercontent.com/h5py/h5py/3.0.0/lzf/lzf_filter.h
RUN mkdir lzf
WORKDIR /lzf/lzf
RUN wget https://raw.githubusercontent.com/h5py/h5py/3.0.0/lzf/lzf/lzf_c.c https://raw.githubusercontent.com/h5py/h5py/3.0.0/lzf/lzf/lzf_d.c https://raw.githubusercontent.com/h5py/h5py/3.0.0/lzf/lzf/lzfP.h https://raw.githubusercontent.com/h5py/h5py/3.0.0/lzf/lzf/lzf.h
WORKDIR /lzf
RUN gcc -O2 -fPIC -shared lzf/*.c lzf_filter.c -I /usr/include/hdf5/serial/ -lhdf5_serial -o liblzf_filter.so
WORKDIR /
ENV HDF5_PLUGIN_PATH=/lzf

## Installing R packages
COPY Visium_Analysis/scripts/install_R_packages.r .
RUN R -e 'remotes::install_version("Matrix",version="1.6.4",repos="https://cran.r-project.org",dependencies=TRUE)'
RUN R -e 'install.packages("SeuratObject",version=">= 5.0.2",repos="https://cran.r-project.org",dependencies=TRUE)'
RUN Rscript install_R_packages.r BiocManager BSgenome.Hsapiens.UCSC.hg38 glmGamPoi GenomeInfoDb GenomicRanges TFBSTools JASPAR2020 EnsDb.Hsapiens.v86 IRanges Rsamtools S4Vectors
RUN R -e 'remotes::install_github("satijalab/azimuth",ref="master",dependencies=TRUE)'
RUN R -e 'remotes::install_github("ctlab/fgsea",dependencies=TRUE)'
RUN R -e 'remotes::install_github("JEFworks-Lab/STdeconvolve",dependencies=TRUE)'

ENV build_path=/opt/build

# Copying over plugin files
ENV plugin_path=/opt/Visium_Analysis
RUN mkdir -p $plugin_path
WORKDIR $plugin_path
COPY . $plugin_path


RUN apt-get update && \
    apt-get install -y --no-install-recommends memcached && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN python -m pip install --no-cache-dir --upgrade --ignore-installed pip setuptools && \
    python -m pip install --no-cache-dir .  && \
    rm -rf /root/.cache/pip/*

# Show what was installed
RUN python --version && python -m pip --version && python -m pip freeze

# Defining entrypoint
WORKDIR $plugin_path/Visium_Analysis/cli
LABEL entry_path="${plugin_path}/Visium_Analysis/cli"

# Testing entrypoint
RUN python -m slicer_cli_web.cli_list_entrypoint --list_cli
RUN python -m slicer_cli_web.cli_list_entrypoint LabelTransfer --help
RUN python -m slicer_cli_web.cli_list_entrypoint CellDeconvolution --help
RUN python -m slicer_cli_web.cli_list_entrypoint SpotAnnotation --help


ENTRYPOINT ["/bin/bash","docker-entrypoint.sh"]
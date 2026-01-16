# Replace this with whatever tag you build/push for the base image
FROM tatkeanish/seurat-python-base:stable

LABEL maintainer="Anish Tatke CMI Lab <anish.tatke@medicine.ufl.edu>"

ENV PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python
ENV PYTHONUNBUFFERED=1

ENV build_path=/build

RUN apt-get update && \
    apt-get install -y --no-install-recommends memcached && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy plugin code late to maximize cache reuse
ENV plugin_path=/opt/Visium_Analysis
RUN mkdir -p $plugin_path
WORKDIR ${plugin_path}
COPY . ${plugin_path}

# Install your plugin (always use python -m pip to avoid path confusion)
RUN python -m pip install --no-cache-dir --upgrade pip setuptools wheel && \
    python -m pip install --no-cache-dir . && \
    rm -rf /root/.cache/pip/*

# Show installed versions (optional)
RUN python --version && python -m pip --version

# Entry path and quick sanity tests
WORKDIR ${plugin_path}/Visium_Analysis/cli
LABEL entry_path="${plugin_path}/Visium_Analysis/cli"

# These tests assume cli/slicer_cli_list.json exists in-image.
RUN ls -lah . && \
    test -f slicer_cli_list.json

RUN python -m slicer_cli_web.cli_list_entrypoint --list_cli
RUN python -m slicer_cli_web.cli_list_entrypoint LabelTransfer --help
# RUN python -m slicer_cli_web.cli_list_entrypoint CellDeconvolution --help
RUN python -m slicer_cli_web.cli_list_entrypoint SpotAnnotation --help

ENTRYPOINT ["/bin/bash","docker-entrypoint.sh"]
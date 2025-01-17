FROM ubuntu:20.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository -y ppa:apptainer/ppa && \
    apt-get install -y \
    build-essential wget curl vim iputils-ping dbus sudo \
    munge \
    libmunge-dev \
    slurm-wlm \
    openmpi-bin \
    openmpi-common \
    libopenmpi-dev \
    apptainer \
    && apt-get clean

# Set up munge key for SLURM
RUN /usr/sbin/create-munge-key && chmod 0700 /etc/munge && \
    chown -R munge:munge /etc/munge && mkdir -p /run/dbus

RUN mkdir /var/spool/slurm && \
    chown -R slurm: /var/spool/slurm

# Configure SLURM
COPY slurm.conf /etc/slurm-llnl/slurm.conf

RUN useradd -m -s /bin/bash slurmuser && \
    echo "slurmuser:slurmuser" | chpasswd && \
    usermod -aG sudo slurmuser && \
    echo "slurmuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER slurmuser
WORKDIR /home/slurmuser

# Start SLURM processes
CMD ["bash"]

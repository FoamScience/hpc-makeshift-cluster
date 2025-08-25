FROM ubuntu:24.04

EXPOSE 6817 6818 6819 6820 3306

ARG SLURM_TAG=slurm-25-05-2-1
# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository -y ppa:apptainer/ppa && \
    apt-get install -y \
    build-essential fakeroot devscripts equivs wget curl vim iputils-ping dbus sudo \
    munge libmunge-dev \
    openssl libjwt-dev libjson-c-dev libyaml-dev libhttp-parser-dev \
    sqlite3 tcl-dev tix-dev tk-dev libopengl-dev libncurses-dev psmisc \
    libssl-dev cmake \
    supervisor \
    mariadb-server mariadb-client libmariadb-dev libmariadbd-dev \
    openmpi-bin \
    openmpi-common \
    libopenmpi-dev \
    apptainer \
    python3 python3-dev \
    && apt-get clean

ENV TINI_VERSION=v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini.asc /tini.asc
RUN gpg --batch --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 595E85A6B1B4779EA4DAAEC70B588DFF0527A9B7 \
 && gpg --batch --verify /tini.asc /tini
RUN chmod +x /tini

RUN git clone https://github.com/aws/s2n-tls.git \
    && cd /s2n-tls/ \
    && cmake . -B build/ -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON \
    && cmake --build build/ -j $(nproc) \
    && cmake --install build/

RUN set -ex \
    && git clone -b slurm-${SLURM_TAG} --single-branch --depth=1 https://github.com/SchedMD/slurm.git \
    && cd /slurm \
    && ./configure --prefix=/usr --sysconfdir=/etc/slurm --enable-slurmrestd \
        --with-mysql_config=/usr/bin --libdir=/usr/lib --enable-multiple-slurmd --with-tls=s2n \
    && make -j $(nproc) install \
    && install -D -m644 etc/cgroup.conf.example /etc/slurm/cgroup.conf.example \
    && install -D -m644 etc/slurm.conf.example /etc/slurm/slurm.conf.example \
    && install -D -m600 etc/slurmdbd.conf.example /etc/slurm/slurmdbd.conf.example \
    && install -D -m644 contribs/slurm_completion_help/slurm_completion.sh /etc/profile.d/slurm_completion.sh

RUN rm -rf /slurm \
    && groupadd -r slurm  \
    && useradd -r -g slurm slurm \
    && mkdir -p /etc/sysconfig/slurm \
        /var/spool/slurmd \
        /var/spool/slurm \
        /var/spool/slurmctld \
        /var/log/slurm \
        /var/run/slurm \
        /var/log/supervisor \
        /var/run/supervisor \
        /run/munge \
    && chown -R slurm:slurm /var/spool/slurmd \
        /var/spool/slurm \
        /var/spool/slurmctld \
        /var/log/slurm \
        /var/run/slurm \
    && chmod 0777 /var/run/supervisor \
    && chmod 0777 /var/log/supervisor \
    && chown munge:munge /run/munge && chmod 0711 /run/munge

RUN mkdir -p /etc/munge /run/dbus && \
    chmod 0700 /etc/munge && chown -R munge:munge /etc/munge && \
    if [ ! -f /etc/munge/munge.key ]; then mungekey -c; fi && \
    chown munge:munge /etc/munge/munge.key && chmod 0400 /etc/munge/munge.key
RUN dd if=/dev/random of=/etc/slurm/jwt_hs256.key bs=32 count=1 \
    && chmod 600 /etc/slurm/jwt_hs256.key && chown slurm:slurm /etc/slurm/jwt_hs256.key

RUN curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/usr/local/bin sh

# Configure SLURM
COPY --chown=slurm slurm.conf /etc/slurm/slurm.conf
COPY --chown=slurm cgroup.conf /etc/slurm/cgroup.conf
COPY --chown=slurm slurmdb.conf /etc/slurm/slurmdbd.conf
COPY supervisord.conf /etc/supervisor/supervisord.conf
RUN chmod 600 /etc/slurm/slurmdbd.conf

COPY head-entrypoint.sh /head-entrypoint.sh
COPY compute-entrypoint.sh /compute-entrypoint.sh
RUN mkdir -p /usr/lib/slurm/rest_auth
RUN ln -s /usr/lib/x86_64-linux-gnu/slurm-wlm/auth_* /usr/lib/slurm/rest_auth/

RUN useradd -m -s /bin/bash slurmuser && \
    echo "slurmuser:slurmuser" | chpasswd && \
    usermod -aG sudo slurmuser && \
    echo "slurmuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER slurmuser
WORKDIR /home/slurmuser

# Start SLURM processes
CMD ["bash"]

FROM debian:jessie-backports

# Add services helper utilities to start and stop LAVA
COPY stop.sh .
COPY start.sh .

# Install debian packages used by the container
# Configure apache to run the lava server
# Log the hostname used during install for the slave name
RUN echo 'lava-server   lava-server/instance-name string lava-docker-instance' | debconf-set-selections \
 && echo 'locales locales/locales_to_be_generated multiselect C.UTF-8 UTF-8, en_US.UTF-8 UTF-8 ' | debconf-set-selections \
 && echo 'locales locales/default_environment_locale select en_US.UTF-8' | debconf-set-selections \
 && apt-get clean && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y -t jessie-backports \
 locales \
 postgresql \
 screen \
 sudo \
 wget \
 vim \
 && service postgresql start \
 && wget http://images.validation.linaro.org/production-repo/production-repo.key.asc \
 && apt-key add production-repo.key.asc \
 && echo 'deb http://images.validation.linaro.org/production-repo/ sid main' > /etc/apt/sources.list.d/lava.list \
 && apt-get clean && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y -t jessie-backports \
 lava \
 qemu-system \
 qemu-system-arm \
 qemu-system-i386 \
 qemu-kvm \
 && a2enmod proxy \
 && a2enmod proxy_http \
 && a2dissite 000-default \
 && a2ensite lava-server \
 && /stop.sh \
 && rm -rf /var/lib/apt/lists/*

# Add patches
COPY hack.patch /root/

# Create a admin user (Insecure note, this creates a default user, username: admin/admin)
RUN /start.sh \
 && echo "from django.contrib.auth.models import User; User.objects.create_superuser('admin', 'admin@localhost.com', 'admin')" | lava-server manage shell \
 && /stop.sh

# Install latest
RUN /start.sh \
 && git clone -b master https://git.linaro.org/lava/lava-dispatcher.git /root/lava-dispatcher \
 && cd /root/lava-dispatcher \
 && git checkout 2017.2 \
 && git clone -b master https://git.linaro.org/lava/lava-server.git /root/lava-server \
 && cd /root/lava-server \
 && git checkout 2017.2 \
 && git am /root/hack.patch \
 && git fetch https://review.linaro.org/lava/lava-server refs/changes/28/18328/1 && git cherry-pick FETCH_HEAD \
 && echo "cd \${DIR} && dpkg -i *.deb" >> /root/lava-server/share/debian-dev-build.sh \
 && cd /root/lava-dispatcher && /root/lava-server/share/debian-dev-build.sh -p lava-dispatcher \
 && cd /root/lava-server && /root/lava-server/share/debian-dev-build.sh -p lava-server \
 && /stop.sh

EXPOSE 69 80 5555 5556
CMD /start.sh && bash

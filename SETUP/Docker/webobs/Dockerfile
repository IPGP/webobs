FROM debian:12-slim

LABEL org.opencontainers.image.authors="boissier@ipgp.fr"
LABEL version="1.0"
LABEL description="Docker image running WebObs on Debian 12."

## Environment variables
# WebObs version
ENV WO_VERSION=2.7.3
# Directories
ENV WORK_DIR=/opt
ENV INSTALL_DIR=/opt/webobs
# Set system to non-interactive during build only
ARG DEBIAN_FRONTEND=noninteractive
# Simulate a chroot environment
ENV FAKE_CHROOT=1
# Ensures that the OpenGL graphics library will not try to direct access GPU in the container
ENV LIBGL_ALWAYS_INDIRECT=1

WORKDIR $WORK_DIR

## System upgrade and packages install

RUN apt-get update && apt-get dist-upgrade -y --no-install-recommends
    # Install generic tools
RUN apt-get install -y \
        openssh-server openssl libssl-dev net-tools python3 python3-pip sudo wget vim git pipx unzip
        ## WebObs dependencies
RUN apt-get install -y \
        apache2 apache2-utils sqlite3 imagemagick pngquant qrencode jq vim mutt xvfb curl gawk
RUN apt-get install -y \
        graphviz net-tools libdatetime-perl libdatetime-format-strptime-perl libdate-calc-perl
RUN apt-get install -y \
        libcgi-session-perl libdbd-sqlite3-perl libgraphviz-perl libimage-info-perl
RUN apt-get install -y \
        libtext-multimarkdown-perl libswitch-perl libintl-perl liblist-moreutils-perl
RUN apt-get install -y \
        wkhtmltopdf poppler-utils libjson-perl libjson-xs-perl libnet-ldap-perl libhtml-escape-perl
RUN apt-get install -y \
        libncurses5 python-is-python3
        # Cleanup
RUN apt-get autoremove -y --purge \
    && apt-get clean 

## Setup ssh access

RUN mkdir /var/run/sshd \
    # Generate SSH host keys 
    && ssh-keygen -A \
    && sed -i'' -e's/^#X11UseLocalhost yes$/X11UseLocalhost no/' /etc/ssh/sshd_config \
    && sed -i'' -e's/^#AllowAgentForwarding yes$/AllowAgentForwarding yes/' /etc/ssh/sshd_config \
    && sed -i'' -e's/^#PermitRootLogin prohibit-password$/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i'' -e's/^#PasswordAuthentication yes$/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i'' -e's/^#PermitEmptyPasswords no$/PermitEmptyPasswords yes/' /etc/ssh/sshd_config \
    && sed -i'' -e's/^UsePAM yes/UsePAM no/' /etc/ssh/sshd_config \
    # SSH login fix. Otherwise user is kicked off after login
    && sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

# Expose SSH TCP port
EXPOSE 22
# Expose HTTP TCP port
EXPOSE 80
# Expose HTTPS TCP port
EXPOSE 443

## Users and groups

# TODO : use BuildKit secrets
# Set root password to 'password'
RUN echo 'root:password' | chpasswd

## Directories

RUN mkdir -p $INSTALL_DIR

## Download WebObs distribution

RUN wget https://github.com/IPGP/webobs/releases/download/v${WO_VERSION}/WebObs-${WO_VERSION}.tar.gz \
    && tar xvfz WebObs-${WO_VERSION}.tar.gz -C $INSTALL_DIR \
    && rm WebObs-${WO_VERSION}.tar.gz

## Download Matlab MCR to $INSTALL_DIR (will be installed during setup)

RUN wget -O ${INSTALL_DIR}/MCR_R2011b_glnxa64_installer.zip http://www.ipgp.fr/~beaudu/webobs/MCR_Runtime/MCR_R2011b_glnxa64_installer.zip

## Set locales

RUN sed -i -e 's/^# \(en_US ISO-8859-1\)/\1/;s/^# \(fr_FR ISO-8859-1\)/\1/' /etc/locale.gen \
    && locale-gen fr_FR en_US

## Apache2 configuration

# Disable default site
RUN a2dissite 000-default.conf \
    # Enable perl CGI
    && a2enmod cgid \
    && apachectl start

## Fix ImageMagick security policy

RUN sed -i'' -e's;\(<policy domain="coder" rights="none" pattern="PS" />\);<!-- \1 -->;' /etc/ImageMagick-6/policy.xml \
    && sed -i'' -e's;\(<policy domain="coder" rights="none" pattern="PS2" />\);<!-- \1 -->;' /etc/ImageMagick-6/policy.xml \
    && sed -i'' -e's;\(<policy domain="coder" rights="none" pattern="PS3" />\);<!-- \1 -->;' /etc/ImageMagick-6/policy.xml \
    && sed -i'' -e's;\(<policy domain="coder" rights="none" pattern="EPS" />\);<!-- \1 -->;' /etc/ImageMagick-6/policy.xml \
    && sed -i'' -e's;\(<policy domain="coder" rights="none" pattern="PDF" />\);<!-- \1 -->;' /etc/ImageMagick-6/policy.xml \
    && sed -i'' -e's;\(<policy domain="coder" rights="none" pattern="XPS" />\);<!-- \1 -->;' /etc/ImageMagick-6/policy.xml

## Run WebObs setup 

#RUN cd $INSTALL_DIR \
#    && WebObs-${WO_VERSION}/SETUP/setup -a

# TODO use BuildKit secrets to create wo user in htpassord file.

## Switch to wo

# USER wo

## Start WebObs

#RUN cd $INSTALL_DIR && \
#    CODE/shells/postboard start \
#    CODE/shells/scheduler start

# Start sshd in foreground - useful for "detached" mode
CMD /usr/sbin/sshd -D

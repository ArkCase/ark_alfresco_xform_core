###########################################################################################################
#
# How to build:
#
# docker build -t arkcase/alfresco-transform-core:3.0.0
#
# How to run: (Docker)
# docker compose -f docker-compose.yml up -d
#
#
###########################################################################################################

ARG PUBLIC_REGISTRY="public.ecr.aws"
ARG ARCH="amd64"
ARG OS="linux"
ARG VER="3.1.1"
ARG JAVA="11"
ARG PKG="alfresco-transform-core"
ARG APP_USER="transform"
ARG APP_UID="33017"
ARG APP_GROUP="alfresco"
ARG APP_GID="1000"

ARG ALFRESCO_MVN_REPO_BASE="https://nexus.alfresco.com/nexus/repository"
ARG ALFRESCO_MVN_RELEASES="releases"
ARG ALFRESCO_MVN_REPO_RELEASES="${ALFRESCO_MVN_REPO_BASE}/${ALFRESCO_MVN_RELEASES}"
ARG ALFRESCO_MVN_THIRDPARTY="thirdparty"
ARG ALFRESCO_MVN_REPO_THIRDPARTY="${ALFRESCO_MVN_REPO_BASE}/${ALFRESCO_MVN_THIRDPARTY}"

ARG EXIFTOOL_VERSION="12.25"
ARG EXIFTOOL_REPO="${ALFRESCO_MVN_REPO_THIRDPARTY}"
ARG EXIFTOOL_SRC="org.exiftool:image-exiftool:${EXIFTOOL_VERSION}:tgz"

ARG IMAGEMAGICK_VERSION="7.1.2-6-ci-1"
ARG IMAGEMAGICK_DEB_REPO="${ALFRESCO_MVN_REPO_THIRDPARTY}"
ARG IMAGEMAGICK_DEB_SRC="org.imagemagick:imagemagick-distribution:${IMAGEMAGICK_VERSION}:deb:ub2204-${ARCH}"
ARG IMAGEMAGICK_DEB_LIB_SRC="org.imagemagick:imagemagick-distribution:${IMAGEMAGICK_VERSION}:deb:ub2204-${ARCH}-dev"

ARG LIBREOFFICE_VERSION="7.2.5.1"
ARG LIBREOFFICE_DEB_REPO="${ALFRESCO_MVN_REPO_THIRDPARTY}"
ARG LIBREOFFICE_DEB_SRC="org.libreoffice:libreoffice-dist:${LIBREOFFICE_VERSION}:gz:deb"

ARG PDFRENDERER_VERSION="1.1"
ARG PDFRENDERER_DEB_REPO="${ALFRESCO_MVN_REPO_RELEASES}"
ARG PDFRENDERER_DEB_SRC="org.alfresco:alfresco-pdf-renderer:${PDFRENDERER_VERSION}:tgz:linux"

ARG ALFRESCO_REPO="alfresco/alfresco-transform-core-aio"
ARG ALFRESCO_IMG="${ALFRESCO_REPO}:${VER}"

ARG BASE_REGISTRY="${PUBLIC_REGISTRY}"
ARG BASE_REPO="arkcase/base-java"
ARG BASE_VER="24.04"
ARG BASE_VER_PFX=""
ARG BASE_IMG="${BASE_REGISTRY}/${BASE_REPO}:${BASE_VER_PFX}${BASE_VER}"

# Used to copy artifacts
FROM "${ALFRESCO_IMG}" AS alfresco-src

ARG PUBLIC_REGISTRY
ARG BASE_REPO
ARG BASE_IMG

# Final Image
FROM "${BASE_IMG}"

ARG ARCH
ARG OS
ARG VER
ARG JAVA
ARG PKG
ARG APP_USER
ARG APP_UID
ARG APP_GROUP
ARG APP_GID
ARG EXIFTOOL_REPO
ARG EXIFTOOL_SRC
ARG IMAGEMAGICK_DEB_REPO
ARG IMAGEMAGICK_DEB_SRC
ARG IMAGEMAGICK_DEB_LIB_SRC
ARG LIBREOFFICE_DEB_REPO
ARG LIBREOFFICE_DEB_SRC
ARG PDFRENDERER_DEB_REPO
ARG PDFRENDERER_DEB_SRC
ARG SRC_JAR="/usr/bin/alfresco-transform-core-aio-${VER}.jar"
ARG MAIN_JAR="/usr/bin/alfresco-transform-core-aio.jar"

LABEL ORG="ArkCase LLC" \
      MAINTAINER="Armedia Devops Team <devops@armedia.com>" \
      APP="Alfresco Transformation Core" \
      VERSION="${VER}"

ENV JAVA_MAJOR="${JAVA}"
ENV HOME_DIR="/home/${APP_USER}"

RUN set-java "${JAVA}" && \
    apt-get -y install \
        fontconfig \
        fonts-dejavu \
        language-pack-en \
        libapr1 \
        libcairo-dev \
        libcups2 \
        libfreetype6 \
        libglu1-mesa \
        libpng-tools \
        libsm6 \
      && \
    apt-get clean && \
    groupadd -g "${APP_GID}" "${APP_GROUP}" && \
    useradd -u "${APP_UID}" -g "${APP_GROUP}" -G "${ACM_GROUP}" -d "${HOME_DIR}" -m "${APP_USER}" && \
    chmod -R u=rwX,g=rX,o= "${HOME_DIR}"

WORKDIR /

COPY --from=alfresco-src --chown="${APP_USER}:${APP_GROUP}" "${SRC_JAR}" "${MAIN_JAR}"
COPY --from=alfresco-src --chown="${APP_USER}:${APP_GROUP}" "/licenses" "/licenses"
COPY --chown=root:root --chmod=0755 entrypoint /entrypoint

RUN IMAGEMAGICK_DEB="imagemagic.deb" && \
    IMAGEMAGICK_DEB_LIB="imagemagic-dev.deb" && \
    INSTALLER="$(mktemp -d)" && \
    cd "${INSTALLER}" && \
    mvn-get "${IMAGEMAGICK_DEB_SRC}" "${IMAGEMAGICK_DEB_REPO}" "${IMAGEMAGICK_DEB}" && \
    mvn-get "${IMAGEMAGICK_DEB_LIB_SRC}" "${IMAGEMAGICK_DEB_REPO}" "${IMAGEMAGICK_DEB_LIB}" && \
    apt-get -y install $(find "${INSTALLERS}"/*.deb -type f | sort) && \
    dpkg --remove --force-depends libgs && \
    cd / && \
    rm -rf "${INSTALLER}"

RUN LIBREOFFICE_GZ="libreoffice-dist-deb.gz" \
    INSTALLER="$(mktemp -d)" && \
    cd "${INSTALLER}" && \
    mvn-get "${LIBREOFFICE_DEB_SRC}" "${LIBREOFFICE_DEB_REPO}" "${LIBREOFFICE_GZ}" && \
    tar -xzvf "${LIBREOFFICE_GZ}" && \
    apt-get -y install $(find "${INSTALLERS}"/*.deb -type f | sort) && \
    cd / && \
    rm -rf "${INSTALLER}"

RUN PDFRENDERER_TGZ="alfresco-pdf-renderer-linux.tgz" \
    INSTALLER="$(mktemp -d)" && \
    cd "${INSTALLER}" && \
    mvn-get "${PDFRENDERER_DEB_SRC}" "${PDFRENDERER_DEB_REPO}" "${PDFRENDERER_TGZ}" && \
    tar -xzf "${PDFRENDERER_TGZ}" -C "/usr/bin" && \
    cd / && \
    rm -rf "${INSTALLER}"

RUN EXIFTOOL_TGZ="exiftool.tgz" && \
    INSTALLER="$(mktemp -d)" && \
    cd "${INSTALLER}" && \
    mvn-get "${EXIFTOOL_SRC}" "${EXIFTOOL_REPO}" "${EXIFTOOL_TGZ}" && \
    apt-get -y install \
        make \
        libdist-zilla-plugin-makemaker-awesome-perl \
        perl \
      && \
    tar --strip-components=1 -xzf "${EXIFTOOL_TGZ}" && \
    perl Makefile.PL && \
    make && \
    make test && \
    make install && \
    cd / && \
    apt-get -y purge --autoremove make libdist-zilla-plugin-makemaker-awesome-perl && \
    apt-get clean && \
    rm -rf "${INSTALLER}"

USER "${APP_USER}"

EXPOSE 8009
ENTRYPOINT [ "/entrypoint" ]

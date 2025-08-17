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
ARG EXIFTOOL_FOLDER="Image-ExifTool-${EXIFTOOL_VERSION}"
ARG EXIFTOOL_SRC="org.exiftool:image-exiftool:${EXIFTOOL_VERSION}:tgz"

ARG IMAGEMAGICK_VERSION="7.1.0-16"
ARG IMAGEMAGICK_RPM_REPO="${ALFRESCO_MVN_REPO_THIRDPARTY}"
ARG IMAGEMAGICK_RPM_SRC="org.imagemagick:imagemagick-distribution:${IMAGEMAGICK_VERSION}:rpm:rockylinux8"
ARG IMAGEMAGICK_RPM_LIB_SRC="org.imagemagick:imagemagick-distribution:${IMAGEMAGICK_VERSION}:rpm:libs-rockylinux8"

ARG LIBREOFFICE_VERSION="7.2.5.1"
ARG LIBREOFFICE_RPM_REPO="${ALFRESCO_MVN_REPO_THIRDPARTY}"
ARG LIBREOFFICE_RPM_SRC="org.libreoffice:libreoffice-dist:${LIBREOFFICE_VERSION}:gz:rpm"

ARG PDFRENDERER_VERSION="1.1"
ARG PDFRENDERER_RPM_REPO="${ALFRESCO_MVN_REPO_RELEASES}"
ARG PDFRENDERER_RPM_SRC="org.alfresco:alfresco-pdf-renderer:${PDFRENDERER_VERSION}:tgz:linux"

ARG ALFRESCO_REPO="alfresco/alfresco-transform-core-aio"
ARG ALFRESCO_IMG="${ALFRESCO_REPO}:${VER}"

ARG BASE_REGISTRY="${PUBLIC_REGISTRY}"
ARG BASE_REPO="arkcase/base-java"
ARG BASE_VER="8"
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
ARG EXIFTOOL_FOLDER
ARG EXIFTOOL_REPO
ARG EXIFTOOL_SRC
ARG IMAGEMAGICK_RPM_REPO
ARG IMAGEMAGICK_RPM_SRC
ARG IMAGEMAGICK_RPM_LIB_SRC
ARG LIBREOFFICE_RPM_REPO
ARG LIBREOFFICE_RPM_SRC
ARG PDFRENDERER_RPM_REPO
ARG PDFRENDERER_RPM_SRC
ARG SRC_JAR="/usr/bin/alfresco-transform-core-aio-${VER}.jar"
ARG MAIN_JAR="/usr/bin/alfresco-transform-core-aio.jar"

LABEL ORG="ArkCase LLC" \
      MAINTAINER="Armedia Devops Team <devops@armedia.com>" \
      APP="Alfresco Transformation Core" \
      VERSION="${VER}"

ENV JAVA_MAJOR="${JAVA}"

RUN set-java "${JAVA}" && \
    yum -y install \
        apr \
        langpacks-en \
        fontconfig \
        dejavu-fonts-common \
        epel-release \
        fontpackages-filesystem \
        freetype \
        libpng \
        dejavu-sans-fonts && \
    yum -y install \
        cairo \
        cups-libs \
        libSM \
        libGLU && \
    yum -y clean all && \
    groupadd -g "${APP_GID}" "${APP_GROUP}" && \
    useradd -u "${APP_UID}" -g "${APP_GROUP}" -G "${ACM_GROUP}" "${APP_USER}"

WORKDIR /
COPY --from=alfresco-src "${SRC_JAR}" "${SRC_JAR}"
COPY --from=alfresco-src "/licenses" "/licenses"
COPY entrypoint /entrypoint
RUN chmod 0755 /entrypoint

ARG INSTALLERS="/installers" \
    EXIFTOOL_TGZ="${INSTALLERS}/exiftool.tgz" \
    LIBREOFFICE_GZ="${INSTALLERS}/libreoffice-dist-rpm.gz" \
    PDFRENDERER_TGZ="${INSTALLERS}/alfresco-pdf-renderer-linux.tgz" \
    IMAGEMAGICK_RPM="${INSTALLERS}/imagemagic.rpm" \
    IMAGEMAGICK_RPM_LIB="${INSTALLERS}/imagemagic-lib.rpm"

RUN chown -R "${APP_USER}" /licenses && \
    ln -v "${SRC_JAR}" "${MAIN_JAR}" && \
    mkdir -p "${INSTALLERS}" && \
    pushd "${INSTALLERS}" && \
    mvn-get "${IMAGEMAGICK_RPM_SRC}" "${IMAGEMAGICK_RPM_REPO}" "${IMAGEMAGICK_RPM}" && \
    mvn-get "${IMAGEMAGICK_RPM_LIB_SRC}" "${IMAGEMAGICK_RPM_REPO}" "${IMAGEMAGICK_RPM_LIB}" && \
    yum localinstall -y "${INSTALLERS}"/*.rpm && \
    rpm -e --nodeps libgs && \
    mvn-get "${LIBREOFFICE_RPM_SRC}" "${LIBREOFFICE_RPM_REPO}" "${LIBREOFFICE_GZ}" && \
    tar xzf "${LIBREOFFICE_GZ}" && \
    yum localinstall -y "${INSTALLERS}"/LibreOffice*/RPMS/*.rpm && \
    mvn-get "${PDFRENDERER_RPM_SRC}" "${PDFRENDERER_RPM_REPO}" "${PDFRENDERER_TGZ}" && \
    tar xzf "${PDFRENDERER_TGZ}" -C "/usr/bin" && \
    mvn-get "${EXIFTOOL_SRC}" "${EXIFTOOL_REPO}" "${EXIFTOOL_TGZ}" && \
    tar xzf "${EXIFTOOL_TGZ}" && \
    yum -y install perl perl-ExtUtils-MakeMaker make && \
    pushd "${EXIFTOOL_FOLDER}" && \
    perl Makefile.PL && \
    make && \
    make test && \
    make install && \
    popd && \
    yum -y autoremove make && \
    rm -rf "${INSTALLERS}" && \
    yum -y clean all 

RUN chgrp -R "${APP_GROUP}" "${MAIN_JAR}"

USER "${APP_USER}"
ENV JAVA_MAJOR="${JAVA}"

EXPOSE 8009
ENTRYPOINT [ "/entrypoint" ]

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
ARG PKG="alfresco-transform-core"
ARG APP_USER="transform"
ARG APP_UID="33017"
ARG APP_GROUP="alfresco"
ARG APP_GID="1000"

ARG EXIFTOOL_VERSION="12.25"
ARG EXIFTOOL_FOLDER="Image-ExifTool-${EXIFTOOL_VERSION}"
ARG IMAGEMAGICK_VERSION="7.1.0-16-ci-6"
ARG LIBREOFFICE_VERSION="7.2.5.1"
ARG PDFRENDERER_VERSION="1.1"
ARG EXIFTOOL_URL="https://nexus.alfresco.com/nexus/service/local/repositories/thirdparty/content/org/exiftool/image-exiftool/${EXIFTOOL_VERSION}/image-exiftool-${EXIFTOOL_VERSION}.tgz"
ARG IMAGEMAGICK_DEP_RPM_URL="https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm"
ARG IMAGEMAGICK_RPM_URL="https://github.com/Alfresco/imagemagick-build/releases/download/v${IMAGEMAGICK_VERSION}/ImageMagick-${IMAGEMAGICK_VERSION}.x86_64.rpm"
ARG IMAGEMAGICK_LIB_RPM_URL="https://github.com/Alfresco/imagemagick-build/releases/download/v${IMAGEMAGICK_VERSION}/ImageMagick-libs-${IMAGEMAGICK_VERSION}.x86_64.rpm"
ARG LIBREOFFICE_RPM_URL="https://nexus.alfresco.com/nexus/service/local/repositories/thirdparty/content/org/libreoffice/libreoffice-dist/${LIBREOFFICE_VERSION}/libreoffice-dist-${LIBREOFFICE_VERSION}-linux.gz"
ARG ALFRESCO_PDF_RENDERER_LIB_RPM_URL="https://nexus.alfresco.com/nexus/service/local/repositories/releases/content/org/alfresco/alfresco-pdf-renderer/${PDFRENDERER_VERSION}/alfresco-pdf-renderer-${PDFRENDERER_VERSION}-linux.tgz"

ARG ALFRESCO_REPO="alfresco/alfresco-transform-core-aio"
ARG ALFRESCO_IMG="${ALFRESCO_REPO}:${VER}"

ARG BASE_REPO="arkcase/base"
ARG BASE_VER="8"
ARG BASE_IMG="${PUBLIC_REGISTRY}/${BASE_REPO}:${BASE_VER}"

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
ARG PKG
ARG APP_USER
ARG APP_UID
ARG APP_GROUP
ARG APP_GID
ARG EXIFTOOL_VERSION
ARG EXIFTOOL_FOLDER
ARG IMAGEMAGICK_VERSION
ARG LIBREOFFICE_VERSION
ARG PDFRENDERER_VERSION
ARG EXIFTOOL_URL
ARG IMAGEMAGICK_DEP_RPM_URL
ARG IMAGEMAGICK_RPM_URL
ARG IMAGEMAGICK_LIB_RPM_URL
ARG LIBREOFFICE_RPM_URL
ARG ALFRESCO_PDF_RENDERER_LIB_RPM_URL
ARG SRC_JAR="/usr/bin/alfresco-transform-core-aio-3.0.0.jar"
ARG MAIN_JAR="/usr/bin/alfresco-transform-core-aio.jar"

LABEL ORG="ArkCase LLC" \
      MAINTAINER="Armedia Devops Team <devops@armedia.com>" \
      APP="Alfresco Transformation Core" \
      VERSION="${VER}"

ENV JAVA_HOME="/usr/lib/jvm/jre-11-openjdk" \
    JAVA_MAJOR=11

RUN yum -y update && \
    yum -y install \
        apr \
        langpacks-en \
        java-${JAVA_MAJOR}-openjdk-devel \
        fontconfig \
        dejavu-fonts-common \
        ${IMAGEMAGICK_DEP_RPM_URL} \
        fontpackages-filesystem \
        freetype \
        libpng \
        dejavu-sans-fonts && \
    yum -y install \
        ${IMAGEMAGICK_LIB_RPM_URL} \
        ${IMAGEMAGICK_RPM_URL} && \
    rpm -e --nodeps libgs && \
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

ARG EXIFTOOL_TGZ="/exiftool.tgz" \
    LIBREOFFICE_GZ="/libreoffice-dist-linux.gz" \
    PDFRENDERER_TGZ="/alfresco-pdf-renderer-linux.tgz"

RUN chown -R "${APP_USER}" /licenses && \
    ln -v "${SRC_JAR}" "${MAIN_JAR}" && \
    curl -s -S "${LIBREOFFICE_RPM_URL}" -o "/libreoffice-dist-linux.gz" && \
    tar xzf "${LIBREOFFICE_GZ}" && \
    yum localinstall -y LibreOffice*/RPMS/*.rpm && \
    rm -rf "${LIBREOFFICE_GZ}" LibreOffice* && \
    curl -s -S "${ALFRESCO_PDF_RENDERER_LIB_RPM_URL}" -o "/alfresco-pdf-renderer-linux.tgz" && \
    tar xf "${PDFRENDERER_TGZ}" -C "/usr/bin" && \
    rm -f "${PDFRENDERER_TGZ}" && \
    curl -s -S "${EXIFTOOL_URL}" -o "${EXIFTOOL_TGZ}" && \
    tar xzf "${EXIFTOOL_TGZ}" && \
    yum -y install perl perl-ExtUtils-MakeMaker make && \
    pushd "${EXIFTOOL_FOLDER}" && \
    perl Makefile.PL && make && \
    make test && \
    make install && \
    popd && \
    yum -y autoremove make && \
    rm -rf "${EXIFTOOL_FOLDER}" "${EXIFTOOL_TGZ}" && \
    yum -y clean all 

RUN chgrp -R "${APP_GROUP}" "${MAIN_JAR}"

USER "${APP_USER}"
ENV JAVA_HOME="/usr/lib/jvm/jre-11-openjdk" \
    JAVA_MAJOR="11"

EXPOSE 8009
ENTRYPOINT [ "/entrypoint" ]

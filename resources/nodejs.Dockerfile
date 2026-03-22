ARG BASE=nix-docker.registry.twcstorage.ru/base/redhat/ubi10-minimal:10.1002-1766033715
ARG NODEJS_MAJOR_VERSION=22
ARG NODEJS_VERSION=22.20.0

FROM ${BASE} AS nodejs
ARG NODEJS_MAJOR_VERSION
ARG NODEJS_VERSION

RUN microdnf -y --refresh \
                --setopt=install_weak_deps=0 \
                --setopt=tsflags=nodocs install curl \
    && curl -kLso nodejs_${NODEJS_MAJOR_VERSION}.sh "https://rpm.nodesource.com/setup_${NODEJS_MAJOR_VERSION}.x" \
    && chmod +x nodejs_${NODEJS_MAJOR_VERSION}.sh \
    && ./nodejs_${NODEJS_MAJOR_VERSION}.sh \
    && microdnf -y --refresh \
                --setopt=install_weak_deps=0 \
                --setopt=tsflags=nodocs \
                --disablerepo=nodesource-nsolid install nodejs-${NODEJS_VERSION} \
    && node --version \
    && npm --version \
    && microdnf clean all \
    && rm -rf /var/cache/dnf /var/cache/yum

FROM nodejs AS builder

WORKDIR /src

COPY --chown=10001:10001 package.json package-lock.json ./

RUN npm ci

COPY --chown=10001:10001 . .

RUN npm run build:prod

FROM nodejs

WORKDIR /app

COPY --from=builder /src/package.json /src/package-lock.json ./

RUN npm ci --omit=dev

COPY --from=builder /src/build .

USER 10001

EXPOSE 3000

ENTRYPOINT ["node", "/app/index.js"]

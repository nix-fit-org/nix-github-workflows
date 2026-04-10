ARG BASE=nix-docker.registry.twcstorage.ru/base/redhat/ubi10-minimal:10.1002-1766033715
ARG DOTNET_MAJOR_VERSION=9
ARG DOTNET_VERSION=9.0

FROM ${BASE} AS dotnet
ARG DOTNET_MAJOR_VERSION
ARG DOTNET_VERSION

RUN microdnf -y --refresh \
                --setopt=install_weak_deps=0 \
                --setopt=tsflags=nodocs install dotnet-sdk-${DOTNET_VERSION} \
    && dotnet --version \
    && microdnf clean all \
    && rm -rf /var/cache/dnf /var/cache/yum

FROM dotnet AS builder

ARG TARGETARCH
# Path to main .csproj (always set by pipeline).
ARG CSPROJ_PATH

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /src

ENV DOTNET_NOLOGO=true \
    DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1 \
    DOTNET_GENERATE_ASPNET_CERTIFICATE=false \
    DOTNET_CLI_TELEMETRY_OPTOUT=1

COPY --chown=10001:10001 . .

RUN DOTNET_RID="linux-${TARGETARCH/amd64/x64}" && \
    dotnet restore "$CSPROJ_PATH" -r "$DOTNET_RID" -p:SelfContained=true

RUN DOTNET_RID="linux-${TARGETARCH/amd64/x64}" && \
    PROJ_NAME=$(basename "$CSPROJ_PATH" .csproj) && \
    dotnet publish "$CSPROJ_PATH" \
        --no-restore \
        --configuration Release \
        -r "$DOTNET_RID" \
        -p:SelfContained=true \
        -p:UseAppHost=true \
        -p:PublishDir=/src/dist && \
    mv "/src/dist/$PROJ_NAME" /src/dist/app

FROM ${BASE}

RUN microdnf -y --refresh \
                --setopt=install_weak_deps=0 \
                --setopt=tsflags=nodocs install libicu \
    && microdnf clean all \
    && rm -rf /var/cache/dnf /var/cache/yum

WORKDIR /dist

COPY --from=builder --chmod=755 /src/dist/ .

USER 10001

ENTRYPOINT ["/dist/app"]

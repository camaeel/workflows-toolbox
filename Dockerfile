FROM alpine:3

# renovate: datasource=github-releases depName=terraform packageName=hashicorp/terraform
ARG TERRAFORM_VERSION=1.14.3
# renovate: datasource=github-releases depName=packer packageName=hashicorp/packer
ARG PACKER_VERSION=1.15.0
# renovate: datasource=github-releases depName=opentofu packageName=opentofu/opentofu
ARG TOFU_VERSION=1.11.4
# renovate: datasource=github-releases depName=terragrunt packageName=gruntwork-io/terragrunt
ARG TERRAGRUNT_VERSION=0.99.0
# renovate: datasource=github-releases depName=talosctl packageName=siderolabs/talos
ARG TALOS_VERSION=1.12.2

ARG TARGETARCH
ARG TARGETOS

USER root

RUN  adduser -u 8737 -D executor

RUN apk update && apk upgrade && \
    apk add --no-cache curl jq yq wget python3 py3-pip ansible && \
    apk add --no-cache tenv --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing/ && \
    wget https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_${TARGETOS}_${TARGETARCH}.zip && \
    unzip packer_${PACKER_VERSION}_${TARGETOS}_${TARGETARCH}.zip -d /usr/local/bin && \
    rm packer_${PACKER_VERSION}_${TARGETOS}_${TARGETARCH}.zip && \
    chmod +x /usr/local/bin/packer && \
    case "${TARGETARCH}" in \
      amd64)  export AWS_ARCH="X86_64"; export AWS_CLI_ARCH="x86_64" ;; \
      arm64)  export AWS_ARCH="Aarch64"; export AWS_CLI_ARCH="aarch64"  ;; \
      *)      echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_CLI_ARCH}.zip" -f -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip ./aws && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /usr/local/bin/

RUN wget https://github.com/siderolabs/talos/releases/download/v${TALOS_VERSION}/talosctl-${TARGETOS}-${TARGETARCH} -O /usr/local/bin/talosctl-${TARGETOS}-${TARGETARCH} && \
    chmod a+x /usr/local/bin/talosctl-${TARGETOS}-${TARGETARCH} && \
    curl -L https://github.com/siderolabs/talos/releases/download/v${TALOS_VERSION}/sha512sum.txt | grep talosctl-${TARGETOS}-${TARGETARCH} | sha512sum -c - && \
    mv /usr/local/bin/talosctl-${TARGETOS}-${TARGETARCH} /usr/local/bin/talosctl

USER executor

ENV TENV_AUTO_INSTALL=true
ENV TENV_ROOT=/home/executor/.tenv

RUN --mount=type=secret,id=TENV_GITHUB_TOKEN,env=TENV_GITHUB_TOKEN \
    tenv tf install ${TERRAFORM_VERSION} && tenv tf use ${TERRAFORM_VERSION} &&\
    tenv tg install ${TERRAGRUNT_VERSION} && tenv tg use ${TERRAGRUNT_VERSION} && \
    tenv tofu install ${TOFU_VERSION} && tenv tofu use ${TOFU_VERSION}

WORKDIR /home/executor

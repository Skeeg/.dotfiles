# k8s-toolbox: Kubernetes CLIs in one image, run through bin/k8s-toolbox.
# Build: k8s-toolbox build   (or: docker build -t k8s-toolbox:local docker/k8s-toolbox)
#
# Every version is a build arg. Bump one, rebuild, done. Each download is
# checked against the checksum file its project publishes with the release.
# That catches corruption and a swapped mirror, not a compromised release.
#
# KUBECTL_VERSION tracks the k3s version the lab clusters run (kubectl
# supports one minor version of skew either way).

ARG ALPINE_VERSION=3.24.2
ARG DEBIAN_VERSION=trixie-20260918-slim
ARG DOCKER_VERSION=29.7.2

FROM docker:${DOCKER_VERSION}-cli AS docker-cli

FROM alpine:${ALPINE_VERSION} AS fetch
ARG TARGETARCH
ARG KUBECTL_VERSION=v1.36.5
ARG HELM_VERSION=v4.3.0
ARG K3D_VERSION=v5.9.0
ARG KIND_VERSION=v0.33.0
ARG MINIKUBE_VERSION=v1.39.0
ARG K9S_VERSION=v0.51.0
ARG KUBECTX_VERSION=v0.11.0
ARG JQ_VERSION=1.8.2
ARG YQ_VERSION=v4.54.1

RUN apk add --no-cache bash curl
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]
WORKDIR /dl

# get <url> <checksum-url> [name-in-checksum-file]
# Downloads <url> and checks it. With no name, the checksum file holds the bare hash.
RUN cat > /usr/local/bin/get <<'EOF'
#!/bin/bash
set -euo pipefail
url=$1 sums=$2 name=${3:-}
file=${url##*/}
curl -fsSLo "$file" "$url"
lines=$(curl -fsSL "$sums")
if [[ -n $name ]]; then
  lines=$(grep -E "(^|[ */(])${name}([ )]|$)" <<<"$lines")
  # BSD-style files list many algorithms per asset, some also 64 hex chars long.
  if grep -q '^SHA256 (' <<<"$lines"; then lines=$(grep '^SHA256 (' <<<"$lines"); fi
fi
# First field that is exactly 64 hex chars. awk reads all input, so no SIGPIPE under pipefail.
hash=$(awk '{for (i = 1; i <= NF; i++) if (!h && $i ~ /^[0-9a-f]+$/ && length($i) == 64) h = $i} END {print h}' <<<"$lines")
[[ -n $hash ]] || { echo "no checksum for $file" >&2; exit 1; }
echo "$hash  $file" | sha256sum -c -
EOF
RUN chmod +x /usr/local/bin/get && mkdir -p /out

RUN get "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" \
        "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl.sha256" \
 && install -m 755 kubectl /out/

RUN f="helm-${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" \
 && get "https://get.helm.sh/$f" "https://get.helm.sh/$f.sha256sum" "$f" \
 && tar -xzf "$f" && install -m 755 "linux-${TARGETARCH}/helm" /out/

RUN get "https://github.com/k3d-io/k3d/releases/download/${K3D_VERSION}/k3d-linux-${TARGETARCH}" \
        "https://github.com/k3d-io/k3d/releases/download/${K3D_VERSION}/checksums.txt" "k3d-linux-${TARGETARCH}" \
 && install -m 755 "k3d-linux-${TARGETARCH}" /out/k3d

RUN get "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-${TARGETARCH}" \
        "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-${TARGETARCH}.sha256sum" "kind-linux-${TARGETARCH}" \
 && install -m 755 "kind-linux-${TARGETARCH}" /out/kind

RUN get "https://github.com/kubernetes/minikube/releases/download/${MINIKUBE_VERSION}/minikube-linux-${TARGETARCH}" \
        "https://github.com/kubernetes/minikube/releases/download/${MINIKUBE_VERSION}/minikube-linux-${TARGETARCH}.sha256" \
 && install -m 755 "minikube-linux-${TARGETARCH}" /out/minikube

RUN f="k9s_Linux_${TARGETARCH}.tar.gz" \
 && get "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/$f" \
        "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/checksums.sha256" "$f" \
 && tar -xzf "$f" k9s && install -m 755 k9s /out/

# kubectx names its assets x86_64, not amd64.
RUN arch=$([[ $TARGETARCH == amd64 ]] && echo x86_64 || echo "$TARGETARCH") \
 && for t in kubectx kubens; do \
      f="${t}_${KUBECTX_VERSION}_linux_${arch}.tar.gz"; \
      get "https://github.com/ahmetb/kubectx/releases/download/${KUBECTX_VERSION}/$f" \
          "https://github.com/ahmetb/kubectx/releases/download/${KUBECTX_VERSION}/checksums.txt" "$f"; \
      tar -xzf "$f" "$t" && install -m 755 "$t" /out/; \
    done

RUN get "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-${TARGETARCH}" \
        "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/sha256sum.txt" "jq-linux-${TARGETARCH}" \
 && install -m 755 "jq-linux-${TARGETARCH}" /out/jq

# yq's "checksums-bsd" is the one file in its release with plain SHA-256 lines.
RUN get "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${TARGETARCH}" \
        "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/checksums-bsd" "yq_linux_${TARGETARCH}" \
 && install -m 755 "yq_linux_${TARGETARCH}" /out/yq

# Debian, not Alpine: minikube is linked against glibc, and Alpine has only musl.
FROM debian:${DEBIAN_VERSION}
# git for helm plugins and remote kustomize bases.
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates git less \
 && rm -rf /var/lib/apt/lists/*
# kind and minikube drive Docker through its CLI. k3d uses the API directly.
COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=fetch /out/ /usr/local/bin/

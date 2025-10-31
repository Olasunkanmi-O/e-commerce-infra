#!/bin/bash

set -euo pipefail


# VARIABLES (parameterize)

# KOPS_CLUSTER_NAME=${KOPS_CLUSTER_NAME:-ecommerce.alasoasiko.co.uk}
# KOPS_STATE_STORE=${KOPS_STATE_STORE:-s3://ecommerce-kops-state-1232}
# AWS_REGION=${AWS_REGION:-eu-west-2}
ISTIO_VERSION=${ISTIO_VERSION:-1.24.2}
HOME_DIR=/home/ubuntu


# UPDATE AND INSTALL DEPENDENCIES

sudo apt update -y
sudo apt install -y wget curl unzip git apt-transport-https ca-certificates


# INSTALL AWS CLI

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip /tmp/awscliv2.zip -d /tmp
sudo /tmp/aws/install
rm -rf /tmp/awscliv2.zip /tmp/aws


# INSTALL KOPS

KOPS_VERSION=$(curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name | cut -d '"' -f 4)
curl -Lo /tmp/kops https://github.com/kubernetes/kops/releases/download/${KOPS_VERSION}/kops-linux-amd64
chmod +x /tmp/kops
sudo mv /tmp/kops /usr/local/bin/kops


# INSTALL KUBECTL

KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl


# INSTALL HELM

curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 /tmp/get_helm.sh
/tmp/get_helm.sh
rm -f /tmp/get_helm.sh


# INSTALL ArgoCD CLI

VERSION=$(curl -L -s https://raw.githubusercontent.com/argoproj/argo-cd/stable/VERSION)
curl -sSL -o /tmp/argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/v$VERSION/argocd-linux-amd64
sudo install -m 555 /tmp/argocd-linux-amd64 /usr/local/bin/argocd
rm -f /tmp/argocd-linux-amd64


# INSTALL ISTIO

sudo mkdir -p /opt/istio
cd /opt/istio
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -
sudo chown -R ubuntu:ubuntu istio-$ISTIO_VERSION
echo "export PATH=/opt/istio/istio-$ISTIO_VERSION/bin:\$PATH" >> $HOME_DIR/.bashrc
export PATH=/opt/istio/istio-$ISTIO_VERSION/bin:$PATH


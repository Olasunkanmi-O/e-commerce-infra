#!/bin/bash
set -e



KOPS_STATE_STORE=${KOPS_STATE_STORE:-s3://ecommerce-kops-state-1232}
CLUSTER_NAME=${CLUSTER_NAME:-ecommerce.alasoasiko.co.uk}
DNS_ZONE=${DNS_ZONE:-ecommerce.alasoasiko.co.uk}
ZONES=${ZONES:-eu-west-2a,eu-west-2b}
NODE_COUNT=${NODE_COUNT:-2}
NODE_SIZE=${NODE_SIZE:-t3.medium}
MASTER_SIZE=${MASTER_SIZE:-t3.medium}
SSH_KEY_PATH=${SSH_KEY_PATH:-~/.ssh/id_rsa.pub}

echo "--------------------------------------------------"
echo "Creating Kops cluster..."
echo "Cluster: $CLUSTER_NAME"
echo "State store: $KOPS_STATE_STORE"
echo "DNS zone: $DNS_ZONE"
echo "Zones: $ZONES"
echo "--------------------------------------------------"

kops create cluster \
  --name=$CLUSTER_NAME \
  --state=$KOPS_STATE_STORE \
  --zones=$ZONES \
  --node-count=$NODE_COUNT \
  --node-size=$NODE_SIZE \
  --control-plane-size=$MASTER_SIZE \
  --dns-zone=$DNS_ZONE \
  --ssh-public-key=$SSH_KEY_PATH \
  --yes

echo "Cluster creation initiated. Run validate_cluster.sh to confirm readiness."

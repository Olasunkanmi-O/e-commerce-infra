#!/bin/bash
set -e

echo "⚠️  This script will delete ArgoCD, all applications, Helm releases, cert-manager resources, Ingresses, and custom namespaces."
echo "Make sure you really want to remove everything!"
read -p "Type YES to continue: " confirm
if [ "$confirm" != "YES" ]; then
    echo "Aborted."
    exit 1
fi

echo "==> Deleting ArgoCD applications"
kubectl delete applications --all -n argocd || true

echo "==> Deleting ArgoCD namespace"
kubectl delete ns argocd || true

echo "==> Deleting Helm releases in all namespaces"
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
    releases=$(helm list -n $ns -q)
    if [ -n "$releases" ]; then
        for release in $releases; do
            echo "Deleting Helm release $release in namespace $ns"
            helm uninstall $release -n $ns
        done
    fi
done

echo "==> Deleting cert-manager resources"
kubectl delete certificates --all -A || true
kubectl delete certificaterequests --all -A || true
kubectl delete clusterissuers --all || true

echo "==> Deleting cert-manager namespace and CRDs"
kubectl delete ns cert-manager || true
kubectl delete crd certificaterequests.cert-manager.io certificates.cert-manager.io clusterissuers.cert-manager.io orders.acme.cert-manager.io challenges.acme.cert-manager.io || true

echo "==> Deleting all Ingresses and Services"
kubectl delete ingress --all -A || true
kubectl delete svc --all -A || true

echo "==> Deleting custom namespaces"
# Replace with any custom namespaces you created
CUSTOM_NAMESPACES=("grafana" "prometheus" "apps" "kubernetes-dashboard" "monitoring")
for ns in "${CUSTOM_NAMESPACES[@]}"; do
    kubectl delete ns $ns || true
done

echo "==> Cleanup completed!"
kubectl get ns

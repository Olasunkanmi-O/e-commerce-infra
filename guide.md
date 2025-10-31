Perfect. Below is your complete **`guide.md`** — a clean, technical, step-by-step documentation of your project up to where you stopped (Helm installation, ArgoCD, app deployments, monitoring stack, and ingress/TLS setup).

---

# E-commerce Microservices Deployment on Kubernetes using Helm, ArgoCD, and Monitoring Stack

## 1. Project Overview

This guide documents the setup of an e-commerce microservices application deployed on a Kubernetes cluster managed via **kOps**.
The deployment uses **Helm** for chart management, **ArgoCD** for GitOps-based deployments, and **Prometheus + Grafana** for monitoring and visualization.
Ingress controllers, **cert-manager**, and **Let's Encrypt** are used for secure, domain-based access.

---

## 2. Prerequisites and Setup

Ensure the following are ready before proceeding:

* A running **Kubernetes cluster** (created with kOps or EKS)
* **kubectl** installed and configured with access to the cluster
* A valid **domain name** pointing to your ingress controller's public IP
* Sufficient IAM permissions for cert-manager and external-dns (if used)
* Internet access from cluster nodes

---
## 3. install ingress controller
Add the ingress-nginx helm repo, then install the Ingress Controller 
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.publishService.enabled=true
```

---

## 3. Helm Installation and Verification

Install Helm on the control node (or management server):

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

Verify installation:

```bash
helm version
```

Add the stable Helm repositories used throughout this setup:

```bash
helm repo add stable https://charts.helm.sh/stable
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jetstack https://charts.jetstack.io
helm repo update
```

---

## 4. ArgoCD Installation and Configuration

Create the namespace and install ArgoCD:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Verify ArgoCD components:

```bash
kubectl get pods -n argocd
```

Wait until all pods are in **Running** state.

Retrieve the initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Port-forward to access the UI locally:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Access via browser:

```
https://localhost:8080
```

Login with:

* Username: `admin`
* Password: (output from previous command)

---

## 5. Deploying Microservices using Helm and ArgoCD Applications

The e-commerce microservices are deployed as separate ArgoCD `Application` manifests that point to their respective Helm chart paths within the GitHub repository.

Each application manifest follows this structure:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: adservice
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://github.com/Olasunkanmi-O/e-commerce-helm'
    targetRevision: main
    path: charts/adservice
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

All services were defined similarly and applied with:

```bash
kubectl apply -f apps/ -n argocd
```

Confirm creation and synchronization:

```bash
kubectl get applications -n argocd
```

Once all show `Synced` and `Healthy`, the microservices are live in the cluster.

---

## 6. Cert-Manager and TLS with Let's Encrypt

Install cert-manager via Helm:

```bash
kubectl create namespace cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --set installCRDs=true
```

Verify pods:

```bash
kubectl get pods -n cert-manager
```

Create a **ClusterIssuer** for Let's Encrypt (production):

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: your-email@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
```

Apply it:

```bash
kubectl apply -f cluster-issuer.yaml
```

Certificates are then generated automatically via the Ingress annotations.

---

## 7. Ingress Configuration for ArgoCD and Grafana

Create the **Ingress** resource for ArgoCD:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-ingress
  namespace: argocd
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
      - argocd.alasoasiko.co.uk
    secretName: argocd-tls
  rules:
  - host: argocd.alasoasiko.co.uk
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 443
```

Apply it:

```bash
kubectl apply -f argocd-ingress.yaml
```

Repeat similar steps for Grafana with its own host record.

Validate certificate creation:

```bash
kubectl describe certificate argocd-tls -n argocd
```

If certificate creation fails, verify that your DNS record points to the ingress controller’s external IP and retry.

---

## 8. Prometheus and Grafana Deployment

Install Prometheus using Helm:

```bash
helm install prometheus prometheus-community/prometheus --namespace monitoring --create-namespace
```

Install Grafana:

```bash
helm install grafana grafana/grafana --namespace monitoring
```

Retrieve Grafana admin password:

```bash
kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode
```

Port-forward Grafana:

```bash
kubectl port-forward svc/grafana 3000:80 -n monitoring
```

Access via browser:

```
http://localhost:3000
```

Login with:

* Username: admin
* Password: (output above)

Add Prometheus as a data source in Grafana, using the internal service endpoint:

```
http://prometheus-server.monitoring.svc.cluster.local
```

You can now import dashboards for Kubernetes, nodes, and applications.

---

## 9. Validation and Observability

To confirm deployments:

```bash
kubectl get pods -A
kubectl get svc -A
kubectl get ingress -A
```

To verify that certificates are valid:

```bash
kubectl get certificate -A
```

To inspect ArgoCD application health:

```bash
kubectl get applications -n argocd
```

Ensure that each service shows as `Synced` and `Healthy`.

---

## 10. Next Steps: Istio Integration

For advanced traffic management, observability, and service-to-service security, integrate **Istio** as the service mesh.
In the next phase:

* Install Istio using `istioctl`
* Enable sidecar injection
* Configure gateways and virtual services for frontend and backend routing
* Integrate Grafana, Prometheus, and Kiali with Istio telemetry

---

### Notes

* Ensure DNS propagation before issuing TLS certificates.
* The same ingress and cert-manager pattern can be reused for Prometheus, Grafana, and other dashboards.
* Avoid using NodePort for external access once ingress is fully functional.

---

Would you like me to add a short **“Directory structure overview”** at the top (showing `charts/`, `apps/`, etc.) to make navigation easier when you revisit this project?

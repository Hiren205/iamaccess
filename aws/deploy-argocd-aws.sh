#!/bin/bash
# Run this from a machine configured with AWS CLI credentials
# or with access to the AWS environment.

set -euo pipefail

REGION="eu-north-1"
CLUSTER="aws-eks-cluster"
NAMESPACE="argocd-aws"
CHART_VERSION="9.4.10"
echo "run"
# ── 1. Configure kubectl for your EKS cluster ──────────────────────────────
aws eks update-kubeconfig \
  --region "$REGION" \
  --name "$CLUSTER" \
  --profile "myuser"
echo "run"
echo "✓ Connected to cluster: $(kubectl config current-context)"

# ── 2. Add Helm repo ────────────────────────────────────────────────────────
helm repo add argo https://argoproj.github.io/argo-helm --force-update
helm repo update

# ── 3. Create namespace ─────────────────────────────────────────────────────
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# ── 4. Deploy ArgoCD ────────────────────────────────────────────────────────
helm upgrade --install argocd argo/argo-cd \
  --version "$CHART_VERSION" \
  --namespace "$NAMESPACE" \
  --values ./argocd-aws-values.yaml \
  --wait \
  --timeout 10m

echo "✓ ArgoCD deployed"

# ── 5. Verify ───────────────────────────────────────────────────────────────
echo ""
echo "=== Pod status ==="
kubectl get pods -n "$NAMESPACE"
echo ""
echo "=== ArgoCD initial admin password ==="
kubectl -n "$NAMESPACE" get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo ""
echo ""

# ── 6. Access ArgoCD UI via port-forward ───────────────────────────────────
echo "=== Access Instructions ==="
echo "No domain configured. To access the UI, run:"
echo "kubectl port-forward svc/argocd-server -n $NAMESPACE 8081:80"
echo ""
echo "Then open your browser to: http://localhost:8081"
echo "Username: admin"
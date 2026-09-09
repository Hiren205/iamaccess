#!/bin/bash
# Run this from a machine configured with AWS CLI credentials
# or with access to the AWS environment.

set -euo pipefail

REGION="eu-north-1"
CLUSTER="aws-eks-cluster"
NAMESPACE="jenkins"

echo "run"
# ── 1. Configure kubectl for your EKS cluster ──────────────────────────────
aws eks update-kubeconfig \
  --region "$REGION" \
  --name "$CLUSTER" \
  --profile "myuser"
echo "run"
echo "✓ Connected to cluster: $(kubectl config current-context)"

# ── 2. Add Helm repo ────────────────────────────────────────────────────────
helm repo add jenkins https://charts.jenkins.io --force-update
helm repo update

# ── 3. Create namespace ─────────────────────────────────────────────────────
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# ── 4. Deploy Jenkins ────────────────────────────────────────────────────────
helm upgrade --install jenkins jenkins/jenkins \
  --namespace "$NAMESPACE" \
  --values ./value.yaml \
  --wait \
  --timeout 10m

echo "✓ Jenkins deployed"

# ── 5. Verify ───────────────────────────────────────────────────────────────
echo ""
echo "=== Pod status ==="
kubectl get pods -n "$NAMESPACE"

# ── 6. Access Jenkins UI via port-forward ───────────────────────────────────
echo ""
echo "=== Access Instructions ==="
echo "No domain configured. To access the UI, run:"
echo "kubectl port-forward svc/jenkins -n $NAMESPACE 8080:8080"
echo ""
echo "Then open your browser to: http://localhost:8080"
echo "Username: admin"
echo "To get the password, run:"
echo "kubectl exec --namespace $NAMESPACE -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password"
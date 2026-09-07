#!/bin/bash

set -euo pipefail

CLUSTER_NAME="aws-eks-cluster"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
POLICY_NAME="AWSLoadBalancerControllerIAMPolicytwo"
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"
VPC_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" --query "cluster.resourcesVpcConfig.vpcId" --output text)
LBC_VERSION="v3.4.0"
HELM_CHART_VERSION="3.4.0"
# 1. Download the IAM policy document
curl -sO "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/${LBC_VERSION}/docs/install/iam_policy.json"
# 2. Check if the IAM policy already exists
echo "Checking if IAM policy ${POLICY_NAME} exists..."
if aws iam get-policy --policy-arn "$POLICY_ARN" > /dev/null 2>&1; then
    echo "Policy already exists. Skipping creation."
else
    echo "Policy does not exist. Creating it now..."
    aws iam create-policy \
      --policy-name "$POLICY_NAME" \
      --policy-document file://iam_policy.json
fi

# 3. Create IRSA for ALB controller
# (Note: eksctl automatically skips or updates if the service account exists, 
# but you can add --override-existing-serviceaccounts if you want to force overwrite)
eksctl create iamserviceaccount \
  --cluster "$CLUSTER_NAME" \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --attach-policy-arn "$POLICY_ARN" \
  --approve

# 4. Install via Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --version "$HELM_CHART_VERSION" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=eu-north-1 \
  --set vpcId="$VPC_ID" \
  --wait
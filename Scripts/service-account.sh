#!/bin/bash

set -euo pipefail

# Ensure all parameters are passed
if [ "$#" -ne 6 ]; then
    echo "Usage: $0 <AWS_PROFILE> <AWS_ACCOUNT_ID> <CLUSTER_NAME> <REGION> <NAMESPACE> <POLICY_NAME>"
    exit 1
fi

AWS_PROFILE=$1
AWS_ACCOUNT_ID=$2
CLUSTER_NAME=$3
REGION=$4
NAMESPACE=$5
POLICY_NAME=$6

# Setup EKS Context Name
CLUSTER_CONTEXT="arn:aws:eks:${REGION}:${AWS_ACCOUNT_ID}:cluster/${CLUSTER_NAME}"
# Construct the target Policy ARN
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"

# ==========================================
# STEP 1 — Validate/Create Namespace
# ==========================================
echo "Checking if Kubernetes namespace '${NAMESPACE}' exists..."
if ! kubectl get namespace "${NAMESPACE}" --context "${CLUSTER_CONTEXT}" >/dev/null 2>&1; then
  echo "Namespace '${NAMESPACE}' not found. Creating it..."
  kubectl create namespace "${NAMESPACE}" --context "${CLUSTER_CONTEXT}"
else
  echo "Namespace '${NAMESPACE}' already exists."
fi

# ==========================================
# STEP 2 — Check/Create the policy in AWS IAM
# ==========================================
echo "Checking if IAM Policy '${POLICY_NAME}' already exists..."

# Attempt to fetch the policy. If it returns 0, the policy exists.
if aws iam get-policy --profile "${AWS_PROFILE}" --policy-arn "${POLICY_ARN}" >/dev/null 2>&1; then
  echo "IAM Policy '${POLICY_NAME}' already exists. Skipping creation."
  echo "Target Policy ARN set to: ${POLICY_ARN}"
else
  echo "IAM Policy not found. Generating dynamic IAM policy string..."
  
  POLICY_DOCUMENT=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowSecretManagerAccess",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:${REGION}:${AWS_ACCOUNT_ID}:secret:*"
    }
  ]
}
EOF
)

  echo "Creating IAM Policy in AWS using profile: ${AWS_PROFILE}..."
  aws iam create-policy \
    --profile "${AWS_PROFILE}" \
    --policy-name "${POLICY_NAME}" \
    --policy-document "${POLICY_DOCUMENT}" \
    --region "${REGION}"
    
  echo "Target Policy ARN successfully created: ${POLICY_ARN}"
fi

# ==========================================
# STEP 3 — Create IAM Service Accounts (IRSA)
# ==========================================
# Array of service accounts to create
SERVICE_ACCOUNTS=("neof-prd-secret-manager-sa")

for SA_NAME in "${SERVICE_ACCOUNTS[@]}"; do
  echo "--------------------------------------------------------"
  echo "Creating IAM Service Account: ${SA_NAME}"
  echo "--------------------------------------------------------"
  
  # Note: eksctl automatically handles existing service accounts gracefully 
  # or updates them if policies change.
  eksctl create iamserviceaccount \
    --profile "${AWS_PROFILE}" \
    --cluster "${CLUSTER_NAME}" \
    --region "${REGION}" \
    --namespace "${NAMESPACE}" \
    --name "${SA_NAME}" \
    --attach-policy-arn "${POLICY_ARN}" \
    --approve
done

echo "🎉 All service accounts processed successfully using profile ${AWS_PROFILE}!"
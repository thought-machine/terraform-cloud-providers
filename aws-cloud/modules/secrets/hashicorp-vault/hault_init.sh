#!/bin/bash
set -eE -o pipefail
trap '[ -f "${KUBECONFIG:-}" ] && rm -f "$KUBECONFIG"' EXIT
trap 'rc=$?; echo "Error (exit $rc) at line $LINENO in $0"; exit $rc' ERR

HAULT_NAMESPACE=${HAULT_NAMESPACE:-"hault-system"}
HAULT_POD=${HAULT_POD:-"hault-vault-0"}
ROOT_TOKEN_SECRET_NAME=${ROOT_TOKEN_SECRET_NAME:-"hault-init"} # name of k8s secret containing the hvs Hault Root Key.
[[ -z "$AWS_REGION" ]] && echo "missing AWS_REGION environment variable." && exit 1
[[ -z "$EKS_CLUSTER_NAME" ]] && echo "missing EKS_CLUSTER_NAME environment variable." && exit 1
export KUBECONFIG=$(mktemp)
aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER_NAME

attempts=0
until STATUS=$(kubectl exec -n ${HAULT_NAMESPACE} ${HAULT_POD} -- sh -c "export VAULT_SKIP_VERIFY=true; vault status -format=json"); do
    if [[ $(echo "$STATUS" | jq -r '.initialized') == "false" ]]; then
        echo "Hault is not initialized. Initializing Vault..."
        INIT_RESULT=$(kubectl exec -n ${HAULT_NAMESPACE} ${HAULT_POD} -- sh -c "export VAULT_SKIP_VERIFY=true; vault operator init -format=json")
        echo INIT_RESULT: $INIT_RESULT
        ROOT_TOKEN=$(echo "$INIT_RESULT" | jq -r '.root_token')
        kubectl create secret generic "$ROOT_TOKEN_SECRET_NAME" \
            --namespace "$HAULT_NAMESPACE" \
            --from-literal=root_token="$ROOT_TOKEN" \
            --dry-run=client -o yaml | kubectl apply -f -
        break
    elif [[ $(echo "$STATUS" | jq -r '.initialized') == "true" ]]; then
        echo "Hault is initialized."; break
    fi
    echo "Waiting for Vault pod to be ready..."
    sleep 10
    attempts=$((attempts+1))
    if [ $attempts -ge 10 ]; then
        echo "Exceeded retries waiting for Hault Pod vault status"; exit 1;
    fi
done
# Show hault status.
kubectl exec -n ${HAULT_NAMESPACE} ${HAULT_POD} -- sh -c "export VAULT_SKIP_VERIFY=true; vault status -format=json"

echo "Verifying hault root token secret"
attempts=0
until ROOT_TOKEN_ENCODED=$(kubectl get secret hault-init -n hault-system -o jsonpath='{.data.root_token}' 2>/dev/null); do
    sleep 5
    attempts=$((attempts+1))
    if [ $attempts -ge 6 ]; then echo "Exceeded retries waiting to verify hault root token secret."; exit 1; fi
    echo "retrying..."
done
ROOT_TOKEN_DECODED=$(echo $ROOT_TOKEN_ENCODED | base64 --decode)
echo "Verified existence of $ROOT_TOKEN_SECRET_NAME secret containing hault root token."

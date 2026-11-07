#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME=demo
IMAGE=demo-service:1.0.0
INGRESS_NGINX_VERSION=controller-v1.15.1

for command in docker kind kubectl helm; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Required command not found: $command" >&2
    exit 1
  fi
done

if ! docker info >/dev/null 2>&1; then
  echo "Docker is installed but its daemon is not available." >&2
  exit 1
fi

kind_config="$(mktemp)"
trap 'rm -f "$kind_config"' EXIT
cat > "$kind_config" <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    image: kindest/node:v1.34.11@sha256:44e222ee2132dab25ff87301682f89eb82c7880ea3a1bf543bfe9708fd08d67d
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
EOF

if kind get clusters | grep -Fxq "$CLUSTER_NAME"; then
  echo "Reusing kind cluster '$CLUSTER_NAME'."
  kind export kubeconfig --name "$CLUSTER_NAME"
else
  echo "Creating kind cluster '$CLUSTER_NAME'."
  kind create cluster --name "$CLUSTER_NAME" --config "$kind_config" --wait 180s
fi

kubectl config use-context "kind-$CLUSTER_NAME"
kubectl wait --for=condition=Ready nodes --all --timeout=180s
kubectl label node "$CLUSTER_NAME-control-plane" ingress-ready=true --overwrite

echo "Installing ingress-nginx ($INGRESS_NGINX_VERSION)."
kubectl apply -f "https://raw.githubusercontent.com/kubernetes/ingress-nginx/${INGRESS_NGINX_VERSION}/deploy/static/provider/kind/deploy.yaml"
for attempt in {1..90}; do
  ca_bundle="$(kubectl get validatingwebhookconfiguration ingress-nginx-admission \
    -o jsonpath='{.webhooks[0].clientConfig.caBundle}' 2>/dev/null || true)"
  if [[ -n "$ca_bundle" ]]; then
    break
  fi
  sleep 2
done
if [[ -z "${ca_bundle:-}" ]]; then
  echo "ingress-nginx admission webhook did not become ready." >&2
  exit 1
fi
kubectl -n ingress-nginx rollout status deployment/ingress-nginx-controller --timeout=240s

echo "Building and loading $IMAGE."
docker build --tag "$IMAGE" "$ROOT_DIR/service"
kind load docker-image "$IMAGE" --name "$CLUSTER_NAME"

echo "Installing or upgrading the demo release."
helm upgrade --install demo "$ROOT_DIR/chart" \
  --namespace demo --create-namespace --wait --timeout 180s
kubectl -n demo rollout status deployment/demo --timeout=180s

echo "Ready. Try: curl --resolve demo.local:80:127.0.0.1 http://demo.local/"

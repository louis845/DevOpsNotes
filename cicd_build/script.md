This is a convenience script that creates a Gitlab runner in the `<name>-runner` namespace, which has permissions to execute jobs in `<name>-ci` namespace, with minimal permissions. Additionally, a `[hostname]` can be specified to explicitly specify which node to run the CI/CD jobs in. This script expects a `gitlabCA.crt` file inside the same folder as it, that is used for verify the identity for the locally hosted Gitlab instance. For explanation, see [here](../kubernetes/setup_gitlab.md#setup-gitlab-runner). For more options on the Kubernetes Gitlab runner, see [Gitlab's official website](https://docs.gitlab.com/runner/executors/kubernetes/), which supports mounting PVs and so on...

# Script
```sh
#!/bin/bash

# Exit on error
set -e

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "kubectl is not installed. Please install it first."
    exit 1
fi

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo "helm is not installed. Please install it first."
    exit 1
fi

# Check if arguments are provided
if [ $# -lt 2 ] || [ $# -gt 4 ]; then
    echo "Usage: $0 <name> <token> [hostname] [toml_file]"
    echo "  <name>: Name prefix for namespaces (<name>-runner and <name>-ci)"
    echo "  <token>: GitLab runner registration token"
    echo "  [hostname]: Optional - Kubernetes node hostname to restrict runner to"
    echo "  [toml_file]: Optional - Path to additional TOML configuration for the runner"
    exit 1
fi

NAME=$1
TOKEN=$2
HOSTNAME=$3
TOML_FILE=$4
RUNNER_NAMESPACE="${NAME}-runner"
CI_NAMESPACE="${NAME}-ci"
TMP_FILE="values.yaml"

# Check if TOML file exists and is readable if provided
if [ -n "$TOML_FILE" ]; then
    if [ ! -f "$TOML_FILE" ]; then
        echo "Error: TOML file $TOML_FILE does not exist."
        exit 1
    fi
    
    if [ ! -r "$TOML_FILE" ]; then
        echo "Error: TOML file $TOML_FILE is not readable."
        exit 1
    fi
    
    # Basic check if it looks like a TOML file
    if ! grep -q '=' "$TOML_FILE" && ! grep -q '\[\[' "$TOML_FILE"; then
        echo "Warning: File $TOML_FILE may not be a valid TOML file."
        echo "Continuing anyway, but this may cause configuration issues."
    fi
    
    echo "Using additional TOML configuration from: $TOML_FILE"
fi

if [ -f "$TMP_FILE" ]; then
    echo "$TMP_FILE already exists!"
    exit 1
fi

# Check if kubectl is properly configured and can connect to the cluster
echo "Checking kubectl connectivity to the cluster..."
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: kubectl is not properly configured or cannot connect to the cluster."
    echo "Please check your kubeconfig and cluster connection."
    exit 1
fi
echo "kubectl is properly configured and can connect to the cluster."

# Check if the runner namespace already exists
echo "Checking if namespace $RUNNER_NAMESPACE already exists..."
if kubectl get namespace $RUNNER_NAMESPACE &> /dev/null; then
    echo "Error: Namespace $RUNNER_NAMESPACE already exists."
    echo "Please delete the namespace or use a different name."
    exit 1
fi
echo "Namespace $RUNNER_NAMESPACE does not exist, will create it."

# Check if the CI namespace already exists
echo "Checking if namespace $CI_NAMESPACE already exists..."
if kubectl get namespace $CI_NAMESPACE &> /dev/null; then
    echo "Error: Namespace $CI_NAMESPACE already exists."
    echo "Please delete the namespace or use a different name."
    exit 1
fi
echo "Namespace $CI_NAMESPACE does not exist, will create it."

echo "Setting up GitLab Runner with:"
echo "  Runner namespace: $RUNNER_NAMESPACE"
echo "  CI namespace: $CI_NAMESPACE"
echo "  Token: $TOKEN"
if [ -n "$HOSTNAME" ]; then
    echo "  Node hostname: $HOSTNAME"
fi

# Get the cluster IP for the ingress controller
CLUSTER_IP=$(kubectl get -n ingress-nginx svc/ingress-nginx-controller -o jsonpath='{.spec.clusterIP}')
if [ -z "$CLUSTER_IP" ]; then
    echo "Could not determine the cluster IP of ingress-nginx-controller. Please check if it's deployed."
    exit 1
fi

echo "Found ingress-nginx cluster IP: $CLUSTER_IP"

# Create namespaces if they don't exist
kubectl create namespace $RUNNER_NAMESPACE
kubectl create namespace $CI_NAMESPACE

echo "Created namespaces: $RUNNER_NAMESPACE and $CI_NAMESPACE"

# Create service account
kubectl create serviceaccount gitlab-runner-svc-acct -n $RUNNER_NAMESPACE

echo "Created service account: gitlab-runner-svc-acct in namespace $RUNNER_NAMESPACE"

# Create Role for the CI namespace
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: gitlab-runner
  namespace: $CI_NAMESPACE
rules:
- apiGroups: [""]
  resources: ["events"]
  verbs:
  - "list"
  - "watch"
- apiGroups: [""]
  resources: ["pods"]
  verbs:
  - "create"
  - "delete"
  - "get"
  - "list"
  - "watch"
- apiGroups: [""]
  resources: ["pods/attach"]
  verbs:
  - "create"
  - "delete"
  - "get"
  - "patch"
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs:
  - "create"
  - "delete"
  - "get"
  - "patch"
- apiGroups: [""]
  resources: ["pods/log"]
  verbs:
  - "get"
  - "list"
- apiGroups: [""]
  resources: ["secrets"]
  verbs:
  - "create"
  - "delete"
  - "get"
  - "update"
- apiGroups: [""]
  resources: ["serviceaccounts"]
  verbs:
  - "get"
- apiGroups: [""]
  resources: ["services"]
  verbs:
  - "create"
  - "get"
EOF

echo "Created Role: gitlab-runner in namespace $CI_NAMESPACE"

# Create RoleBinding to connect the ServiceAccount to the Role
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: gitlab-runner-binding
  namespace: $CI_NAMESPACE
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: gitlab-runner
subjects:
- kind: ServiceAccount
  name: gitlab-runner-svc-acct
  namespace: $RUNNER_NAMESPACE
EOF

echo "Created RoleBinding: gitlab-runner-binding in namespace $CI_NAMESPACE"

# Start creating the values.yaml with the common configuration
cat > $TMP_FILE <<EOF
image:
  registry: registry.gitlab.com
  image: gitlab-org/gitlab-runner
imagePullPolicy: IfNotPresent
useTini: false
gitlabUrl: http://gitlab-webservice-default.gitlab.svc.cluster.local:8080
runnerToken: $TOKEN
rbac:
  create: false
  clusterWideAccess: false
serviceAccount:
  name: gitlab-runner-svc-acct
unregisterRunners: true
runners:
  executor: kubernetes
  config: |
    [[runners]]
      url = "https://gitlab.example.local"
      clone_url = "https://gitlab.example.local"
      pre_get_sources_script = "git config --global http.https://gitlab.example.local.sslVerify false"
      [runners.kubernetes]
        namespace = "$CI_NAMESPACE"
        image = "alpine"
        privileged = false
EOF

# Add node selector if hostname is provided
if [ -n "$HOSTNAME" ]; then
    cat >> $TMP_FILE <<EOF
        [runners.kubernetes.node_selector]
          "kubernetes.io/hostname" = "$HOSTNAME"
EOF
fi

# Add additional TOML configuration if provided
if [ -n "$TOML_FILE" ]; then
    # Read the TOML file and add proper indentation (8 spaces)
    while IFS= read -r line; do
        # Skip empty lines
        if [[ -z "$line" ]]; then
            continue
        fi
        echo "        $line" >> $TMP_FILE
    done < "$TOML_FILE"
fi

# Add the rest of the configuration
cat >> $TMP_FILE <<EOF
        [[runners.kubernetes.host_aliases]]
          ip = "$CLUSTER_IP"
          hostnames = ["gitlab.example.local"]
certsSecretName: self-administered-ca-cert
metrics:
  enabled: false
service:
  enabled: false
EOF

echo "Created Helm values file: $TMP_FILE"

# Install/upgrade the GitLab Runner using Helm
helm repo add gitlab https://charts.gitlab.io/ || true
helm repo update

helm upgrade --install gitlab-runner-$NAME gitlab/gitlab-runner \
  --namespace $RUNNER_NAMESPACE \
  -f $TMP_FILE

echo "GitLab Runner installed/upgraded successfully in namespace: $RUNNER_NAMESPACE"
echo "CI jobs will run in namespace: $CI_NAMESPACE"
if [ -n "$HOSTNAME" ]; then
    echo "Runner constrained to node: $HOSTNAME"
fi

# Create a self-adminstered CA cert corresponding to the Gitlab instance
script_dir="$(dirname "${BASH_SOURCE[0]}")"
if [ -f "${script_dir}/gitlabCA.crt" ]; then
    kubectl create secret generic -n $RUNNER_NAMESPACE self-administered-ca-cert --from-file=gitlab.example.local.crt=${script_dir}/gitlabCA.crt
    echo "Created self-administered CA certificate secret"
else
    echo "Warning: ${script_dir}/gitlabCA.crt not found. Certificate secret not created."
    echo "You may need to create it manually or provide the certificate file."
fi

echo "Setup complete!"

rm $TMP_FILE
```

# Additional TOML example
```toml
[[runners.kubernetes.volumes.pvc]]
  name = "pvc-1"
  mount_path = "/path/to/mount/point1"
```
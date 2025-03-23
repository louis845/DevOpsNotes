This script creates a PVC in a given namespace of specified size, with additional labels that are to be applied to the underlying PV. This script assumes `rook-cephfs` is a StorageClass that retains its data, and the PVs can be repurposed for other uses (e.g the PVs are datasets).

```sh
if [ $# -lt 3 ]; then
  echo "Usage: $0 <namespace> <pvc-name> <size> [label1=value1] [label2=value2] ..."
  echo "Example: $0 mynamespace pvcname 4Gi type=dataset source=mywebsite"
  exit 1
fi

NAMESPACE=$1
PVC_NAME=$2
SIZE=$3
shift 3  # Remove the first three arguments, leaving only labels

# Validate size format
if [[ ! $SIZE =~ ^[0-9]+[KMGTPEZYkmgtpezy]i?$ ]]; then
  echo "Error: Size '$SIZE' is not in a valid Kubernetes format (e.g., 4Gi, 100Mi, 1Ti)"
  exit 1
fi

# If labels are provided, validate their format
if [ $# -gt 0 ]; then
  for label in "$@"; do
    if [[ ! $label =~ ^[a-zA-Z0-9].+=[a-zA-Z0-9].+$ ]]; then
      echo "Error: Label '$label' is not in valid format. Must be key=value."
      exit 1
    fi
  done
fi

# Function to check if PVC exists
check_pvc_exists() {
  kubectl get pvc -n "$NAMESPACE" "$PVC_NAME" &>/dev/null
  return $?
}

# Check if PVC already exists
if check_pvc_exists; then
  echo "PVC '$PVC_NAME' already exists in namespace '$NAMESPACE'"
  read -p "Do you want to use the existing PVC? (y/n): " use_existing
  if [[ "$use_existing" =~ ^[Yy]$ ]]; then
    echo "Using existing PVC..."
  else
    echo "Operation cancelled by user"
    exit 1
  fi
else
  # Create the PVC with the specified size
  echo "Creating PVC '$PVC_NAME' with size $SIZE in namespace '$NAMESPACE'..."
  
  # Create PVC YAML and apply it
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $PVC_NAME
  namespace: $NAMESPACE
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: $SIZE
  storageClassName: rook-cephfs
EOF
  
  if [ $? -ne 0 ]; then
    echo "Error: Failed to create PVC '$PVC_NAME'"
    exit 1
  fi
  echo "PVC creation request submitted"
fi

# If no labels were provided, we can exit early
if [ $# -eq 0 ]; then
  echo "No labels provided. PVC creation complete."
  exit 0
fi

echo "Waiting for PVC '$PVC_NAME' in namespace '$NAMESPACE' to be bound..."
MAX_ATTEMPTS=60  # Max wait time = 60 * 5 seconds = 5 minutes
attempt=0

while [ $attempt -lt $MAX_ATTEMPTS ]; do
  # Check PVC status
  PVC_STATUS=$(kubectl get pvc -n "$NAMESPACE" "$PVC_NAME" -o jsonpath='{.status.phase}' 2>/dev/null)
  
  # If PVC doesn't exist anymore, exit
  if ! check_pvc_exists; then
    echo "Error: PVC '$PVC_NAME' no longer exists in namespace '$NAMESPACE'"
    exit 1
  fi
  
  # If bound, get PV name
  if [ "$PVC_STATUS" == "Bound" ]; then
    PV_NAME=$(kubectl get pvc -n "$NAMESPACE" "$PVC_NAME" -o jsonpath='{.spec.volumeName}' 2>/dev/null)
    
    if [ -n "$PV_NAME" ]; then
      echo "PVC bound to PV: $PV_NAME"
      
      # Apply all provided labels
      LABEL_CMD="kubectl label pv $PV_NAME"
      for label in "$@"; do
        LABEL_CMD="$LABEL_CMD $label"
      done
      
      # Execute label command
      if $LABEL_CMD; then
        echo "Successfully applied labels to PV $PV_NAME:"
        for label in "$@"; do
          echo "  - $label"
        done
        
        # Print a helpful command to use this PV in other namespaces
        echo -e "\nTo use this PV in another namespace, use:"
        LABEL_SELECTOR=""
        for label in "$@"; do
          LABEL_SELECTOR="${LABEL_SELECTOR}${LABEL_SELECTOR:+,}${label}"
        done
        echo "kubectl get pv -l \"$LABEL_SELECTOR\" -o jsonpath='{.items[0].metadata.name}'"
        exit 0
      else
        echo "Error: Failed to apply labels to PV $PV_NAME"
        exit 1
      fi
    fi
  fi
  
  # PVC not bound yet, wait and try again
  echo "PVC status: $PVC_STATUS. Waiting 5 seconds... (attempt $((attempt+1))/$MAX_ATTEMPTS)"
  sleep 5
  ((attempt++))
done

echo "Error: Timed out waiting for PVC '$PVC_NAME' to be bound"
echo "Current PVC status: $(kubectl get pvc -n "$NAMESPACE" "$PVC_NAME" -o jsonpath='{.status.phase}' 2>/dev/null)"
exit 1
```
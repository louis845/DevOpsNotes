# Scaling up and down services in namespaces
To scale up/down deployments in namespaces, the the following scripts:

# Scaling down
```
#!/bin/bash

# --- Configuration ---
namespace="$1"
deployments_backup_file="./${namespace}_deployments.json"
statefulsets_backup_file="./${namespace}_statefulsets.json"

# --- Input Validation ---
if [ -z "$namespace" ]; then
  echo "Error: Namespace must be provided as an argument."
  echo "Usage: $0 <namespace>"
  exit 1
fi

if ! command -v kubectl &> /dev/null; then
  echo "Error: kubectl not found. Please install it."
  exit 1
fi

# --- Check if namespace exists ---
if ! kubectl get namespace "$namespace" &> /dev/null; then
    echo "Error: Namespace '$namespace' does not exist."
    exit 1
fi

# --- Backup Deployment Information ---
echo "Backing up Deployments in namespace '$namespace' to '$deployments_backup_file'..."
kubectl get deployments -n "$namespace" -o json > "$deployments_backup_file"

if [ $? -ne 0 ]; then
  echo "Error: Failed to backup Deployments."
  exit 1
fi

# --- Backup StatefulSet Information ---
echo "Backing up StatefulSets in namespace '$namespace' to '$statefulsets_backup_file'..."
kubectl get statefulsets -n "$namespace" -o json > "$statefulsets_backup_file"

if [ $? -ne 0 ]; then
  echo "Error: Failed to backup StatefulSets."
  exit 1
fi

# --- Scale Down Deployments ---
echo "Scaling down Deployments in namespace '$namespace'..."
kubectl scale deployments --replicas=0 -n "$namespace" --all
if [ $? -ne 0 ]; then
    echo "Warning: Failed to scale down Deployments."
fi

# --- Scale Down StatefulSets ---
echo "Scaling down StatefulSets in namespace '$namespace'..."
kubectl scale statefulsets --replicas=0 -n "$namespace" --all
if [ $? -ne 0 ]; then
    echo "Warning: Failed to scale down StatefulSets."
fi

echo "Resources scaled down."
exit 0
```

# Scaling up
```
#!/bin/bash

# --- Configuration ---
namespace="$1"
deployments_backup_file="./${namespace}_deployments.json"
statefulsets_backup_file="./${namespace}_statefulsets.json"

# --- Input Validation ---
if [ -z "$namespace" ]; then
  echo "Error: Namespace must be provided as an argument."
  echo "Usage: $0 <namespace>"
  exit 1
fi

if ! command -v kubectl &> /dev/null; then
  echo "Error: kubectl not found. Please install it."
  exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq not found. Please install it."
    exit 1
fi

# --- Check if namespace exists ---
if ! kubectl get namespace "$namespace" &> /dev/null; then
    echo "Error: Namespace '$namespace' does not exist."
    exit 1
fi

# --- Check if Backup Files Exist ---
if [ ! -f "$deployments_backup_file" ]; then
  echo "Error: Deployments backup file '$deployments_backup_file' not found.  Skipping Deployments restore."
fi

if [ ! -f "$statefulsets_backup_file" ]; then
  echo "Error: StatefulSets backup file '$statefulsets_backup_file' not found. Skipping StatefulSets restore."
fi

# --- Restore Deployments ---
if [ -f "$deployments_backup_file" ]; then # Only restore if the file exists
    echo "Restoring Deployments in namespace '$namespace'..."
    deployments=$(jq -r '.items[] | .metadata.name + " " + (.spec.replicas | tostring)' "$deployments_backup_file")
    while read -r deployment_name replica_count; do
      echo "Scaling up Deployment '$deployment_name' to $replica_count replicas..."
      kubectl scale deployment "$deployment_name" --replicas="$replica_count" -n "$namespace"
      if [ $? -ne 0 ]; then
        echo "Warning: Failed to scale up Deployment '$deployment_name'."
      fi
    done <<< "$deployments"
else
    echo "Skipping Deployments restore, no backup file found."
fi

# --- Restore StatefulSets ---
if [ -f "$statefulsets_backup_file" ]; then # Only restore if the file exists
    echo "Restoring StatefulSets in namespace '$namespace'..."
    statefulsets=$(jq -r '.items[] | .metadata.name + " " + (.spec.replicas | tostring)' "$statefulsets_backup_file")
    while read -r statefulset_name replica_count; do
      echo "Scaling up StatefulSet '$statefulset_name' to $replica_count replicas..."
      kubectl scale statefulset "$statefulset_name" --replicas="$replica_count" -n "$namespace"
      if [ $? -ne 0 ]; then
        echo "Warning: Failed to scale up StatefulSet '$statefulset_name'."
      fi
    done <<< "$statefulsets"
else
    echo "Skipping Statefulsets restore, no backup file found."
fi

echo "Resource restoration complete."
exit 0
```
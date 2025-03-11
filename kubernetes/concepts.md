# Core diagram

![relationship](core_relationship.png)

 * Every runnable job is run inside containers
 * A pod is the "smallest" unit that could be run
    * May contain multiple containers
 * Each node is either a control plane node or a worker node
    * Can be physical machine
    * Or VM
 * Kubelets are services used for fundamental kubernetes operations
    * Deploying containers (e.g with containerd)
 * Control plane instructs kubelets what to do
 * `kubectl` command connects to the control plane through the Kubernetes API server
    * `kubectl` can be installed separately in a user's device (e.g developer's laptop)
    * `kubectl` is bundled inside microk8s installations

# Types of "runnable things"
## Deployments
Programs that are expected to run long-term.
## Jobs
Programs that run in a one-off fashion.
## Cron Jobs
Scheduled programs that run periodically or in some expected time

# Namespaces
To isolate different groups of processes, kubernetes supports namespaces so the resources in namespaces are isolated from each other. This allows resources in different namespaces to have the same names, and allows rules to enforce permissions, limits on taking resources and so on.

# Network
Recall that in Docker, it is necessary to specify port forwarding in the `docker-compose.yml` file so a specified port in the host will be forwarded to a port inside a specified container. Kubernetes has similar behaviour.

## Services

Services acts as 

## Ingress

# Helm
Kubernetes uses Helm to install "extensions" on kubernetes. Helm is to kubernetes as is pip is to Python. The "packages" are called Helm charts, and the command is `helm/helm3` (or `microk8s helm/helm3`). 

Helm charts usually create a namespace, and then creates particular deployments and so on in the newly created namespaces, so that the extensions for the kubernetes cluster can be managed by kubernetes operations itself, to reap the benefits of distributed computing.

2. Network configuration
  2.1. Services - A network abstraction layer that handles the access to pods, internal pod to pod communication
  2.2. Ingress - Network configuration to set external communication
3. Configuration data
  3.1. ConfigMaps - Configuration information for non-sensitive purposes (e.g UI settings)
  3.2. Secrets - Config for sensitive purposes (e.g API keys, passwords)
4. Namespaces
  4.1. Can isolate resources from the programs (deployments/jobs).
  4.2. Can limit the resources used in the namespace.
  4.3. Scoping - each "object" (e.g. volume) in different namespaces can have the same name
  4.4. Unique name for the names in a namespace.
5. Persistent volumes
  5.1. Persistent volume - The actual storage resource
  5.2. Persistent volume claim - A request for storage by a pod
6. kubectl - Command for doing various jobs via kubernetes
```
kubectl create -f deployment.yaml     # Create resources from a file
kubectl get pods                      # List all pods
kubectl logs my-pod                   # View pod logs
kubectl exec -it my-pod -- /bin/bash  # Access a running container
kubectl apply -f updated-config.yaml  # Update resources
kubectl delete job batch-job          # Delete a job
kubectl scale deployment webapp --replicas=5  # Scale a deployment
```
7. Kubernetes YAML structure
```
apiVersion: [API version for this resource type]
kind: [Resource type]
metadata:
  name: [Resource name]
  namespace: [Optional namespace]
  labels:
    [Optional key-value pairs]
  annotations:
    [Optional metadata]
spec:
  [Resource-specific configuration]
```
8. Labels and selectors
   8.1. Labels can be attached to most kubernetes resources
   8.2. Selectors are then used to select resources with the given labels
   8.3. Labels are attached to each resources in a dictionary style (key-value pair)
9. 

## Commands
`kubectl describe`
`kubectl get`
Commands to list available resources. Both commands are the same, expect that one gives more detailed output and one gives concise output in tabular form.

`kubectl port-forward`
Forwards a port from the physical machine that the `kubectl` command is installed in, to the specified destination `container:port`. Similar to SSH port forwarding, in that when the command is closed, the tunnel will be closed too.

`kubectl 

## Notes
Hostnames of kubernetes have to be unique.
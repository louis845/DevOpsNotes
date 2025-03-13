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
Services acts as a flag for Kubernetes deployments / pods to declare that they are listening to a port. There are mainly these kinds of services for managing TCP sockets:
  * ClusterIP - Services that are only accessible internally by K8S jobs
    * Doesn't cause physical hosts to listen to any ports indicated by the ClusterIP (intended for internal use only)
    * Still accessible by pods within the cluster, using the ClusterIP address or DNS name.
  * NodePort - Services that make use of a ClusterIP, and makes all nodes listen to the specified port, and forwards to the ClusterIP end point.
    * All physical nodes listen to the specified port, making this service accessible from the outside
    * The destination is the specified ClusterIP, where the ClusterIP specifies the internal load balancing and routing and so on.
  * LoadBalancer - Haven't used this before.

## Ingress
Recall that some setups make use of a [reverse proxy](../encryption.md#encryption-reverse-proxy). A reverse proxy usually reads the HTTP requests and responses and forwards the HTTP requests to the backend servers, or may help upgrade HTTP to HTTPS if the server doesn't natively have TLS/HTTPS capabilities (look up [TLS termination for details](https://en.wikipedia.org/wiki/TLS_termination_proxy)). Unlike services, which operate at the TCP level, this operates at the HTTP level.

Ingresses are the settings for Kubernetes to know which "HTTP services" there are, and correspondingly assign a reverse proxy to forward HTTP requests to the HTTP services. The two main parts of ingresses are:

 * Ingress controller - The program for the reverse proxy (e.g NGINX)
 * Ingress resources - The specifications the configurations of the ingress endpoints
    * What services there are, etc...

Here is the workflow of the Kubernetes ingresses:
![ingress](ingress.png)

Note that the ingress controller is like a usual Kubernetes deployment stack, itself with ClusterIP, NodePort etc configurations. The main point for Kubernetes Ingress stack is to allow to configure HTTP level routing decisions so that the ingress controller is instructed to execute such routing decisions.

The diagram does left to right, so the "incoming" connections start at the Ingress controller's Services. If the ingress controller has only ClusterIP services, and also the backend servers, this will cause the backend servers to be only accessible internally, no matter the Ingress resources configuration. This is because Ingress resources only adjust how the ingress controller routes to the backend servers, but does not dictate at the TCP level whether a port has to be listened to and so on.

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
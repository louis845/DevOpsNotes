# Concepts for K8S Nodes
Here are some relevant concepts for K8S nodes which detail how Kubernetes run as a process in the nodes. Recall that each node hosts a Kubelet, which is the Kubernetes process.

## Kubelet folder
The Kubelet folder is used to store kubelet-related files, such as temporary container pulls and so on. In standard K8S, its usually stored in `/var/lib/kubelet`, while it is stored in `/var/snap/microk8s/common/var/lib/kubelet` for the microk8s variant.

## Core Components
### Control Plane Components

* kube-apiserver
    * The Kubernetes API server
    * Central management point that exposes the Kubernetes API
    * All cluster communications (CLI, web dashboard, other components) go through this server
    * Validates and processes requests to modify cluster state

* kube-controller-manager
    * Runs controller processes (logical control loops)
    * Watches the current cluster state and works to reach the desired state
    * Includes Node Controller, Replication Controller, Endpoints Controller, etc.
    * Handles tasks like node failure response and maintaining correct pod counts

* kube-scheduler
    * Watches for newly created pods with no assigned node
    * Assigns pods to nodes based on constraints and available resources
    * Considers hardware/software/policy constraints, data locality, etc.

### Node Components

* kubelet
    * Agent that runs on each node
    * Ensures containers are running in a Pod
    * Takes PodSpecs and ensures containers described in those specs are running and healthy

* kube-proxy
    * Network proxy on each node
    * Maintains network rules for pod-to-service communication
    * Implements part of the Kubernetes Service concept
    * Performs connection forwarding or network address translation

### Storage and Networking Components

* dqlite
    * Distributed SQLite database
    * Used in some Kubernetes distributions (like MicroK8s) for storing cluster state
    * Lightweight alternative to etcd in smaller deployments
    * Provides distributed consensus and persistent storage

* Calico VXLAN interface
    * Part of Calico CNI networking solution
    * VXLAN (Virtual Extensible LAN) encapsulates Layer 2 frames within UDP packets
    * Creates an overlay network for pod communication across nodes
    * Typically appears as interfaces like "vxlan.calico" on nodes
    * Enables pod-to-pod communication across different hosts/subnets

## Networking
In the above, the components for K8S processes are separate processes that run in the physical nodes that forms a part of the K8S cluster. K8S uses a *CNI* to manage networking for the pods. The networking configurations and behaviour of the Kubernetes processes themselves (e.g kube-scheduler, kubelet) is *not influenced* by the management of the CNI. However, when running pods and containers in them, they work with the CNI to manage networking connections for the pods.

For concepts of networking from within the cluster that is influenced by the CNI, see [the networking document](concepts_networking.md).
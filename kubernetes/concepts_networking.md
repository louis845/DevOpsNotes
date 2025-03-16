# Networking

This assumes knowledge about [the networking part in the basic concepts](concepts.md#network). The routing rules for pods and services and how it works is influenced by the CNI. Here we discuss some more details of virtual subnets, how they are assigned to pods, services, and how the CNI (Calico/VXLAN) settings affect that.

## ClusterIP subnet
The Service ClusterIP subnet is managed by Kubernetes itself (by kube-proxy). Typically no virtual network interfaces will be on any nodes, and therefore it is typically not possible to ping the IP addresses of the ClusterIP services using the `ping` command on any of the nodes that forms the K8S cluster.

The ClusterIP addresses are fixed by the configuration of the Kubernetes cluster, so it provides a "stable way" of identifying the IPs of different services from within the K8S cluster. The ClusterIPs are reachable from within any pod/container of the K8S cluster, regardless of the namespace.

For accessing ClusterIP services within pods using a domain name, K8S assigns the following domain:
```
<service-name>.<namespace>.svc.cluster.local
```

Each ClusterIP service has a list of ports of the form `(port, targetPort)`, where the `port` is the port for the ClusterIP itself (the port for other containers to connect to if it wants to reach the service), and the `targetPort` is the port within the pod that runs the service itself.

The ClusterIP subnet is different from the K8S pod/container IP subnet.

## NodePort
The NodePort is also managed by K8S itself by kube-proxy. The `nodePortAddresses` for kube-proxy dictate where the K8S node ports will bind to. This means, when a node port is created, which causes all physical nodes to listen to a specific port, they will only bind to one of the permitted addresses in the nodePortAddresses setting for kube-proxy for that port.

For example, adding the argument `--nodeport-addresses=192.168.1.0/24` to the `/var/snap/microk8s/current/args/kube-proxy` file for microk8s clusters will bind all NodePort(s) only to the 192.168.1.0/24 subnet of the host nodes ([reference from Canonical](https://microk8s.io/docs/configure-host-interfaces#nodeport-services)).

Each NodePort service has a list of ports of the form `(port, targetPort, nodePort)`, where the `nodePort` is the port that causes all physical nodes to listen to, and the others are the ones inherited from ClusterIP.

## Calico/VXLAN CNI
The K8S pod IP subnet is managed by the CNI. This subnet is different from the subnet used for ClusterIP. This indeed creates virtual network interfaces on the nodes that run the pods. All pods can access different pods through the pod IP. The pod IP is randomly assigned to pods during their initialization, so ClusterIP is preferred for services. For connections initiated from within the pods/container, Calico by default translates using SNAT whenever the destination IP is an IP address outside Calico's IP pools [official reference here](https://docs.tigera.io/calico/latest/networking/configuring/workloads-outside-cluster). This means that not only public IPs can be reached, physical devices in the node's physical subnets can also probably be reached.

### Internal cluster routing on which physical subnet

To configure on which physical subnet (by CIDR) Calico VXLAN uses for routing the IP packets, one can copy and edit `/var/snap/microk8s/current/args/cni-network/cni.yaml` to adjust the `- name: IP_AUTODETECTION_METHOD` parameter, and apply `microk8s kubectl apply -f /var/snap/microk8s/current/args/cni-network/cni.yaml` to make VXLAN route packets over the specified physical subnet. For reference, see [Canonical's microk8s instructions](https://microk8s.io/docs/configure-host-interfaces#calico-vxlan-interface) and [Calico's autodetection methods](https://docs.tigera.io/calico/latest/networking/ipam/ip-autodetection#disable-autodetection). When configured successfully, one can check the `ipv4Address` ([reference in Calico](https://docs.tigera.io/calico/latest/reference/resources/node)).

### Block off pod/container access to physical devices on host
According to [Calico's document](https://docs.tigera.io/calico/latest/networking/configuring/workloads-outside-cluster#use-additional-ip-pools-to-specify-addresses-that-can-be-reached-without-nat), it is possible to disable NAT to specific CIDR ranges by creating custom disabled IP pools with that CIDR, so that Calico doesn't apply NAT to those destinations as its one of the registed IP pools, but no pods are assigned that IP since its disabled. For example, disallowing NAT for `192.168.1.*` will be
```yaml
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: no-nat-192.168.1.0-8
spec:
  cidr: 192.168.1.0/8
  disabled: true
```
and applying `kubectl apply -f <file>.yaml` to it.

### Choosing external NAT gateway
For physical nodes with attached to multiple physical subnets (with multiple physical NICs), not all physical subnets have a gateway to the public internet. It is better to specify the gateway address for SNAT. The Felix configuration contains a `natOutgoingAddress` field that can specify the gateway address of the nodes ([reference here](https://docs.tigera.io/calico/latest/reference/resources/felixconfig#data-plane-common) or [here](https://docs.tigera.io/calico/latest/reference/felix/configuration#data-plane-common)). 

Note that the FelixConfiguration is registered as a K8S resource type (although it is a config). To set the outgoing addresses explicitly, one can use
```
apiVersion: projectcalico.org/v3
kind: FelixConfiguration
metadata:
  name: node.<node name> # see https://docs.tigera.io/calico/latest/reference/felix/configuration
spec:
  NATOutgoingAddress: 192.168.1.100 # the address for that node
```

The problem is that the IP address assigned to each node will be different, so this has to be set for every node. Alternatively, the default configuration works as long as the Netplan configuration already specifies a gateway (and corresponding MAC address of the physical NIC with the outgoing connections), since IP tables MASQUERADE automatically selects the IP address of the subnet with a gateway.
## Network Policy

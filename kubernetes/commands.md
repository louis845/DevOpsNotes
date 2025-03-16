# Command list

 * `kubectl config` - Manages Kubernetes configuration details. This command primarily affects client-side settings, such as the Kubernetes API endpoints, user credentials, and namespaces. It does not affect the state of the actual Kubernetes cluster on the server side. Here are some of its common uses:
   * `kubectl config view` - Displays the current configuration settings.
   * `kubectl config use-context` - Switches between pre-configured contexts (clusters, users, namespaces).
   * `kubectl config set-context` - Modifies kubeconfig files, setting or changing current context elements like user, namespace, etc.
 * `kubectl get` - Retrieves and displays one or more resources. This command can be used to list various types of resources (pods, services, deployments, etc.) or a specific resource. It can also show additional information when used with different flags:
   * `kubectl get pods` - Lists all pods in the current namespace.
   * `kubectl get deployment my-dep -o yaml` - Shows the detailed configuration of the specified deployment in YAML format.
 * `kubectl describe` - Provides a detailed description of a specific resource or group of resources, including configuration details and recent events. This is useful for debugging and understanding the state and settings of cluster components:
   * `kubectl describe nodes` - Shows detailed information about each node.
   * `kubectl describe pods/my-pod` - Shows detailed information about a specific pod.
 * `kubectl apply` - Applies a configuration change to the cluster from a file or stdin. This command creates or updates resources in a cluster through declarative resource configuration files. It's a key component of infrastructure as code practices in Kubernetes environments:
   * `kubectl apply -f my-config.yaml` - Applies or updates resources defined in `my-config.yaml`.
   * `kubectl apply -k ./my-dir` - Applies all configurations found in the specified directory using kustomize to manage resource configurations.

# Common flags
* `-n`, `--namespace` - Specifies the namespace to use for the current `kubectl` command. If not provided, the command will default to the namespace set in the kubeconfig or "default" if not set. Example:
  * `kubectl get pods -n my-namespace` - Lists all pods in the "my-namespace" namespace.

* `--all-namespaces`, `-A` - Includes resources from all namespaces. This is useful when you want to query cluster-wide resources rather than those in a specific namespace. Example:
  * `kubectl get pods --all-namespaces` - Lists all pods across all namespaces.

* `-c`, `--container` - Specifies a container name when multiple containers are present in a pod. This is often used with commands like `kubectl logs` or `kubectl exec` to interact with a specific container. Example:
  * `kubectl logs my-pod -c my-container` - Fetch the logs from "my-container" in "my-pod".

* `-f`, `--filename` - Specifies the filename, directory, or URL containing the configuration to apply. This flag is used to point to files that contain Kubernetes resource definitions. Example:
  * `kubectl apply -f ./my-resource.yaml` - Applies the configuration in "my-resource.yaml".

* `--kubeconfig` - Points to a kubeconfig file. This can be used to specify a kubeconfig file other than the default `~/.kube/config`. Example:
  * `kubectl get pods --kubeconfig=/path/to/kubeconfig`

* `-o`, `--output` - Formats the output using the specified format. Common values include `json`, `yaml`, `wide`, `name`, and `custom-columns`. Example:
  * `kubectl get pods -o wide` - Lists all pods with additional columns like node name and IP addresses.

* `--dry-run` - Simulates a command without making any actual changes. Useful for validating resource definitions or command syntax. Example:
  * `kubectl apply -f deploy.yaml --dry-run=client` - Simulates applying the deployment without actually creating resources.

* `--selector`, `-l` - Selects resources based on label queries. This can filter objects according to specified labels. Example:
  * `kubectl get pods -l app=myapp` - Lists pods that have a label "app" with the value "myapp".

* `--watch`, `-w` - Watches for changes to the specified resources and prints them to stdout. Example:
  * `kubectl get pods --watch` - Continuously watches for changes in all pods and updates the display as changes occur.

* `--record` - Records the command issued in the resource annotation `kubernetes.io/change-cause`. This can be helpful for keeping a history of what commands were executed. Example:
  * `kubectl apply -f deploy.yaml --record` - Applies the deployment and records the command used in the deployment's annotations.

# Common commands
Here are the commonly used commands. Note that some of these commands are to be used with the setup specified by [this document](setup.md).

```sh
# kubernetes dashboard
kubectl create token dashboard-admin -n kube-system
kubectl port-forward -n kube-system service/kubernetes-dashboard 8080:443

# rook ceph dashboard
kubectl -n rook-ceph get secret rook-ceph-dashboard-password -o jsonpath="{['data']['password']}" | base64 --decode
kubectl port-forward -n rook-ceph services/rook-ceph-mgr-dashboard 8000:8443

# NGINX controller
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80 8443:443

# gitlab initial password
kubectl get -n gitlab secret/gitlab-gitlab-initial-root-password -o jsonpath='{.data.password}' | base64 --decode
```

# Debugging commands
Here are some commands for debugging by spinning up custom temporary pods, or starting a process within a container in a pod.
```sh
kubectl run busybox-test --rm -it --image=busybox -- /bin/sh # runs busybox in a temporary pod
kubectl run busybox-test --rm -it --image=busybox --overrides='{"spec":{"nodeName":"<specific node name>"}}' -- /bin/sh # specify node name

kubectl exec -it pod-name -- /bin/sh # starts an interactive shell in an existing pod
# write -c <container name> for exec to specify which container to connect to
```

The `kubectl exec` command allows you to execute commands directly inside a running container. The `-it` flags make it interactive, so you get a shell prompt where you can run multiple commands like ping, netstat, or other networking tools.
# Running interactive development with GPUs using VSCode remote

It is useful to have an interactive development environment using VSCode SSH remote extension into a K8S cluster to quickly test out Python programs (due to the non-strict checking nature of Python), to weed out syntax or argument errors and so on. 

This iteration method allows to skip the tedious methods of running Docker building pipelines and so on to test Python function to see if it works as a first step. 

**WARNING:** Files in K8S pods are temporary, they will be deleted whenever the pod is deleted! ALWAYS treat the VSCode remote workspace as a temporary, and download the changes to a local place whenever the changes are to be saved.

## Dockerfile
For the docker file, apart from setting up an environment for Jupyter notebook, we also setup an OpenSSH server that is to be run inside the container.

Expected files:
   * `images/sshd_config` - The configuration for SSH access into the container
     * Should allow TCP forwarding as VSCode remote access extension requires it
   * `images/interactive.sh` - The code that is to be run when the container starts
     * Necessary since both jupyter notebook and the SSH server is to be run in the background.

```Dockerfile
FROM nvidia/cuda:12.4.1-base-ubuntu22.04

# install python3 and pip3
RUN apt-get update && apt-get install -y python3-pip python3-dev && \
    ln -s /usr/bin/python3 /usr/bin/python && apt-get clean && rm -rf /var/lib/apt/lists/*

# install relevant Python packages
RUN pip install --no-cache-dir numpy==2.2.4
RUN pip install --no-cache-dir torch==2.6.0
RUN pip install --no-cache-dir pandas==2.2.3
RUN pip install --no-cache-dir build

# setup jupyter notebook
RUN pip install --no-cache-dir jupyter_server
RUN pip install --no-cache-dir ipykernel

# create a non-root user
RUN groupadd -r jupyter && useradd -r -g jupyter jupyter

# set work dir and let jupyter notebook access that
WORKDIR /app
RUN chown jupyter:jupyter /app

# set home directory and switch to it
ENV HOME=/home/jupyter
RUN mkdir -p $HOME && chown -R jupyter:jupyter $HOME

# install ssh server and set up ssh with password for the jupyter account, and enable sftp for the jupyter account
RUN apt-get update && apt-get install -y openssh-server
RUN rm /etc/ssh/sshd_config
# use the configured sshd_config with internal-sftp
COPY /images/sshd_config /etc/ssh/sshd_config
RUN mkdir /run/sshd

RUN mkdir /scripts
COPY images/interactive.sh /scripts/interactive.sh
RUN chmod +x /scripts
RUN chmod +x /scripts/interactive.sh

# switch to jupyter user
RUN mkdir -p $HOME/.jupyter
RUN mkdir -p $HOME/.ssh
RUN chown -R jupyter:jupyter $HOME/.jupyter

CMD ["sh", "-c", "/scripts/interactive.sh"]
```

## Running script

This script setups the `jupyter` account inside the container by activating the account for logins, so it could be accessed by SSH. Also the host keys and access keys are stored as a Kubernetes secret, which allows developers to generate the temporary access keys via `ssh-keygen`.

```sh
#!/bin/sh

# use openssl to generate a random password for jupyter account
JUPYTER_PASSWORD=$(openssl rand -base64 64 | base64 -d | od -t x1 -An -v | tr -d ' \n')
echo "jupyter:${JUPYTER_PASSWORD}" | chpasswd # set the password for the jupyter account
passwd -u jupyter

# copy the host key and the authorized keys from the K8S secret mount into the right place
rm /etc/ssh/ssh_host_ed25519_key
rm /etc/ssh/ssh_host_ed25519_key.pub
cp /k8s_secret/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key
cp /k8s_secret/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ed25519_key.pub
cp /k8s_secret/authorized_keys /home/jupyter/.ssh/authorized_keys

# setup permission for the host key
chmod 600 /etc/ssh/ssh_host_ed25519_key
chown root:root /etc/ssh/ssh_host_ed25519_key
chmod 644 /etc/ssh/ssh_host_ed25519_key.pub
chown root:root /etc/ssh/ssh_host_ed25519_key.pub

# setup permission for the ssh folder
chmod -R 640 /home/jupyter/.ssh
chown -R jupyter:jupyter /home/jupyter/.ssh/
chmod 700 /home/jupyter/.ssh
chmod 600 /home/jupyter/.ssh/authorized_keys

# run commands in the background
/usr/sbin/sshd &
su jupyter -c "jupyter server --ip=0.0.0.0 --ServerApp.token=${JUPYTER_TOKEN}" &
wait
```

## Kubernetes YAML
The following YAML file deploys the temporary interactive development environment in a namespace, where the namespace can be specified, and the token to access the Jupyter server can be changed.

 * <temporary notebook> - The namespace for the interactive development environment
 * <your token> - The token for accessing the Jupyter server. The access URL will be `<IP>/?token=<token>`.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notebook
  namespace: <temporary notebook>
  labels:
    app: notebook
spec:
  replicas: 1
  selector:
    matchLabels:
      app: notebook
  template:
    metadata:
      labels:
        app: notebook
    spec:
      containers:
      - name: notebook
        image: 10.152.183.59/library/time-series-detector-interactive:latest
        ports:
        - containerPort: 8888
        - containerPort: 22
        env:
        - name: JUPYTER_TOKEN
          value: "<your token>"
        volumeMounts:
        - name: secret-keys
          mountPath: /k8s_secret
      volumes:
      - name: secret-keys
        secret:
          secretName: secret-keys
---
apiVersion: v1
kind: Service
metadata:
  name: notebook
  namespace: <temporary notebook>
  labels:
    app: notebook
spec:
  type: ClusterIP
  selector:
    app: notebook
  ports:
  - port: 8888
    targetPort: 8888
    name: jupyter
  - port: 22
    targetPort: 22
    name: ssh
```

## sshd_config
Here is a configuration that disallows root login, and only allows access using public key authentication (password login disabled).

```cfg
Include /etc/ssh/sshd_config.d/*.conf

Port 22
HostKey /etc/ssh/ssh_host_ed25519_key
SyslogFacility AUTH
LogLevel INFO
LoginGraceTime 1m
PermitRootLogin no
StrictModes yes
MaxAuthTries 6
MaxSessions 2
PubkeyAuthentication yes
AuthorizedKeysFile	.ssh/authorized_keys
AuthorizedPrincipalsFile none
AuthorizedKeysCommand none
AuthorizedKeysCommandUser nobody
HostbasedAuthentication no
PasswordAuthentication no
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
KerberosAuthentication no
GSSAPIAuthentication no
UsePAM no
AllowAgentForwarding no
AllowTcpForwarding yes # permit TCP forwarding to allow VSCode SSH
X11Forwarding no
PermitTTY yes # permit TTY to allow VSCode SSH
PrintMotd no
PrintLastLog no
TCPKeepAlive yes
PermitUserEnvironment no
UseDNS no
PermitTunnel no
AcceptEnv LANG LC_*
```

## Key generation commands
The following key generation commands can be used to generate the keys and SSH into the server.

```sh
#!/bin/bash

# run locally in client, generates a new key pair for the host key and the access key
if [ ! -d generated_keys ]; then
    mkdir generated_keys
fi

ssh-keygen -t ed25519 -f generated_keys/ssh_host_ed25519_key -N ""
ssh-keygen -t rsa -f generated_keys/authorized_keys -N ""
kubectl delete secret secret-keys -n <namespace>
kubectl apply -f notebook_namespace.yml
kubectl create secret generic secret-keys --from-file=ssh_host_ed25519_key.pub=generated_keys/ssh_host_ed25519_key.pub --from-file=ssh_host_ed25519_key=generated_keys/ssh_host_ed25519_key --from-file=authorized_keys=generated_keys/authorized_keys.pub -n <namespace>
```
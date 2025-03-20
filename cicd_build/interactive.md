temp markdown for interactive notebooks

```Dockerfile
FROM python:latest

RUN pip install --no-cache-dir numpy
RUN pip install --no-cache-dir pandas
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
USER jupyter
RUN mkdir -p $HOME/.jupyter

CMD ["sh", "-c", "jupyter server --ip=0.0.0.0 --ServerApp.token=${JUPYTER_TOKEN}"]
```

# K8S pods

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: temp-pod
  labels:
    app: temp-pod
spec:
  containers:
  - name: temp-pod
    image: 10.152.183.59/library/data-processor_interactive
    ports:
    - containerPort: 8888
    env:
    - name: JUPYTER_TOKEN
      value: "your_token_here"
  restartPolicy: Never
---
apiVersion: v1
kind: Service
metadata:
  name: temp-service
spec:
  type: NodePort
  selector:
    app: temp-pod
  ports:
  - port: 31888
    targetPort: 8888
    nodePort: 31888
```
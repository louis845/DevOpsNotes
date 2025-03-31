Here are some commonly used base images:

# Pytorch

```Dockerfile
FROM nvidia/cuda:12.4.1-base-ubuntu22.04

# install python3 and pip3
RUN apt-get update && apt-get install -y python3-pip python3-dev && \
    ln -s /usr/bin/python3 /usr/bin/python && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir numpy==2.2.4
RUN pip install --no-cache-dir torch==2.6.0
```

# Python

```Dockerfile
FROM python:latest

RUN pip install --no-cache-dir numpy
RUN pip install --no-cache-dir fastapi[standard]
```

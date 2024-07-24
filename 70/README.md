# Deploy Kafka on Kubernetes

This tutorial walks through how to:

- Deploy a Kafka cluster within Kubernetes using Strimzi Kafka Operator
- Create a simple application that uses the deployed Kafka cluster
- Enable monitoring of usefull Kafka metrics with Prometheus and Grafana

## Deploy Kafka on Kubernetes (using Minikube)

1. Create a new Minikube cluster

    ``` bash
    $ minikube start -p kafka-cluster
    😄  [kafka-cluster] minikube v1.33.1 on Darwin 14.5 (arm64)
    ✨  Using the docker driver based on existing profile
    👍  Starting "kafka-cluster" primary control-plane node in "kafka-cluster" cluster
    🚜  Pulling base image v0.0.44 ...
    🔄  Restarting existing docker container for "kafka-cluster" ...
    🐳  Preparing Kubernetes v1.30.0 on Docker 26.1.1 ...
    🔎  Verifying Kubernetes components...
        ▪ Using image gcr.io/k8s-minikube/storage-provisioner:v5
    🌟  Enabled addons: default-storageclass, storage-provisioner
    🏄  Done! kubectl is now configured to use "kafka-cluster" cluster and "default" namespace by default
    ```

2. Apply terraform script to create the namespace and install Strimzi Kafka Operator

    ``` bash
    terraform apply --autor-approve
    ```

3. Apply kubernetes yamls to create kafka resources:

   ``` bash
   kubectl apply -f kafka 
   ```

## Configure Kuberneets audit logs for Minikube

To enable audit logs on a Minikube:

### 1. Configure Kube-apiserver

Using the official [kubernetes documentation](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/) as reference, we login into our minikube VM and configure the `kube-apiserver` as follow:

``` bash 
$ minikube -p kafka-cluster ssh
# we create a backup copy of the kube-apiserver manifest file in case we mess things up 😄
docker@minikube:~$ sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml .
# edit the file to add audit logs configurations
docker@minikube:~$ sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

We need to instruct the `kube-apiserver` to start using an `audit-policy` that
will define what logs we want to capture, then where to which file we want to send them.
This is done by adding these two lines bellow the kube-apiserver command:

``` bash
  - command:
    - kube-apiserver
    # add the following two lines
    - --audit-policy-file=/etc/kubernetes/audit-policy.yaml
    - --audit-log-path=/var/log/kubernetes/audit/audit.log
    # end 
    - --advertise-address=192.168.49.2
    - --allow-privileged=true
    - --authorization-mode=Node,RBAC
```

With both files, we need need to configure the `volumes` and `volumeMount` into the
`kube-apiserver` container. Scroll down into the same file and add these lines:

``` bash
...
volumeMounts:
  - mountPath: /etc/kubernetes/audit-policy.yaml
    name: audit
    readOnly: true
  - mountPath: /var/log/kubernetes/audit/
    name: audit-log
    readOnly: false
```

And then:

``` bash
...
volumes:
- name: audit
  hostPath:
    path: /etc/kubernetes/audit-policy.yaml
    type: File

- name: audit-log
  hostPath:
    path: /var/log/kubernetes/audit/
    type: DirectoryOrCreate
```

Be carefull with the number of spaces you add before each line, this can prevent
the `kube-apiserver` from starting.

However, at this point, even if you are super carefull, it wont start... 😈

### 2. Create the audit-policy

This is because, we need to create the audit-policy file at the location we gave to the `kube-apiserver`.
To keep things simple, we will use the audit-policy provided by the kubernetes documentation.

``` bash
docker@minikube:~$ cd /etc/kubernetes/
docker@minikube:~$ sudo curl -sLO https://raw.githubusercontent.com/kubernetes/website/main/content/en/examples/audit/audit-policy.yaml
```

Now, everything should be Ok for the `kuber-apiserver` pod to come back to a running state.

``` bash
docker@minikube:~$ exit
$ kubectl get po -n kube-system
NAME                               READY   STATUS    RESTARTS   AGE
coredns-5dd5756b68-mbtm8           1/1     Running   0          1h
etcd-minikube                      1/1     Running   0          1h
kube-apiserver-minikube            1/1     Running   0          13s
kube-controller-manager-minikube   1/1     Running   0          1h
kube-proxy-jcn6v                   1/1     Running   0          1h
kube-scheduler-minikube            1/1     Running   0          1h
storage-provisioner                1/1     Running   0          1h 
```

### 3. Check audit logs are generated

Now, we can log back to the Minikube VM to check that our audit logs are
correctly generated in the provided audit.log file.

``` bash
$ minikube ssh
docker@minikube:~$ sudo cat /var/log/kubernetes/audit/audit.log
...
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Metadata", ...
"authorization.k8s.io/reason":"RBAC:
allowed by ClusterRoleBinding \"system:public-info-viewer\" of ClusterRole
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Request", ...
...
```

Yes, we have our logs. 🥳

## Configure Kafka to produce event-streams from the audit logs

## Deploy Prometheus and Grafana

## Monitoring a Kafka cluster with Prometheus and Grafana

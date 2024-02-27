# Monitoring K8s audit logs with Loki, Grafana & Prometheus

In this tutorial, we will monitor Kubernetes audit logs using the Grafana, Loki, Promtail and Prometheus stack.
The goal is to quickly bootstrap a security-monitored Kubernetes cluster using Kubernetes vanilla audit capability.
Our setup is described in the figure bellew:

## Configure Kubernetes Audit Policy

We start by creating a new Kubernetes cluster using Minikube so that you can redo this tutorial and test the setup before trying it on a cloud deployed cluster.

``` bash
$ minikube start
😄  minikube v1.32.0 on Darwin 14.2.1 (arm64)
✨  Using the docker driver based on existing profile
👍  Starting control plane node minikube in cluster minikube
🚜  Pulling base image ...
🐳  Preparing Kubernetes v1.28.3 on Docker 24.0.7 ...
🔗  Configuring bridge CNI (Container Networking Interface) ...
🔎  Verifying Kubernetes components...
    ▪ Using image gcr.io/k8s-minikube/storage-provisioner:v5
🌟  Enabled addons: storage-provisioner, default-storageclass
🏄  Done! kubectl is now configured to use "minikube" cluster and "default" namespace by default
```

Once the cluster started, we login into it using `minikube ssh` so that we can configure the `kube-apiserver` with an `audit-policy` and how audit logs should be stored.

To enable audit logs on a Minikube:

### 1. Configure Kube-apiserver

Using the official [kubernetes documentation](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/) as reference, we login into our minikube VM and configure the `kube-apiserver` as follow:

``` bash 
$ minikube ssh
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

## Deploying the monitoring stack

Now we need to setup the monitoring stack and push these logs to Grafana.

The stack we will be using consists of Grafana, Loki and Promtail.
First, we will use promtail to push logs from within our cluster node to loki.
Loki will aggregate these logs and store them for further analysis or audit needs.
Last Grafana will visualize these logs during assessments, investigations and
potentially create alerts on some usecases.

### Power-up with Infrastructure as Code

Since I already published and article on how to setup a similar monitoring stack, you can refer to my previous article for more details.
For now, just create this terraform file and run `terraform apply` in the same
folder to do the trick:

``` terraform 
# Initialize terraform providers
provider "kubernetes" {
  config_path = "~/.kube/config"
}
provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}
# Create a namespace for observability
resource "kubernetes_namespace" "observability-namespace" {
  metadata {
    name = "observability"
  }
}
# Helm chart for Grafana
resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = "7.1.0"
  namespace  = "observability"

  values     = [file("${path.module}/values/grafana.yaml")]
  depends_on = [kubernetes_namespace.observability-namespace]
}
# Helm chart for Loki
resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = "5.41.5"
  namespace  = "observability"

  values     = [file("${path.module}/values/loki.yaml")]
  depends_on = [kubernetes_namespace.observability-namespace]
}
# Helm chart for promtail
resource "helm_release" "promtail" {
  name       = "promtail"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  version    = "6.15.3"
  namespace  = "observability"

  values     = [file("${path.module}/values/promtail.yaml")]
  depends_on = [kubernetes_namespace.observability-namespace]
}
```

For this script to run properly, you need to create a `values` folder along with
the `terraform` file.

This folder will hold all our configuration for the stack to get the audit logs into Grafana.

Here is the content for each file:

``` yaml title="values/grafana.yaml"
persistence.enabled: true
persistence.size: 10Gi
persistence.existingClaim: grafana-pvc
persistence.accessModes[0]: ReadWriteOnce
persistence.storageClassName: standard
  
adminUser: admin
adminPassword: grafana

datasources: 
 datasources.yaml:
   apiVersion: 1
   datasources:
    - name: Loki
      type: loki
      access: proxy
      orgId: 1
      url: http://loki-gateway.observability.svc.cluster.local
      basicAuth: false
      isDefault: true
      version: 1
```

``` yaml title="values/loki.yaml"
loki:
  auth_enabled: false
  commonConfig:
    replication_factor: 1
  storage:
    type: 'filesystem'
singleBinary:
  replicas: 1
```

``` yaml title="values/promtail.yaml"
# Add Loki as a client to Promtail
config:
  clients:
    - url: http://loki-gateway.observability.svc.cluster.local/loki/api/v1/push


# Scraping kubernetes audit logs located in /var/log/kubernetes/audit/
  snippets:
    scrapeConfigs: |
      - job_name: audit-logs
        static_configs:
          - targets:
              - localhost
            labels:
              job: audit-logs
              __path__: /var/log/host/kubernetes/**/*.log
```

Now, everything is setup for our monitoring stack to be able to ingest audit
logs from our kubernetes node.

We can log into our Grafana using the credentials configured in the value file above.

We head to the **Explore** tab and check our audit logs.

🌟🌟🌟 Found this useful, consider leaving a start 🌟 on the project, it encourages me to produce more content like this 💖.

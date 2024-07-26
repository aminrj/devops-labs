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

## Setup Metrics for our Kafka Cluster

Collecting metrics is critical for understanding the health and performance of our Kafka cluster.
This is important to identify issues before they become critical and make informed decisions about resource allocation and capacity planning.
Furthermore, without clear visibility into the behavior of our Kafka deployment, troubleshooting becomes more difficult and time-consuming.

For this, we will use Prometheus and Grafana to monitor Strimzi.
Prometheus consumes metrics from the running pods in your cluster when configured with Prometheus rules.
Grafana visualizes these metrics on dashboards, providing better interface for
monitoring.

### Setting-up Prometheus

To deploy the Prometheus Operator to our Kafka cluster, we apply the YAML bundle resources file from the Prometheus CoreOS repository:

``` bash
  curl -s https://raw.githubusercontent.com/coreos/prometheus-operator/master/bundle.yaml > prometheus-operator-deployment.yaml
```

Then we update the namespace with our `observability` namespace:

``` bash
sed -i '' -e '/[[:space:]]*namespace: [a-zA-Z0-9-]*$/s/namespace:[[:space:]]*[a-zA-Z0-9-]*$/namespace: observability/' prometheus-operator-deployment.yaml
```

Note: For Linux, use:

``` bash
sed -E -i '/[[:space:]]*namespace: [a-zA-Z0-9-]*$/s/namespace:[[:space:]]*[a-zA-Z0-9-]*$/namespace: observability/' prometheus-operator-deployment.yaml
```

Then, deploy the Prometheus Operator:

```bash
kubectl -n observability create -f prometheus-operator-deployment.yaml
```

Now that we have the operator up and running, we need to create the Prometheus server and configure it to watch for Strimzi CRDs in the `kafka` namespace.
Note here that the name of the namespace must match otherwise Prometheus Operator won't scrap any resources we deploy.

```bash
kubectl -n observability apply -f strimzi-pod-monitor.yaml
kubectl -n observability apply -f prometheus.yaml
```

### Configuring our Kafka cluster to expose metrics

To enable and expose metrics in Strimzi for Prometheus, we use metrics configuration properties using the `metricsConfig` configuration property or our Kafka cluster.

```yaml
    metricsConfig:
      type: jmxPrometheusExporter
      valueFrom:
        configMapKeyRef:
          name: kafka-metrics
          key: kafka-metrics-config.yml
```

Once configured, we apply the new config which will restart our cluster with the updated configuration:

```bash
kubectl apply -f kafka-metrics.yaml
```

For more details on how monitor Strimzi Kafka using Prometheus and Grafana, check the [Strimzi documentation](https://strimzi.io/docs/operators/latest/deploying#proc-metrics-kafka-deploy-options-str).

### Deploy and Configure Grafana

First we need to install Grafana using the `grafana.yaml` file then configure the our Prometheus as data source.

```bash
kubectl -n observability apply -f grafana-install/grafana.yaml
```

Once deployed, we can access the UI using port-forward, or directly using our Minikube:

```bash
$ minikube -p kafka service grafana -n observability
😿  service observability/grafana has no node port
❗  Services [observability/grafana] have type "ClusterIP" not meant to be exposed, however for local development minikube allows you to access this !
🏃  Starting tunnel for service grafana.
|---------------|---------|-------------|------------------------|
|   NAMESPACE   |  NAME   | TARGET PORT |          URL           |
|---------------|---------|-------------|------------------------|
| observability | grafana |             | http://127.0.0.1:61909 |
|---------------|---------|-------------|------------------------|
🎉  Opening service observability/grafana in default browser...
❗  Because you are using a Docker driver on darwin, the terminal needs to be open to run it.
```

This will open the browser to the login page of Grafana.
The default login/password are : admin/admin.

We head to the Configuration > Data Sources tab and add Prometheus as a data source.
In the URL field we put the address of our prometheus service : `http://prometheus-operated:9090`
After `Save & Test` we should have a green banner indicating that our Prometheus source is up and running.

Now is time to add a dashboard in order to visualize our Kafka metrics.
In the Dashboard tab, we click on `Import` and point to our `strimzi-kafka.json` file.
Once imported, the dashboard should look something similar to the following figure:

_TODO: add Grafana dashboard screenshot here_


## Generating some Kafka events

At this time, since there is no traffic going on in our Kafka cluster, some panels migh show `No Data`. To resove this, we will generate some events using Kafka performance tests.

First, we create our first topic thanks to our Kafka Operator which is watching for any Kafka CRDs.

```bash
kubectl apply -f kafka/kafka-topic.yaml
```

This will create our first topic `my-topic` so we can generate some events.

Head to the terminal and past the following command:

```bash
$kubectl -n kafka exec -i my-cluster-kafka-0 -c kafka -- \
    bin/kafka-producer-perf-test.sh --topic my-topic --num-records 1000000 --record-size 100 --throughput 100 --producer-props bootstrap.servers=my-cluster-kafka-bootstrap:9092 --print-metrics
501 records sent, 100.2 records/sec (0.01 MB/sec), 8.3 ms avg latency, 301.0 ms max latency.
501 records sent, 100.1 records/sec (0.01 MB/sec), 1.4 ms avg latency, 8.0 ms max latency.
500 records sent, 99.9 records/sec (0.01 MB/sec), 1.8 ms avg latency, 35.0 ms max latency.
501 records sent, 100.0 records/sec (0.01 MB/sec), 1.8 ms avg latency, 39.0 ms max latency.
500 records sent, 100.0 records/sec (0.01 MB/sec), 1.6 ms avg latency, 8.0 ms max latency.
...
```

Then, we run the consumer with:

```bash
$kubectl -n kafka exec -i my-cluster-kafka-0 -c kafka -- \
    bin/kafka-consumer-perf-test.sh --bootstrap-server my-cluster-kafka-bootstrap:9092 --topic my-topic --from-latest --messages 100000000 --print-metrics --show-detailed-stats
```

This will generate some traffic that we can observe on our Grafana dashboards.

<!-- ## Configure Kubernetes audit logs for Minikube

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

 -->

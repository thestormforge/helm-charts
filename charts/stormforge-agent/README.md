<!-- Add useful information to your short description that explains what the product is, why a user wants to install and use it, and any additional details the user needs to get started. The following information is an example. Make sure you update this section accordingly. -->

StormForge Optimize Live delivers continuous, autonomous rightsizing for Kubernetes workloads.

The StormForge Agent is a helm chart which combines the stormforge-agent that surfaces minimum Kubernetes resource (pods, hpa) metrics and a prometheus agent to forward these metrics to StormForge Optimize Live's SaaS backend.

## Before you begin

<!-- List any prereqs including required permissions, capacity requirements, etc. The following information is an example. Make sure you update this section accordingly. -->

* Sign up for a StormForge Optimize Live account by visiting https://app.stormforge.io
* Download the StormForge CLI by following the instructions here: https://docs.stormforge.io/optimize-live/getting-started/install-v2/#install-the-stormforge-cli-tool
* Create the access credential that will contain the input variables required to successfully authenticate and deploy the StormForge Agent: https://docs.stormforge.io/optimize-live/getting-started/install-v2/#generate-an-access-credential


## Required resources

<!-- The following information is an example. Make sure you update this section accordingly. -->

To run the software, the following resources are required:

  * A Kubernetes cluster > v1.16
  * The StormForge CLI: https://docs.stormforge.io/optimize-live/getting-started/install-v2/#install-the-stormforge-cli-tool 
  * A valid StormForge Optimize Live license: https://app.stormforge.io 

## Installing the software

<!-- It is recommended to not include the large table of configuration parameters that are listed on the Create page. -->
Generating the credentials:

```
stormforge auth create AUTH_NAME
```

It will generate the following file. Save the file locally, i.e. as `AUTH_NAME-credentials.yaml`:

```
stormforge:
  address: https://api.stormforge.io/
authorization:
  issuer: https://api.stormforge.io/
  clientID: <CLIENT_ID> # AUTH_NAME
  clientSecret: <CLIENT_SECRET>
```

Running the installation (replace `LATEST_VERSION` and `CLUSTER_NAME` in example with appropriate values)

```
helm install stormforge-agent oci://registry.stormforge.io/library/stormforge-agent \
  --version LATEST_VERSION \
  --namespace stormforge-system \
  --create-namespace \
  --values AUTH_NAME-credentials.yaml \
  --set stormforge.clusterName=CLUSTER_NAME
```

### Parameters

<!-- Add additional H3 level headings as needed for sections that apply to IBM Cloud such as network policy, persistence, cluster topologies, etc.
### H3
### H3
-->
| Parameter             | Description                                                          | Default                        |
|-----------------------|----------------------------------------------------------------------|--------------------------------|
| `stormforge.address`  | API endpoint for StormForge Optimize Live Saas                       | `https://api.stormforge.io`    |
| `authorization.issuer`| Authorization Issuer                                                 | `https://api.stormforge.io`    |
| `authorization.clientID`            | client.ID string from credential YAML. Visit docs.stormforge.io for details | `[]`      |
| `authorization.clientSecret`        | client.Secret string from credential YAML. Visit docs.stormforge.io for details | `[]`  |
| `workload.allowNamespaces` | List specific namespaces for Optimize Live's recommendations. Default behavior is all namespaces expect "kube-system" | `[]`|
| `workload.denyNamespaces` | List specific namespaces to exclude from Optimize Live's recommendations. Note: `workload.allowNamespaces` and `workload.denyNamespaces` are mutuall exclusive with `workload.Allownamespaces` taking precendence. | `[]`|
| `stormforge.clusterName`| String used to define Cluster Name in the StormForge SaaS UI         | `[]`|

## Upgrading to a new version

<!-- Information about how a user can upgrade to a new version when it's available. The following information is an example. Make sure you update this section accordingly. -->

A typical upgrade might look something like the following.

```
helm upgrade stormforge-agent oci://registry.stormforge.io/library/stormforge-agent \
  --version LATEST_VERSION \
  --namespace stormforge-system \
  --reuse-values
```
## Uninstalling the software

<!-- Information about how a user can uninstall this product. The following information is an example. Make sure you update this section accordingly. -->

Complete the following steps to uninstall a Helm Chart from your account. 

```
helm uninstall RELEASE_NAME [...] [flags]
```
## Workload Metrics

Here are the workload metrics produced by StormForge Agent

| Metric                                           | Source                              | Why                                                                           |
| ------------------------------------------------ | ----------------------------------- | ----------------------------------------------------------------------------- |
| sf_kube_pod_container_resource_requests             | KSM-like/pod-metrics                     | Track requests for each container                                             |
| sf_kube_pod_container_resource_limits               | KSM-like/pod-metrics                     | Track limits for each container                                               |
| sf_kube_replicaset_spec_replicas                    | KSM-like/replicaset-metrics              | Track replicas for replicasets                                                |
| sf_kube_statefulset_replicas                        | KSM-like/statefulset-metrics             | Track replicas for statefulsets                                               |
| sf_workload_pod_owner                        | Consolidated metric for ownership              | With this metric, we have pod owner and workload, replacing KSM kube_pod_owner and kube_replicaset_owner                                               |
| sf_workload_replicas                        | Consolidated metric for replicas number              | With this metric, we have all replica metrics regardless type of pod owner. Should eventually replace KSM-like  kube_replicaset_spec_replicas  and kube_statefulset_replicas                                             |
| sf_workload_spec_replicas                        | Consolidated metric for desired replicas number              | With this metric, we have all desired replica metrics regardless type of pod owner. Should eventually replace KSM-like  kube_replicaset_spec_replicas  and kube_statefulset_replicas                                             |
| sf_workload_status_replicas                        | Consolidated metric for observed replicas number              | With this metric, we have all observed replica metrics regardless type of pod owner. Should eventually replace KSM-like  kube_replicaset_status_replicas  and kube_statefulset_replicas                                             |
| sf_workload_pod_container_resource_requests    | Consolidated pod metric with  requests              | With this metric, we have all requests metrics in a single metric. Should eventually replace KSM-like  kube_pod_container_resource_requests                                        |
| sf_workload_pod_container_resource_limits    | Consolidated pod metric with  limits              | With this metric, we have all limits metrics in a single metric. Should eventually replace KSM-like  kube_pod_container_resource_limits                                        |
| container_cpu_usage_seconds_total                | cadvisor                            | Track cpu usage for each container                                            |
| container_memory_working_set_bytes               | cadvisor                            | Track memory usage for each container                                         |
| sf_horizontalpodautoscaler_spec_min_replicas   | KSM-like/horizontalpodautoscaler-metrics | Track minimum replicas for each HPA                                           |
| sf_horizontalpodautoscaler_spec_max_replicas   | KSM-like/horizontalpodautoscaler-metrics | Track maximum replicas for each HPA                                           |
| sf_horizontalpodautoscaler_spec_target_metric  | KSM-like/horizontalpodautoscaler-metrics | Track target metric for each HPA                                              |

Individual tenants could have additional metrics.

## Troubleshooting StormForge Agent

### Getting Logs from Prometheus Agent

In case one does not see data on AMP, check the prometheus agent logs. In this example below, the agent is running on namespace `stormforge-system`:

```sh
kubectl logs -l app.kubernetes.io/name=stormforge-agent --tail=-1 -n stormforge-system -c prom-agent
```

If there is no errors, see the next steps.

### Verify Prom Targets

When you install the agent, you should be sure to verify it is actually able to scrape the workload metrics. In particular, stormforge-agent  has a static url config which makes it config error prone, which is `https://<>:8080/metrics`. In this example below, the agent is running on namespace `stormforge-system`

```sh
# e.g.
kubectl expose deploy/stormforge-agent -n stormforge-system
kubectl port-forward deploy/stormforge-agent 9090:9090 -n stormforge-system
# http://localhost:9090/targets?search= to validate targets are being collected
```

To look at the actual metrics from the perspective of the stormforge-agent:

```sh
# e.g.
kubectl expose deploy/stormforge-agent -n stormforge-system
kubectl port-forward deploy/stormforge-agent 8080:8080 -n stormforge-system
# http://localhost:8080/metrics to validate targets are being collected
```

### Checking Prometheus WAL

Data should be on the WAL. In this example below, the agent is running on namespace `stormforge-system`:

```sh
# e.g.
kubectl exec $(kubectl get pods -n stormforge-system -l app.kubernetes.io/name=stormforge-agent | grep agent | awk '{print $1}') -n stormforge-system -it -c prom-agent -- sh

# inside the pod
$ promtool tsdb dump data-agent/ | head

# check sf workload metrics
$ promtool tsdb dump data-agent/ | grep sf_workload | head -5

# check horizontal metrics
$ promtool tsdb dump data-agent/ | grep horizontal | head -5

```

By default, we are holding 30 minutes on data on WAL.

### Credentials

Credentials are not authorized, ask permission:

```
# kubectl logs --tail=-1 -n stormforge-system -l app.kubernetes.io/name=stormforge-agent -c prom-agent

ts=2023-02-13T22:21:55.813Z caller=dedupe.go:112 component=remote level=error remote_name=d24ad1 url=https://in.dev-1.dev.gramlabs.dev/prometheus/write msg="non-recoverable error" count=77 exemplarCount=0 err="server returned HTTP status 404 Not Found: {\"message\":null}"
```

Bad credentials, double check parameters passed during installation (i.e. secrets):

```
# kubectl logs --tail=-1 -n stormforge-system -l app.kubernetes.io/name=stormforge-agent -c prom-agent

ts=2023-02-13T22:25:48.460Z caller=dedupe.go:112 component=remote level=error remote_name=0745da url=https://in.dev-1.dev.gramlabs.dev/prometheus/write msg="non-recoverable error" count=35 exemplarCount=0 err="server returned HTTP status 401 Unauthorized: Authorization malformed or invalid"
ts=2023-02-13T22:26:03.506Z caller=dedupe.go:112 component=remote level=error remote_name=0745da url=https://in.dev-1.dev.gramlabs.dev/prometheus/write msg="non-recoverable error" count=77 exemplarCount=0 err="server returned HTTP status 401 Unauthorized: Authorization malformed or invalid"
```

### Enable debug logging

Debug logging can now be enabled via http requests.
This should make it more useful to enable debug logging for a short period.

The default log level is `1` ( info ).

This can be changed by:
```
kubectl port-forward -n stormforge-system <stormforge-agent pod> 6060:6060

# Default info level logging
curl -X PUT localhost:6060/debug/loglevel -d level=1
# Verbose/Debug logging
curl -X PUT localhost:6060/debug/loglevel -d level=5
# Trace logging
curl -X PUT localhost:6060/debug/loglevel -d level=9
```

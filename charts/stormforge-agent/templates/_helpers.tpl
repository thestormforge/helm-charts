{{/*
Expand the name of the chart.
*/}}
{{- define "stormforge-agent.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "stormforge-agent.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "stormforge-agent.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Define a series of reusable required values, built from either .Values or from the existing secret
(if present). Using these helps prevent accidental loss of critical configuration information during
upgrade.
*/}}

{{/* Usage: ($scopeForRecycleFn := include "stormforge-agent.scopeForRecycleFn" . | fromJson) */}}
{{- define "stormforge-agent.scopeForRecycleFn" -}}
    {{- $secret := dict -}}
    {{- if not .Values.resetSecret -}}
        {{- $secret = (lookup "v1" "Secret" .Release.Namespace (include "stormforge-agent.fullname" .)).data | default dict -}}
    {{- end }}
    {{- range $k, $v := $secret -}}{{- $_ := set $secret $k ($v | b64dec) -}}{{- end -}}
    {{- dict "secret" $secret "values" .Values | toJson -}}
{{- end -}}

{{/* Usage: (include "stormforge-agent.recycle.clientID" $scopeForRecycleFn). */}}
{{- define "stormforge-agent.recycle.clientID" -}}
    {{- required "authorization.clientID is required" (dig "authorization" "clientID" nil .values | default .secret.STORMFORGE_CLIENT_ID) -}}
{{- end -}}

{{/* Usage: (include "stormforge-agent.recycle.clientSecret" $scopeForRecycleFn). */}}
{{- define "stormforge-agent.recycle.clientSecret" -}}
    {{- required "authorization.clientSecret is required" (dig "authorization" "clientSecret" nil .values | default .secret.STORMFORGE_CLIENT_SECRET) -}}
{{- end -}}

{{/* Usage: (include "stormforge-agent.recycle.issuer" $scopeForRecycleFn). */}}
{{- define "stormforge-agent.recycle.issuer" -}}
    {{- required "authorization.issuer is required" (dig "authorization" "issuer" nil .values | default .secret.STORMFORGE_ISSUER) -}}
{{- end -}}

{{/* Usage: (include "stormforge-agent.recycle.address" $scopeForRecycleFn). */}}
{{- define "stormforge-agent.recycle.address" -}}
    {{- required "stormforge.address is required" (dig "stormforge" "address" nil .values | default .secret.STORMFORGE_SERVER) -}}
{{- end -}}

{{/* Usage: (include "stormforge-agent.recycle.clusterName" $scopeForRecycleFn). */}}
{{- define "stormforge-agent.recycle.clusterName" -}}
    {{- required "stormforge.clusterName is required" (dig "stormforge" "clusterName" nil .values | default .secret.STORMFORGE_CLUSTER_NAME) -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "stormforge-agent.labels" -}}
helm.sh/chart: {{ include "stormforge-agent.chart" . }}
{{ include "stormforge-agent.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "stormforge-agent.selectorLabels" -}}
app.kubernetes.io/name: {{ include "stormforge-agent.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
component: agent
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "stormforge-agent.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "stormforge-agent.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the clusterrolebinding view name
*/}}
{{- define "stormforge-agent.roleBindingViewName" -}}
{{- printf "%s-view" (include "stormforge-agent.fullname" .) -}}
{{- end -}}

{{/* StormForge Metrics */}}
{{- define "stormforge-agent.workload.metrics" -}}
{{- $metrics := list "sf_workload_pod_owner" "sf_workload_pod_container_resource_limits" "sf_workload_pod_container_resource_requests" "sf_workload_spec_replicas" "sf_workload_status_replicas" "sf_horizontalpodautoscaler_spec_target_metric" "sf_horizontalpodautoscaler_spec_max_replicas" "sf_horizontalpodautoscaler_spec_min_replicas" -}}
{{- printf "^(%s)$" ($metrics | join "|") -}}
{{- end -}}

{{/* StormForge Labels to keep */}}}
{{- define "stormforge-agent.workload.labels-to-keep" -}}
{{- $labels := list "__name__" "cluster_name" "container" "instance" "name" "kubernetes_io_arch" "node_kubernetes_io_instance_type" "pod" "topology_kubernetes_io_region" "topology_kubernetes_io_zone" "workload_name" "workload_namespace" "workload_resource" "namespace" -}}
{{- printf "^(%s)$" ($labels | join "|") -}}
{{- end -}}

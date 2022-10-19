{{/*
Expand the name of the chart.
*/}}
{{- define "optimize-live.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "optimize-live.fullname" -}}
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
{{- define "optimize-live.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "optimize-live.labels" -}}
helm.sh/chart: {{ include "optimize-live.chart" . }}
{{ include "optimize-live.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
component: controller
{{- end }}

{{/*
Selector labels
*/}}
{{- define "optimize-live.selectorLabels" -}}
app.kubernetes.io/name: {{ include "optimize-live.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
component: controller
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "optimize-live.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "optimize-live.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the role to use
*/}}
{{- define "optimize-live.clusterRoleName" -}}
{{- if .Values.rbac.clusterRole.create }}
{{- default (include "optimize-live.fullname" .) .Values.rbac.clusterRole.name }}
{{- else }}
{{- default "default" .Values.rbac.clusterRole.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the rolebinding to use
*/}}
{{- define "optimize-live.clusterRoleBindingName" -}}
{{- if .Values.rbac.clusterRoleBinding.create }}
{{- default (include "optimize-live.fullname" .) .Values.rbac.clusterRoleBinding.name }}
{{- else }}
{{- default "default" .Values.rbac.clusterRoleBinding.name }}
{{- end }}
{{- end }}

{{/*
Create the image pull secret
*/}}
{{- define "optimize-live.dockerConfig" -}}
{{- $auth := printf "%s:%s" .Values.imageCredentials.username .Values.imageCredentials.password -}}
{{- $authB64 := b64enc $auth -}}
{{- $dockerAuth := dict "username" .Values.imageCredentials.username "password" .Values.imageCredentials.password "auth" $authB64 -}}
{{- $registry := dict .Values.imageCredentials.registry $dockerAuth -}}
{{- $dockerAuths := dict "auths" $registry -}}
{{ b64enc (toJson $dockerAuths) }}
{{- end }}

{{/*
Create the namespace name
*/}}
{{- define "optimize-live.namespace" -}}
{{- default .Values.defaultNamespace .Release.Namespace }}
{{- end }}

{{/*
Applier name, hardcoded for now since controller assumes this name atm
*/}}
{{- define "applier.name" -}}
{{- default "applier" .Values.applier.nameOverride }}
{{- end }}

{{/*
Applier Common labels
*/}}
{{- define "applier.labels" -}}
helm.sh/chart: {{ include "optimize-live.chart" . }}
{{ include "applier.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Applier Selector labels
*/}}
{{- define "applier.selectorLabels" -}}
app.kubernetes.io/name: {{ include "applier.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
component: applier
{{- end }}

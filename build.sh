#!/usr/bin/env bash
set -e

IMAGE_REPO="${IMAGE_REPO:-thestormforge/optimize-controller}"
IMAGE_TAG="${IMAGE_TAG:-latest}"


# Pull the Optimize Controller image (mimic `imagePullPolicy = IfNotPresent` so we can support pre-pulled images)
[ -n "$(docker images -q "${IMAGE_REPO}:${IMAGE_TAG}" 2> /dev/null)" ] || docker pull -q "${IMAGE_REPO}:${IMAGE_TAG}" > /dev/null
dockerlabel () { docker inspect --format "{{ index .Config.Labels \"$1\" }}" "${IMAGE_REPO}:${IMAGE_TAG}"; }


# Fake the Optimize CLI by using the Docker version
CLI_IMAGE_REPO="${IMAGE_REPO%controller}cli"
[ -n "$(docker images -q "${CLI_IMAGE_REPO}:${IMAGE_TAG}" 2> /dev/null)" ] || docker pull -q "${CLI_IMAGE_REPO}:${IMAGE_TAG}" > /dev/null
stormforge () { docker run --rm "${CLI_IMAGE_REPO}:${IMAGE_TAG}" "$@"; }


# Chart information
CHART_DIR="$(git rev-parse --show-toplevel)/charts"
CHART_NAME="$(basename ${IMAGE_REPO})"
CHART_VERSION="$(dockerlabel "org.opencontainers.image.version")"
CHART_VERSION="${CHART_VERSION#v}"


# Create a build area and populate it with all the manifests we need
BUILD_DIR="$(git rev-parse --show-toplevel)/build"
rm -rf "${BUILD_DIR}" && mkdir -p "${BUILD_DIR}"
cp "$(git rev-parse --show-toplevel)/src/${CHART_NAME}/kustomization.yaml" "${BUILD_DIR}"
stormforge generate install --bootstrap-role > "${BUILD_DIR}/resources.yaml"
(cd "${BUILD_DIR}" && kustomize build --output ".")

# Additional information from the CLI
SETUP_TOOLS_IMAGE_REPOSITORY="$(stormforge version --setuptools-image)"
SETUP_TOOLS_IMAGE_REPOSITORY="${SETUP_TOOLS_IMAGE_REPOSITORY%%:*}"

# Chart.yaml
cat <<-EOF > "${CHART_DIR}/${CHART_NAME}/Chart.yaml"
apiVersion: v2
name: ${CHART_NAME}
version: ${CHART_VERSION}
description: $(dockerlabel "org.opencontainers.image.description")
type: application
home: $(dockerlabel "org.opencontainers.image.url")
sources:
- $(dockerlabel "org.opencontainers.image.source")
- $(git remote get-url origin)
icon: https://app.stormforge.io/img/logo.png
appVersion: ${CHART_VERSION}
kubeVersion: 1.14.x-0 - 1.21.x-0
EOF

# values.yaml
cat <<-EOF > "${CHART_DIR}/${CHART_NAME}/values.yaml"
image:
  repository: ${IMAGE_REPO}
  pullPolicy: IfNotPresent
  # Overrides the image tag whose default is the chart appVersion.
  tag: ""
rbac:
  create: true
  bootstrapPermissions: true
stormforge:
  address: https://api.stormforge.io/
authorization:
  issuer: https://api.stormforge.io/
  clientID: ""
  clientSecret: ""
datadog:
  apiKey:  # <DATADOG_API_KEY>
  appKey:  # <DATADOG_APP_KEY>
newrelic:
  accountID:  # <NEW_RELIC_ACCOUNT_ID>
  userKey:  # <NEW_RELIC_API_KEY>
extraEnvVars: []
# - name: FOO
#   value: bar
setupTasks:
  image:
    repository: ${SETUP_TOOLS_IMAGE_REPOSITORY}
    # Default is the chart appVersion.
    tag: ""
trialJobs:
  perftest:
    image:
      repository: thestormforge/optimize-trials
      tag: v0.0.3-stormforge-perf
  locust:
    image:
      repository: thestormforge/optimize-trials
      tag: v0.0.3-locust
EOF

# values.schema.json
cat <<-EOF > "${CHART_DIR}/${CHART_NAME}/values.schema.json"
{
  "$schema": "https://json-schema.org/draft-07/schema#",
  "properties": {
    "extraEnvVars": {
      "type": "array",
      "items": {
        "properties": {
          "name": {
            "type": "string"
          },
          "value": {
            "type": "string"
          }
        }
      },
      "x-kubernetes-patch-merge-key": "name",
      "x-kubernetes-patch-strategy": "merge"
    }
  }
}
EOF

# crds/*
CRDS_DIR="${CHART_DIR}/${CHART_NAME}/crds"
for f in "${BUILD_DIR}/"*_*_customresourcedefinition_*; do mv "${f}" "${CRDS_DIR}/${f#*_*_*_}" ; done

# templates/deployment.yaml
konjure --format "${BUILD_DIR}/apps_v1_deployment_{{ .release.name }}-controller-manager.yaml" > "${CHART_DIR}/${CHART_NAME}/templates/deployment.yaml"

# templates/secret.yaml
konjure --format "${BUILD_DIR}/v1_secret_{{ .release.name }}-manager.yaml" > "${CHART_DIR}/${CHART_NAME}/templates/secret.yaml"
cat << EOF >> "${CHART_DIR}/${CHART_NAME}/templates/secret.yaml"
  {{- if .Values.datadog.apiKey }}
  DATADOG_API_KEY: '{{ .Values.datadog.apiKey | b64enc }}'
  {{- end }}
  {{- if .Values.datadog.appKey }}
  DATADOG_APP_KEY: '{{ .Values.datadog.appKey | b64enc }}'
  {{- end }}
  {{- if and .Values.newrelic.accountID .Values.newrelic.userKey }}
  NEW_RELIC_ACCOUNT_ID: '{{ .Values.newrelic.accountID | b64enc }}'
  NEW_RELIC_API_KEY: '{{ .Values.newrelic.userKey | b64enc }}'
  {{- end }}
  {{- range .Values.extraEnvVars }}
  {{ .name }}: '{{ .value | b64enc }}'
  {{- end }}
EOF
	

# templates/rbac.yaml
RBAC_TEMPLATE="${CHART_DIR}/${CHART_NAME}/templates/rbac.yaml"
echo "{{- if .Values.rbac.create -}}" > "${RBAC_TEMPLATE}"
konjure --format "${BUILD_DIR}/rbac.authorization.k8s.io_v1_clusterrole_{{ .release.name }}-manager-role.yaml" >> "${RBAC_TEMPLATE}"
echo "---" >> "${RBAC_TEMPLATE}"
konjure --format "${BUILD_DIR}/rbac.authorization.k8s.io_v1_clusterrolebinding_{{ .release.name }}-manager-rolebinding.yaml" >> "${RBAC_TEMPLATE}"
echo "{{- if .Values.rbac.bootstrapPermissions }}" >> "${RBAC_TEMPLATE}"
echo "---" >> "${RBAC_TEMPLATE}"
konjure --format "${BUILD_DIR}/rbac.authorization.k8s.io_v1_clusterrole_{{ .release.name }}-patching-role.yaml" >> "${RBAC_TEMPLATE}"
echo "---" >> "${RBAC_TEMPLATE}"
konjure --format "${BUILD_DIR}/rbac.authorization.k8s.io_v1_clusterrolebinding_{{ .release.name }}-patching-rolebinding.yaml" >> "${RBAC_TEMPLATE}"
echo "{{- end -}}" >> "${RBAC_TEMPLATE}"
echo "{{- end -}}" >> "${RBAC_TEMPLATE}"


# Clean up
rm -rf "${BUILD_DIR}"


# Print a summary (NOTE: if we exit with 0 then this will also be the commit message!)
echo "Built chart ${CHART_NAME}-${CHART_VERSION} from tag '${IMAGE_TAG}'"
echo
echo "${IMAGE_REPO}@$(docker images --no-trunc -q ${IMAGE_REPO}:${IMAGE_TAG})"
echo "${CLI_IMAGE_REPO}@$(docker images --no-trunc -q ${CLI_IMAGE_REPO}:${IMAGE_TAG})"

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
authorization:
  clientID: ""
  clientSecret: ""
EOF

# crds/*
CRDS_DIR="${CHART_DIR}/${CHART_NAME}/crds"
for f in "${BUILD_DIR}/"*_*_customresourcedefinition_*; do mv "${f}" "${CRDS_DIR}/${f#*_*_*_}" ; done

# templates/deployment.yaml
DEPLOYMENT_TEMPLATE="${CHART_DIR}/${CHART_NAME}/templates/deployment.yaml"
cat "${BUILD_DIR}/apps_v1_deployment_{{ .release.name }}-controller-manager.yaml" \
	| sed -e "/namespace: '{{ .Release.Namespace }}'/d" > "${DEPLOYMENT_TEMPLATE}"

# templates/secret.yaml
SECRET_TEMPLATE="${CHART_DIR}/${CHART_NAME}/templates/secret.yaml"
cat "${BUILD_DIR}/v1_secret_{{ .release.name }}-manager.yaml" \
	| sed -e "/namespace: '{{ .Release.Namespace }}'/d" > "${SECRET_TEMPLATE}"

# templates/rbac.yaml
RBAC_TEMPLATE="${CHART_DIR}/${CHART_NAME}/templates/rbac.yaml"
echo "{{- if .Values.rbac.create -}}" > "${RBAC_TEMPLATE}"
cat "${BUILD_DIR}/rbac.authorization.k8s.io_v1_clusterrole_{{ .release.name }}-manager-role.yaml" >> "${RBAC_TEMPLATE}"
echo "---" >> "${RBAC_TEMPLATE}"
cat "${BUILD_DIR}/rbac.authorization.k8s.io_v1_clusterrolebinding_{{ .release.name }}-manager-rolebinding.yaml" >> "${RBAC_TEMPLATE}"
echo "{{- if .Values.rbac.bootstrapPermissions }}" >> "${RBAC_TEMPLATE}"
echo "---" >> "${RBAC_TEMPLATE}"
cat "${BUILD_DIR}/rbac.authorization.k8s.io_v1_clusterrole_{{ .release.name }}-patching-role.yaml" >> "${RBAC_TEMPLATE}"
echo "---" >> "${RBAC_TEMPLATE}"
cat "${BUILD_DIR}/rbac.authorization.k8s.io_v1_clusterrolebinding_{{ .release.name }}-patching-rolebinding.yaml" >> "${RBAC_TEMPLATE}"
echo "{{- end -}}" >> "${RBAC_TEMPLATE}"
echo "{{- end -}}" >> "${RBAC_TEMPLATE}"


# Clean up
rm -rf "${BUILD_DIR}"


# Print a summary (NOTE: if we exit with 0 then this will also be the commit message!)
echo "Built chart ${CHART_NAME}-${CHART_VERSION} from tag '${IMAGE_TAG}'"
echo
echo "${IMAGE_REPO}@$(docker images --no-trunc -q ${IMAGE_REPO}:${IMAGE_TAG})"
echo "${CLI_IMAGE_REPO}@$(docker images --no-trunc -q ${CLI_IMAGE_REPO}:${IMAGE_TAG})"

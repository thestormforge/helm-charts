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
# TODO Versions of the Helm chart can exist _between_ application releases, how do we account for that?


# Overwrite the Helm chart metadata using information from the image
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
appVersion: "$(dockerlabel "org.opencontainers.image.version")"
EOF

# Overwrite the values
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


# Generate the manifests
cd "$(git rev-parse --show-toplevel)/src/${CHART_NAME}"
rm -rf "manifests" && mkdir "manifests"
stormforge generate install --bootstrap-role > "resources.yaml"
kustomize build --output "manifests"

CRDS_DIR="${CHART_DIR}/${CHART_NAME}/crds"
for f in "manifests/"*_*_customresourcedefinition_*; do mv "${f}" "${CRDS_DIR}/${f#*_*_*_}" ; done

DEPLOYMENT_TEMPLATE="${CHART_DIR}/${CHART_NAME}/templates/deployment.yaml"
mv "manifests/apps_v1_deployment_{{ .release.name }}-controller-manager.yaml" "${DEPLOYMENT_TEMPLATE}"
sed -i "" "/namespace: '{{ .Release.Namespace }}'/d" "${DEPLOYMENT_TEMPLATE}"

SECRET_TEMPLATE="${CHART_DIR}/${CHART_NAME}/templates/secret.yaml"
mv "manifests/v1_secret_{{ .release.name }}-manager.yaml" "${SECRET_TEMPLATE}"
sed -i "" "/namespace: '{{ .Release.Namespace }}'/d" "${SECRET_TEMPLATE}"

RBAC_TEMPLATE="${CHART_DIR}/${CHART_NAME}/templates/rbac.yaml"
hungryCat() { cat "$1" && rm "$1"; }
echo "{{- if .Values.rbac.create -}}" > "${RBAC_TEMPLATE}"
hungryCat "manifests/rbac.authorization.k8s.io_v1_clusterrole_{{ .release.name }}-manager-role.yaml" >> "${RBAC_TEMPLATE}"
echo "---" >> "${RBAC_TEMPLATE}"
hungryCat "manifests/rbac.authorization.k8s.io_v1_clusterrolebinding_{{ .release.name }}-manager-rolebinding.yaml" >> "${RBAC_TEMPLATE}"
echo "{{- if .Values.rbac.bootstrapPermissions }}" >> "${RBAC_TEMPLATE}"
echo "---" >> "${RBAC_TEMPLATE}"
hungryCat "manifests/rbac.authorization.k8s.io_v1_clusterrole_{{ .release.name }}-patching-role.yaml" >> "${RBAC_TEMPLATE}"
echo "---" >> "${RBAC_TEMPLATE}"
hungryCat "manifests/rbac.authorization.k8s.io_v1_clusterrolebinding_{{ .release.name }}-patching-rolebinding.yaml" >> "${RBAC_TEMPLATE}"
echo "{{- end -}}" >> "${RBAC_TEMPLATE}"
echo "{{- end -}}" >> "${RBAC_TEMPLATE}"


# Clean up (fail if we didn't explicitly consume everything)
rm "resources.yaml"
rm "manifests/v1_namespace_{{ .release.namespace }}.yaml"
rmdir manifests

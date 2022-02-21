# StormForge - Helm Charts

## How do I use this chart repository?

```shell
helm repo add stormforge https://registry.stormforge.io/chartrepo/library/
```

For additional instructions, view the [repository home page](https://thestormforge.github.io/helm-charts/).

## Development

This repository contains a `main` branch and a `gh-pages` branch: the `main` branch contains the source for the latest (potentially unreleased) version of the chart; the `gh-pages` branch contains a mirror of the Helm repository.

The [Helm Chart Releaser](https://github.com/marketplace/actions/helm-chart-releaser) Action is used to keep the the Helm repository on the `gh-pages` branch up to date.

There is a [Build](https://github.com/thestormforge/helm-charts/actions/workflows/build.yaml) Action that can be used to refresh the Optimize Pro chart (it can be run manually or triggered from another repository).

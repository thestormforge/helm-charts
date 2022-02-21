## Usage

[Helm](https://helm.sh) must be installed to use the charts.  Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

Once Helm has been set up correctly, add the repo as follows:

    helm repo add stormforge https://registry.stormforge.io/chartrepo/library/

If you had already added this repo earlier, run `helm repo update` to retrieve
the latest versions of the packages.  You can then run `helm search repo
stormforge` to see the charts.

To install the `optimize-controller` chart:

    helm install my-optimize-pro stormforge/optimize-controller --namespace stormforge-system --create namespace

To uninstall the chart:

    helm delete my-optimize-pro

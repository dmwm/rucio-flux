# Rucio


We have two clusters: integration and production.
The end goal is to leverage Flux and Kustomize to manage both clusters while minimizing duplicated declarations.

Flux is configured to install, test and upgrade Rucio using
`HelmRepository` and `HelmRelease` custom resources.
Flux monitors the Helm repository and this Git repository, and it will automatically
upgrade the Helm releases to their latest chart version based on semver ranges.

## Prerequisites

You will need a Kubernetes cluster version 1.22 or newer and kubectl version 1.18.

> NGINX ingress controller MUST be configured to allow ssl-passthrough. To check that on a cern instance, you can take a look at the daemonset on kube-system namespace called `cern-magnum-ingress-nginx-controller` and check the presence of `--enable-ssl-passthrough` flag. This can be rectified with `kubectl edit ds cern-magnum-ingress-nginx-controller`.

> CERN kubernetes cluster templates may include a prometheus node exporter that conflicts with the one provided here. You can remove it by running `kubectl -n kube-system delete service cern-magnum-prometheus-node-exporter` followed by `kubectl -n kube-system delete daemonset cern-magnum-prometheus-node-exporter`. Better is to request the cluster without monitoring enabled (it's a flag).

For a quick local test, you can use [Kubernetes kind](https://kind.sigs.k8s.io/docs/user/quick-start/).
Any other Kubernetes setup will work as well though.

In order to follow the guide you'll need a GitHub account and a
[personal access token](https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line)
that can create repositories (check all permissions under `repo`).


Or install the CLI by downloading precompiled binaries using a Bash script:

```sh
curl -s https://fluxcd.io/install.sh | sudo bash
```

> __(OPTIONAL)__ if OIDC authentication is enabled on the rucio-server configuration, you'll have to follow [this](./scripts/create_iam_clients/README.md) preparatory steps.

## Repository structure

The Git repository contains the following top directories:

- **apps** dir contains Helm releases with a custom configuration per cluster
- **infrastructure** dir contains common infra tools such as NGINX ingress controller and Helm repository definitions
- **clusters** dir contains the Flux configuration per cluster

```
├── apps
│   ├── base
│   ├── integration
│   ├── options
│   └── production
├── clusters
│   ├── integration
│   └── production
├── infrastructure
│   ├── base
│   │   ├── fluentbit
│   │   ├── prometheus
│   │   ├── etc..
│   ├── integration
│   └── production
```

The apps configuration is structured as follows:

- **apps/base/** dir contains namespaces, Helm release definitions, and the helm config files applicable to all CMS Rucio clusters. The helm files are converted into Kubernetes ConfigMaps by `kustomizeconfig.yaml` in each directory.
- **apps/production/** dir contains the production Helm release values all grouped in a single directory. `kustomization.yaml` shows which components are running for the production server and generates ConfigMaps from the relevant YAML files.
- **apps/integration/** dir contains the integration values similarly grouped
- **apps/options/** dir contains namespaces and Helm release definitions for optional components which may not run in every server
- **infrastructure/base/** contains the common defintions of helm repositories and the releases for 3rd party products we install
- **infrastructure/production(integration)/** dir contains the configuration changes specific to a cluster for the products in integration

Changes are applied in a cascading way which you can see from **apps/base/PRODUCT/PRODUCT-helm** where settings from later in the **valuesFrom** list take precedence over those from earlier in the list.

Note that with `path: ./apps/production` we configure Flux 
with `dependsOn` to tell Flux to create the infrastructure items before deploying the apps.

To install this in a kubernetes cluster, fork this repository on your personal GitHub account and export your GitHub access token, username and repo name:

```sh
export GITHUB_TOKEN=<your-token>
export GITHUB_USER=<your-username>
export GITHUB_REPO=<repository-name>
```

The Rucio setup relies on a number of secrets being created before flux is bootstrapped. Run the `create_flux_secrets.sh` script. 
This relies on three pieces of information not supplied by any repository:
- `$HOSTP12`: The certificate for a node in the Rucio cluster which also has entries for the node aliases like `cms-rucio.cern.ch`
- `$ROBOTP12`: The Robot certificate used for all FTS/gfal operations. This also gets used to authenticate as `root` to Rucio. 
- `${INSTANCE}-secrets.yaml` (not a YAML file): A file providing the true secrets of the Rucio install (database connection strings, passwords and tokens for various services)

The format of this file is

```text
# This is an ENV secret file

db_string="oracle://..."
kronos_password="..."  # Used to connect to the message broker
trace_password="..." # Used to connect to the message broker
monit_token="..." # Used to connect to FacOps MONIT pages for site status
gitlab_token="..." # Token for SITECONF gitlab repositroy
globus_client="..." # Not currently used
globus_refresh="..." # Not currently used
geoip_licence_key="..." # Used to connect to the MaxMind GeoIP database
```

You will need to get these files or values from someone who has them for the server you are looking to setup.

Verify that your staging cluster satisfies the flux prerequisites with:

```sh
flux check --pre
```

Set the kubectl context to your staging cluster and bootstrap Flux:

```sh
flux bootstrap github \
    --token-auth # New as of Flux 2.4  \ 
    --owner=${GITHUB_USER} \
    --repository=${GITHUB_REPO} \
    --branch=main \
    --personal \
    --path=clusters/integration # or production
```

The actual clusters are done WITHOUT the `--personal` flag, `GITHUB_USER=dmwm`, and a GitHub personal access token which has commit rights to the dmwm/rucio-flux repository.

The bootstrap command commits the manifests for the Flux components in `clusters/staging/flux-system` dir
and creates a deploy key with read-only access on GitHub, so it can pull changes inside the cluster.

Watch for the Helm releases being install on staging:

```console
$ watch flux get helmreleases --all-namespaces 
NAMESPACE	NAME   	REVISION	SUSPENDED	READY	MESSAGE                          
nginx    	nginx  	5.6.14  	False    	True 	release reconciliation succeeded	
podinfo  	podinfo	5.0.3   	False    	True 	release reconciliation succeeded	
redis    	redis  	11.3.4  	False    	True 	release reconciliation succeeded
```

Watch the production reconciliation:

```console
$ watch flux get kustomizations
NAME          	REVISION                                        READY
apps          	main/797cd90cc8e81feb30cfe471a5186b86daf2758d	True
flux-system   	main/797cd90cc8e81feb30cfe471a5186b86daf2758d	True
infrastructure	main/797cd90cc8e81feb30cfe471a5186b86daf2758d	True
```

Or get an overview of everything flux has control over with 
```console
$ flux get all -A
...
```

Once you have verified changes working in your own cluster, make a PR against `dmwm/rucio-flux` to have the changes deployed in production (or the integration server).

## Testing a new cluster

You can bring up a new cluster slowly. 
The crucial element is the proxy generating cron-jobs which are in the rucio-server helm chart.
Before adding servers to the LanDB aliases in OpenStack (check the old nodes for the format and change the numbers to something unused),
you can check that the server is responding correctly (testing the ingress and service) with this curl command:

`curl -H "Host: cms-rucio.cern.ch" http://[IP ADDRESS]/ping` and 
`curl --resolve cms-rucio-auth.cern.ch:443:[IP address] https://cms-rucio-auth.cern.ch/ping` to test the auth server.

The Host: is crucial as it forces the ingress to direct the traffic to the right pod. 
IP ADDRESS is the address of a host in the new cluster with role=ingress.
Performing this test from off-site also ensures the firewall is open.

Once this is done, you can slowly add LanDB aliases for the new nodes and remove them for the old nodes.

## Switching branches

If you want to test out a new development without accepting a PR (maybe you aren't sure it will work). 
Of course, this is only appropriate on a development server, not in production:

- Checkout your branch in git
- Update clusters/CLUSTERNAME/flux-system/gotk-sync.yaml to set the value of `branch` to `MY_TEST_BRANCH` and commit and push it upstream
- At the shell with KUBECONFIG set to your cluster: `flux suspend source git flux-system`
- `kubectl edit GitRepository  flux-system  -n flux-system` and change the value of `branch` to `MY_TEST_BRANCH`. Exit the editor.
- `flux resume source git flux-system`
  
Once testing is complete, repeat the above process but setting the branch back to its original value.

## Mantainance

### Renew FTS Robot certificates



```bash
ROBOTP12=<PATH TO FTS P12 HERE> UPDATE_FTS_CERTS=1 ./scripts/create_flux_secrets.sh
```

### Renew Host certificates

```bash
HOSTP12=<PATH TO HOST P12 HERE> UPDATE_HOST_CERTS=1 ./scripts/create_flux_secrets.sh
```

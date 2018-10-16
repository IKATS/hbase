# IKATS Operations

This repository contains all the elements to spin up a new IKATS cluster in the
CS network.

> The RETEX is provided in an annex document : [retex_deploiement_cluster.md](retex_deploiement_cluster.md)

## Directory structure

```
.             # You are here
├── charts    # Helm charts to deploy ikats on a running cluster
├── cluster   # Cluster initial setup scripts and playbooks
├── config    # Kubernetes configuration (once it is up and running)
└── doc       # ?
```

## Prerequisites

- Python + Ansible on your local machine
- A bare metal Ubuntu 16.04 server
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) installed on your machine
- [Helm](https://github.com/kubernetes/helm) installed on your machine
  - Install instructions [from here](https://github.com/helm/helm/blob/master/docs/install.md#from-script). If version of Tiller on the server is not matching. Use the script with option  `--version`

## Création de l'infrastructure IKATS Cluster

Cette partie à pour objectif de décrire les étapes permettant de créer l'infrastructure du cluser définie dans [les diagrammes d'architecture](../doc/)

### Accès à l'hôte

- L'hôte du cluster est disponible à l'adresse IP : 172.28.15.30
- L'utilisateur `ikats` est présent et appartient aux `sudoers`
- L'accès `root` est autorisé en ssh
- Les codes d'accès sont disponibles dans le fichier des mots de passe.

### Procédure

#### 1. Provision des VM sur l'hôte et déploiement K8S

Toutes les opérations sont effectuées sur le poste local via des tâches Ansilble encapsulés dans un script shell :

1. Put the correct host IP in those files:
   - cluster/deploy_ikats.sh
   - cluster/deployment/inventory.cfg
   - cluster/deployment/group_vars/vms.yml

2. go in the `cluster` directory and run `./deploy_ikats.sh`
   - This operation is the longest one, it will takeo aroung 50mn to complete.

À ce stade, nous avons un cluster K8S sans service de stockage, déployé sur une infrastructure de machines virtuelles et non spécifique à IKATS

#### 2. Configuration du contrôleur K8S sur poste local

Les opérations suivantes permettent de configuer les outils sur le poste local.

1. Une fois l'infrastructure des machines (VM) IKATS créée sur l'hôte il faut configurer le `kubectl` local pour qu'il se connecte au cluster K8S :
   - Les opérations nécessaires sont scriptées dans  [`cluster/import_kubectl_conf.sh`](cluster/import_kubectl_conf.sh)

2. Dans le cas où on doit bypasser le proxy, il faut identifier la liste des IP des VM créées précédement
   - SSH into the cluster host
   - retrieve the `/tmp/ikats_cluster_setup/inventory_items.cfg` file
   - add the network range into your local `NO_PROXY` environment variable (`172.28.18.0/16` for instance)

#### 3. Configuration de K8S pour IKATS

Le cluster K8S doit être configuré et provisionné avec des services spécifiques pour déployer les différents composants d'IKATS

Go in the `config` directory and run `./bootstrap_cluster_resouces.sh`
*More information [config/README.md](config/README.md)*

## IKATS Software stacks deployment

The deployment of IKATS is made of 2 charts:

- `stack`: The base software layer for data store with HDFS and HBase
  This allow to mutualize the Hadoop data storage layer between more than one IKATS instance
- `ikats`: That chart is for IKATS instances deployement.
  Currently the cluster and the charts support two k8s releases deployement: `demo` and `dev`

### Deployment of `stack` with Helm

#### From an existing cluster

The `hadoop` part of this chart is linked to a real disk space.
When starting, hadoop requires an empty folder in order to be initialized properly.
The second time a deployment occurs, the folder won't be empty.

A manual cleanup shall be done to erase all information from the volume bound to the image.
Otherwise, hadoop datanodes will yield errors upon start, complaining that their cluster ID
is not the same as the one read from the persistent storage.
This operation is automated by the playbook located at `ikats_ops/cluster/deployment/reset_hdfs_datas.yml`

You can run it like so:

```sh
cd ikats_ops/cluster/deployment
ansible-playbook -i ./inventory.cfg --flush-cache reset_hdfs_datas.yml
```

*Beware, HDFS shall not be running while performing this operation*

The other components of the chart (Zookeeper and HBase) are injected alongside HDFS,
and can be operated transparently. For more configuration, you can tweak the chart `values.yaml`

#### Chart deployment

```sh
cd ikats_ops/charts/stack

helm install --name ${YOUR_RELEASE_NAME} .
```

### Deployment of `ikats` chart with Helm

The script `charts/deploy_ikats.sh` is used to deploy a release of IKATS.
It retrieves existing persistent volume for postgresql data (associated to the release name), if exists.

Usage: `deploy_ikats.sh ${YOUR_RELEASE_NAME}`

## Monitoring with Kubernetes dashboard

1. run `kubectl proxy &`
2. then go to [kubernetes dashboard](http://127.0.0.1:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/#!/overview?namespace=default) (first time: click SKIP)

## IKATS "Cluster" PREPROD instance

Go to [http://preprod.intra.ikats.org](http://preprod.intra.ikats.org)

The name and the subdomains needed are declared into the ikats.org DNS.
It should be modified manually after each redeploymenet.

## Troubleshooting

- Rook filesystem won't spawn (no pod named `rook-ceph-mds` prefixed pod in the namespace you deployed your filesystem)
> Destructive solution:
> - Uninstall rook: `helm del rook-ceph --purge`
> - Remove `/var/lib/rook` and `/var/lib/kubelet/volumeplugins/*` on each VM
> - Reinstall rook with the helm chart (see `config/bootstrap_cluster_resouces.sh` file)

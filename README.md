This repo contains a demonstration of installation of [OSS RabbitMQ for Kubernetes](https://docs.vmware.com/en/VMware-RabbitMQ-for-Kubernetes/index.html) using the repo, but exactly follows what was depicted in the article [Install OSS RabbitMQ in Kubernetes using Cluster Operator](https://www.alfusjaganathan.com/blogs/install-oss-rabbitmq-kubernetes/)

The entire code in the repo is in templated format, which uses [ytt](https://carvel.dev/ytt/) for dynamically generating yaml configuration from declared values files.

Before continuing further, please have a look into the article [Install VMware RabbitMQ in Kubernetes using Cluster Operator](https://www.alfusjaganathan.com/blogs/install-oss-rabbitmq-kubernetes/), which gives a better understanding of what is available in the repo and how we are going to process it.

### Prerequisites

- Account at [Docker Hub](https://www.docker.com/products/docker-hub/)
- Kubernetes cluster with required operator privileges for installation
- [Carvel Tools](https://carvel.dev/#install) installed
- [Kubectl](https://kubernetes.io/docs/tasks/tools/) installed
- [kapp](https://carvel.dev/kapp/docs/v0.60.x/install/) installed
- [direnv](https://direnv.net/) installed

### Getting started

Clone the repository down to the workstation.

Connect to the Kubernetes cluster.

Summarized below are some of the kubernetes resources to be created in order to complete the installation, which we will see in detail later.

1. Namespaces
1. [Secretgen Controller](https://github.com/carvel-dev/secretgen-controller)
1. Secrets, [SecretImports](https://github.com/carvel-dev/secretgen-controller/blob/develop/docs/secret-export.md) and [SecretExports](https://github.com/carvel-dev/secretgen-controller/blob/develop/docs/secret-export.md)
1. [RabbitMQ Cluster Operator](https://www.rabbitmq.com/kubernetes/operator/quickstart-operator)
1. [RabbitMQCluster](https://www.rabbitmq.com/kubernetes/operator/using-operator)

Let's get into each of the above, one by one, more detailed.

**Setup Environment Variables and Secrets:** From the repo root folder, run the below command to create the environment secrets file.

  ```sh
  mv ./.envrc.secrets.template ./.envrc.secrets
  ```

  Update below **variables** in `./.envrc` and `./.envrc.secrets`

  ```
  export CFG_registry__username=
  export CFG_registry__password=
  ```

  Run command `direnv allow` so as to refresh the ENV onto your command scope. 

**Update YTT values:** Update the **value files** available in `values` folder as needed (especially the rabbitmq specific configuration, persistence_storage_class and persistence_storage)

Execute the below `kapp` and `kubectl` commands in the given order, so as to create the rabbitmq cluster. It is advisable to use `kubectl get` or `kubectl describe` command to verify the statuses of the installation.

**Namespaces:**: This creates the app `oss-rabbitmq-namespaces`, which creates the necessary **Namespaces**, one for `secrets` and second one for the `rabbitmq server cluster` itself. 

  ```sh
  ytt --ignore-unknown-comments -f ./templates/00-namespaces.yaml -f ./values/common.yaml --data-values-env CFG | kapp deploy -a oss-rabbitmq-namespaces -f- -y
  ```

**Secretgen Controller:** Execute the below code block in a command shell to install the [Secretgen Controller](https://github.com/carvel-dev/secretgen-controller) in the kubernetes cluster. 

  ```sh
  kubectl apply -f https://github.com/carvel-dev/secretgen-controller/releases/latest/download/release.yml
  ```

**Secrets, SecretImports and SecretExports:** Execute the below code block in a command shell to create the app `oss-rabbitmq-secrets`, which a `secret` in `generic-secrets` namespace, then a [secret export](https://github.com/carvel-dev/secretgen-controller/blob/develop/docs/secret-export.md) and [SecretExports](https://github.com/carvel-dev/secretgen-controller/blob/develop/docs/secret-export.md) in `generic-secrets` namespace are created, which is used to export the `secret` to any targeted namespaces, which is configured by using a [secret import](https://github.com/carvel-dev/secretgen-controller/blob/develop/docs/secret-export.md) created at the target namespace. Here, the secret `registry-credentials-secret` is exported to the namespace `rabbitmq-clusters`.

  ```sh
  ytt --ignore-unknown-comments -f ./templates/01-secrets.yaml -f ./values/common.yaml --data-values-env CFG | kapp deploy -a oss-rabbitmq-secrets -f- -y
  ```

**RabbitMQ Cluster Operator:** Execute the below code block in a command shell, which installs [RabbitMQ Cluster Operator](https://www.rabbitmq.com/kubernetes/operator/quickstart-operator)

> Note: The operator will be created in `rabbitmq-system` namespace

  ```sh
  kubectl apply -f "https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml"
  ```

Verify the operator availability by executing the below command in a command shell and make sure that `rabbitmqclusters.rabbitmq.com` is shown on the list.

  ```sh
  kubectl get customresourcedefinitions.apiextensions.k8s.io
  ```

**RabbitMQCluster:** Execute the below code block in a command shell to create the app `oss-rabbitmq-cluster`, which creates the RabbitMQ Server Cluster.

  ```sh
  ytt --ignore-unknown-comments -f ./templates/02-rabbitmqcluster.yaml -f ./values/rabbitmq.yaml -f ./values/common.yaml --data-values-env CFG | kapp deploy -a oss-rabbitmq-cluster -f- -y && sleep 45
  ```


We should have a cluster ready in few seconds, once available, we can obtain the IP address and the credentials as below.

**Obtain the IP address:** Execute the below command to retrieve the external IP address, or use any convenient method as your wish.

  ```sh
  kubectl get svc rabbitmq -n rabbitmq-clusters -o jsonpath="{.items[0].status.loadBalancer.ingress[0].ip}"
  ```

**Obtain the default username and password:** Execute the below commands to retrieve the username and password. 

  ```sh
  kubectl -n rabbitmq-clusters get secret rabbitmq-default-user -o jsonpath="{.data.username}" | base64 --decode
  kubectl -n rabbitmq-clusters get secret rabbitmq-default-user -o jsonpath="{.data.password}" | base64 --decode
  ```

> Note: To setup your own default user (here I used `guest`), add the below under `spec:rabbitmq:additionalConfig`.

  ```yaml
  loopback_users.guest = false
  default_user = guest
  default_pass = guest
  ```

Once you have the above information, you can open the management UI by launching `http://<IP Address>:15672` and log in using the obtained credentials.

Applications can connect to RabbitMQ server using port `5672`.

To quickly do a connectivity test using [RabbitMQ PerfTest](https://perftest.rabbitmq.com/), execute the below command after replacing IP address, username and password.

  ```sh
  docker run -it --rm pivotalrabbitmq/perf-test:latest --uri amqp://<username>:<password>@<IP Address>:5672 --id "connectivity test 1"
  ```

To manage the [RabbitMQ Cluster Operator](https://www.rabbitmq.com/kubernetes/operator/quickstart-operator) from cli using [Kubectl](https://kubernetes.io/docs/tasks/tools/) plugin, follow the instruction [here](https://docs.vmware.com/en/VMware-RabbitMQ-for-Kubernetes/1/rmq/kubernetes-operator-kubectl-plugin.html?hWord=N4IghgNiBcIA4FMBOAzEBfIA).

### Uninstall

To uninstall the cluster, execute the below in a command shell where it is connected to the kubernetes cluster.

  ```sh
  ./scripts/destroy.sh
  ```

### References

- [Installation of Rabbitmq](https://www.rabbitmq.com/kubernetes/operator/using-operator).
- [RabbitMQ Releases](https://github.com/rabbitmq/rabbitmq-server/releases)
- [Rabbitmq Samples](https://github.com/rabbitmq/cluster-operator/tree/main/docs/examples)

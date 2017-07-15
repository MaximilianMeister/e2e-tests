# Caasp end-to-end tests

This project hosts the end-to-end tests for the Caasp platform. They are meant to be run against
a CaaSP Cluster

This can be either a production environment installed from images, or a [caasp-devenv](https://github.com/kubic-project/caasp-devenv)

Unit and feature tests can also be found in the [velum project](https://github.com/kubic-project/velum).

## Tools

This project is using [Rspec](http://rspec.info/) and [Capybara](http://www.rubydoc.info/gems/capybara)
(with Phantomjs driver) to interact with Velum.

## Running the tests

First you need to have a running CaaSP cluster with `velum` ready to register the first user, and at least 2 minions up and running

Against a cluster set up via [caasp-devenv](https://github.com/kubic-project/caasp-devenv) and 3 minions via [k8s-terraform](https://github.com/kubic-project/terraform)

```
VERBOSE=true NODE_NUMBER=3 KUBERNETES_HOST=[MASTER_MINION_IP] bundle exec rspec spec/**/*
```

Against a CaaSP cluster installed via images:

```
VERBOSE=true \
HOSTNAMES=[K8S_MASTER_FQDN],[K8S_WORKER1_FQDN],[K8S_WORKER2_FQDN] \
NODE_NUMBER=3 \
SSH_KEY_PATH=/home/$USER/.ssh/id_rsa \
DASHBOARD_HOST=[ADMIN_NODE_IP] \
KUBERNETES_HOST=[MASTER_MINION_IP] \
bundle exec rspec spec/**/*
```

**Note**: to be able to run commands in the application containers make sure your public ssh key is in the authorized_keys on the minions

## Flags

| Name            | Type     | Default                               | Description                                                       |
|-----------------|----------|---------------------------------------|-------------------------------------------------------------------|
| VERBOSE         | `bool`   | `false`                               | Debug output                                                      |
| NODE_NUMBER     | `int`    | `2`                                   | Total number of minions                                           |
| HOSTNAMES       | `string` | `minionX.k8s.local,minionN.k8s.local` | Comma separated list of hostnames as they will appear in the UI   |
| SSH_KEY_PATH    | `string` | `nil`                                 | Path to public ssh key (must be present on all minions)           |
| DASHBOARD_HOST  | `string` | `Host IP address`                     | IP/Hostname of the machine that runs the velum UI                 |
| KUBERNETES_HOST | `string` | `localhost`                           | IP/Hostname of the machine that runs the Kubernetes master (api)  |

## License

This project is licensed under the Apache License, Version 2.0. See
[LICENSE](https://github.com/kubic-project/e2e-tests/blob/master/LICENSE) for the full
license text.

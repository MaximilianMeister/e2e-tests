# Caasp end to end tests

This project hosts the end-to-end tests for the Caasp platform. An environment
as close to production as possible is used to run the tests.

Unit and feature tests can also be found in the [velum project](https://github.com/kubic-project/velum).
These are tests that are utilizing all the components of the platform, therefore
they are slower and more complicated to setup.

## Tools

This project is using [Rspec](http://rspec.info/) and [Capybara](http://www.rubydoc.info/gems/capybara)
(with Phantomjs driver) to interact with Velum.

The testing environment is setup using kubelet (check the [Velum README](https://github.com/kubic-project/velum/blob/master/README.md) for more)
and we use terraform to create salt-minions that act as workers on the platform.

## Running the tests

For now:

```
rspec spec/**/*
```

After the tests are done there should be:

- no kubelet process running
- no docker containers left running (only refers to those we spawned)

### Specifying branches

For the end to end testing 5 git repositories are pulled:

- [caasp-devenv](https://github.com/kubic-project/caasp-devenv)
- [velum](https://github.com/kubic-project/velum)
- [k8s-salt](https://github.com/kubic-project/salt)
- [k8s-terraform](https://github.com/kubic-project/terraform)
- [caasp-container-manifests](https://github.com/kubic-project/caasp-container-manifests)

Sometimes we need to specify a spefic branch for each one of them. That can be
achieved by specifying the following environment variables:

- CAASP_DEVENV_BRANCH: branch to use for `caasp-devenv`
- VELUM_BRANCH: branch to use for `velum`
- TERRAFORM_BRANCH: branch to use for `k8s-terraform`
- SALT_BRANCH: branch to use for `k8s-salt`
- CAASP_CONTAINER_MANIFESTS_BRANCH: branch to use for `caasp-container-manifests`

You can also define the branch through the sinatra api `/start` endpoint:

```
curl -X POST http://localhost:4567/start --data "velum-branch=ui-integration"
```

or (for a pull request)

```
curl -X POST http://localhost:4567/start --data "velum-branch=pull/56/head"
```

The available params are salt-branch, velum-branch and terraform-branch.

## Other flags

You can provide other environment variables that will modify the behaviour of the end to end tests.
Allowed flags:

- SKIP_VELUM_IMAGE_CLEANUP: by default the velum image is rebuilt on every run for extra
  safety. While being useful in some environments (e2e-tests in our infrastructure), it
  might be overkill under some situations, making this process slower. Set this environment
  variable and the velum image will only be recreated if necessary.

## Output

You can enable verbose output by setting the `VERBOSE` env variable.
E.g.  `VERBOSE=true rspec spec/**/*`

If you want to keep an environment after the test finished set `KEEP`
E.g.  `KEEP=true rspec spec/**/*`

When you do, all the output from scripts will be output. Use this for debugging.

## TODO:

- The script that starts the kubelet (velum/kubernetes/start) and the script
  that stops the kubelet, both need `sudo` to run. We want the tests to run
  unsupervised so we need to get rid of those `sudo`s.

## License

This project is licensed under the Apache License, Version 2.0. See
[LICENSE](https://github.com/kubic-project/e2e-tests/blob/master/LICENSE) for the full
license text.

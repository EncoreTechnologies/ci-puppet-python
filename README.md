# ci-puppet-python
Repository for Continuous Integration tests Puppet modules with Bolt Python tasks.

## Quick Start

To add testing capabilities to your Puppet module pack simply:

``` shell
cd /path/to/my/puppet/module/
git clone https://github.com/EncoreTechnologies/ci-puppet-python.git
cp ci-puppet-python/module/Makefile .
make
```

## Details

This repo provides testing in the form of a Makefile.

The Makefile does all of the following when you run the `make` command:

* Cloning this repo into the `ci/` folder within your pack
* Creating a virtualenv in `ci/virtualenv` (note: `virtualenv` must be installed)
* Clones the `python_task_helper` repo into `ci/samdbox/`
* Validates all YAML files
* Validates all JSON files
* Lint all python (`*.py`) files in the repository (using `pylint`)
* Check all python (`*.py`) files against PEP-8 specs (using `flake8`)
* Executes all unit tests in the `test/unit` directory (using `nosetest`)

## Tips/Tricks

To get a list of available `make` targets run: `make list`

To clean up all of the data used by this CI system, simply run `make clean`

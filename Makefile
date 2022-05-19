################################################################################
# Description:
#  Executes testing and validation for python code and configuration files
#  within a Python Module.
#
# =============================================

ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
PYMODULE_DIR := $(ROOT_DIR)/..
PYMODULE_TEST_DIR ?= $(PYMODULE_DIR)/test
PYMODULE_FILES_DIR ?= $(PYMODULE_DIR)/files
PYMODULE_TASKS_DIR ?= $(PYMODULE_DIR)/tasks
CI_DIR ?= $(ROOT_DIR)
YAML_FILES := $(shell git ls-files '*.yaml' '*.yml')
JSON_FILES := $(shell git ls-files '*.json')
PY_FILES   := $(shell git ls-files '*.py')
SANDBOX_DIR ?= $(ROOT_DIR)/sandbox
TEST_COVERAGE_DIR ?= $(ROOT_DIR)/cover

### python 2/3 specific stuff
PYTHON_EXE ?= python
PYTHON_VERSION = $(shell $(PYTHON_EXE) --version 2>&1 | awk '{ print $$2 }')
PYTHON_NAME = python$(PYTHON_VERSION)
PYTHON_CI_DIR = $(ROOT_DIR)/$(PYTHON_NAME)
PIP_EXE ?= pip
VIRTUALENV_NAME ?= virtualenv
VIRTUALENV_DIR ?= $(PYTHON_CI_DIR)/$(VIRTUALENV_NAME)

space_char :=
space_char +=
comma := ,
PYMODULE_PYTHON_FILES := $(wildcard $(PYMODULE_FILES_DIR)/*.py)
PYMODULE_PYTHON_FILES += $(wildcard $(PYMODULE_TASKS_DIR)/*.py)
# remove leading file/path/components
PYMODULE_PYTHON_FILES_NOTDIR := $(notdir $(PYMODULE_PYTHON_FILES))
# remove file extensions
PYMODULE_PYTHON_FILES_BASENAME := $(basename $(PYMODULE_PYTHON_FILES_NOTDIR))
# make into a comma,separated,list
PYMODULE_PYTHON_FILES_COMMA := $(subst $(space_char),$(comma),$(PYMODULE_PYTHON_FILES_BASENAME))

.PHONY: all
all: virtualenv requirements lint test-python test-coveralls

.PHONY: python2
python2: .python2 .pythonvars all

.PHONY: python3
python3: .python3 .pythonvars all

.PHONY: clean
clean: .clean-virtualenv .clean-test-coverage .clean-sandbox

.PHONY: lint
lint: virtualenv requirements flake8 pylint json-lint yaml-lint

.PHONY: flake8
flake8: virtualenv requirements .flake8

.PHONY: pylint
pylint: virtualenv requirements .pylint

.PHONY: json-lint
pylint: virtualenv requirements .json-lint

.PHONY: yaml-lint
pylint: virtualenv requirements .yaml-lint

.PHONY: sandbox
sandbox: .sandbox

.PHONY: test-python
test-python: virtualenv requirements sandbox .test-python

.PHONY: test-coverage-html
test-coverage-html: virtualenv requirements .test-coverage-html

.PHONY: test-coveralls
test-coveralls: virtualenv requirements .test-coveralls

.PHONY: clean-test-coverage
clean-test-coverage: .clean-test-coverage

# list all makefile targets
.PHONY: list
list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$' | xargs

.PHONY: .flake8
.flake8:
	@echo
	@echo "==================== flake8 ===================="
	@echo
	. $(VIRTUALENV_DIR)/bin/activate; \
	for py in $(PY_FILES); do \
		echo "Checking $$py"; \
		flake8 --config $(CI_DIR)/lint-configs/python/.flake8 $$py || exit 1; \
	done


.PHONY: .pylint
.pylint:
	@echo
	@echo "==================== pylint ===================="
	@echo
	. $(VIRTUALENV_DIR)/bin/activate; \
	for py in $(PY_FILES); do \
		echo "Checking $$py"; \
		python -m pylint -E --rcfile=$(CI_DIR)/lint-configs/python/.pylintrc $$py && echo "--> No pylint issues found in file: $$py." || exit 1; \
	done


.PHONY: .json-lint
.json-lint:
	@echo
	@echo "==================== json-lint ===================="
	@echo
	. $(VIRTUALENV_DIR)/bin/activate; \
	for json in $(JSON_FILES); do \
		echo "Checking $$json"; \
		python -mjson.tool $$json > /dev/null || exit 1; \
	done


.PHONY: .yaml-lint
.yaml-lint:
	@echo
	@echo "==================== yaml-lint ===================="
	@echo
	. $(VIRTUALENV_DIR)/bin/activate; \
	for yaml in $(YAML_FILES); do \
		echo "Checking $$yaml"; \
		python -c "import yaml; yaml.safe_load(open('$$yaml', 'r'))" || exit 1; \
	done


.PHONY: .sandbox
.sandbox:
	@echo
	@echo "==================== sandbox ===================="
	@echo
	rm -rf $(SANDBOX_DIR)
	git clone 'https://github.com/puppetlabs/puppetlabs-python_task_helper.git' --depth 1 --single-branch --branch main $(SANDBOX_DIR)/python_task_helper
#	cp -r $(PYMODULE_TEST_DIR)/ $(SANDBOX_DIR)/
#cp -r $(PYMODULE_FILES_DIR)/ $(SANDBOX_DIR)/
#cp -r $(PYMODULE_TASKS_DIR)/ $(SANDBOX_DIR)/


.PHONY: .clean-sandbox
.clean-sandbox:
	@echo "==================== cleaning sandbox ===================="
	rm -rf $(SANDBOX_DIR)


.PHONY: .test-python
.test-python:
	@echo
	@echo "==================== test-python ===================="
	@echo
	. $(VIRTUALENV_DIR)/bin/activate; \
	if [ -d "$(PYMODULE_TEST_DIR)" ]; then \
		PT__installdir=$(SANDBOX_DIR) nosetests --rednose --immediate --with-parallel -s -v --with-coverage --cover-inclusive --cover-package=$(PYMODULE_PYTHON_FILES_COMMA) --exe $(PYMODULE_TEST_DIR) || exit 1; \
	else \
		echo "test/ directory not found: $(PYMODULE_TEST_DIR)";\
	fi;


.PHONY: .test-coverage-html
.test-coverage-html:
	@echo
	@echo "==================== test-coverage-html ===================="
	@echo
	. $(VIRTUALENV_DIR)/bin/activate; \
	if [ -d "$(PYMODULE_TEST_DIR)" ]; then \
		PT__installdir=$(SANDBOX_DIR) nosetests -s -v --rednose --immediate --with-parallel --with-coverage --cover-inclusive --cover-erase --cover-package=$(PYMODULE_PYTHON_FILES_COMMA) --cover-html --exe $(PYMODULE_TEST_DIR) || exit 1; \
	else \
		echo "test/ directory not found: $(PYMODULE_TEST_DIR)";\
	fi;


.PHONY: .test-coveralls
.test-coveralls:
	@echo
	@echo "==================== test-coveralls ===================="
	@echo
	. $(VIRTUALENV_DIR)/bin/activate; \
	if [ ! -z "$$COVERALLS_REPO_TOKEN" ]; then \
		coveralls; \
	else \
		echo "COVERALLS_REPO_TOKEN env variable is not set! Skipping test coverage submission to coveralls.io."; \
	fi;


.PHONY: .clean-test-coverage
.clean-test-coverage:
	@echo
	@echo "==================== clean-test-coverage ===================="
	@echo
	rm -rf $(TEST_COVERAGE_DIR)
	rm -f $(PYMODULE_DIR)/.coverage


.PHONY: requirements
requirements:
	@echo
	@echo "==================== requirements ===================="
	@echo
	ls $(PYTHON_CI_DIR)
	ls $(VIRTUALENV_DIR)
	ls $(VIRTUALENV_DIR)/bin
	. $(VIRTUALENV_DIR)/bin/activate; \
	$(VIRTUALENV_DIR)/bin/$(PIP_EXE) install --upgrade pip; \
	$(VIRTUALENV_DIR)/bin/$(PIP_EXE) install --cache-dir $(HOME)/.pip-cache -q -r $(CI_DIR)/requirements-dev.txt -r $(CI_DIR)/requirements-test.txt;


.PHONY: virtualenv
virtualenv:
	@echo
	@echo "==================== virtualenv ===================="
	@echo
# prefer using virtualenv command if it exists, because this works properly in travis
# for some reason doing python3 -m venv in travis doesn't give us a pip executable
	if [ ! -d "$(VIRTUALENV_DIR)" ]; then \
		if command -v virtualenv > /dev/null 2>&1; then \
			virtualenv --python=$(PYTHON_EXE) $(VIRTUALENV_DIR);\
		else \
			$(PYTHON_EXE) -m venv $(VIRTUALENV_DIR); \
		fi; \
	fi;

.PHONY: .clean-virtualenv
.clean-virtualenv:
	@echo "==================== cleaning virtualenv ===================="
	rm -rf $(VIRTUALENV_DIR)
	rm -rf $(CI_DIR)/python*

# setup python2 executable
.PHONY: .python2
.python2:
	@echo
	@echo "==================== python2 ===================="
	@echo
	$(eval PYTHON_EXE=python2)
	$(eval PIP_EXE=pip2)
	@echo "PYTHON_EXE=$(PYTHON_EXE)"
	@echo "PIP_EXE=$(PIP_EXE)"

# setup python3 executable
.PHONY: .python3
.python3:
	@echo
	@echo "==================== python3 ===================="
	@echo
	$(eval PYTHON_EXE=python3)
	$(eval PIP_EXE=pip3)
	@echo "PYTHON_EXE=$(PYTHON_EXE)"
	@echo "PIP_EXE=$(PIP_EXE)"

# initialize PYTHON_EXE dependent variables
.PHONY: .pythonvars
.pythonvars:
	@echo
	@echo "==================== pythonvars ===================="
	@echo
	$(eval PYTHON_VERSION=$(shell $(PYTHON_EXE) --version 2>&1 | awk '{ print $$2 }'))
	$(eval PYTHON_NAME=python$(PYTHON_VERSION))
	$(eval PYTHON_CI_DIR=$(ROOT_DIR)/$(PYTHON_NAME))
	$(eval VIRTUALENV_DIR=$(PYTHON_CI_DIR)/$(VIRTUALENV_NAME))
	@echo "PYTHON_VERSION=$(PYTHON_VERSION)"
	@echo "PYTHON_NAME=$(PYTHON_NAME)"
	@echo "PYTHON_CI_DIR=$(PYTHON_CI_DIR)"
	@echo "VIRTUALENV_DIR=$(VIRTUALENV_DIR)"

# @todo print test converage
# @todo print code metrics

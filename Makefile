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
VIRTUALENV_DIR ?= $(ROOT_DIR)/virtualenv
SANDBOX_DIR ?= $(ROOT_DIR)/sandbox
TEST_COVERAGE_DIR ?= $(ROOT_DIR)/cover

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
all: requirements lint test-python test-coveralls

.PHONY: clean
clean: .clean-virtualenv .clean-test-coverage .clean-sandbox

.PHONY: lint
lint: requirements flake8 pylint json-lint yaml-lint

.PHONY: flake8
flake8: requirements .flake8

.PHONY: pylint
pylint: requirements .pylint

.PHONY: json-lint
pylint: requirements .json-lint

.PHONY: yaml-lint
pylint: requirements .yaml-lint

.PHONY: sandbox
sandbox: .sandbox

.PHONY: test-python
test-python: requirements sandbox .test-python

.PHONY: test-coverage-html
test-coverage-html: requirements .test-coverage-html

.PHONY: test-coveralls
test-coveralls: requirements .test-coveralls

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
		python -m pylint -E --rcfile=$(CI_DIR)/lint-configs/python/.pylintrc $py && echo "--> No pylint issues found in file: $$py." || exit 1; \
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
	git clone 'https://github.com/puppetlabs/puppetlabs-python_task_helper.git' --depth 1 --single-branch --branch master $(SANDBOX_DIR)/python_task_helper
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
requirements: virtualenv
	@echo
	@echo "==================== requirements ===================="
	@echo
	. $(VIRTUALENV_DIR)/bin/activate; \
	$(VIRTUALENV_DIR)/bin/pip install --upgrade pip; \
	$(VIRTUALENV_DIR)/bin/pip install --cache-dir $(HOME)/.pip-cache -q -r $(CI_DIR)/requirements-dev.txt -r $(CI_DIR)/requirements-test.txt;


.PHONY: virtualenv
virtualenv: $(VIRTUALENV_DIR)/bin/activate
$(VIRTUALENV_DIR)/bin/activate:
	@echo
	@echo "==================== virtualenv ===================="
	@echo
	test -d $(VIRTUALENV_DIR) || virtualenv --no-site-packages $(VIRTUALENV_DIR)


.PHONY: .clean-virtualenv
.clean-virtualenv:
	@echo "==================== cleaning virtualenv ===================="
	rm -rf $(VIRTUALENV_DIR)


# @todo print test converage
# @todo print code metrics

# File:    Makefile
# Version: GNU Make 3.81
# Author:  Nicholas Russo (njrusmc@gmail.com)
# Purpose: Phony targets used for YAML linting and role tests.
#          The 'all' target runs linting then role tests in sequence.
#          The 'setup' target installs LaTeX and other Python packages.

.ONESHELL:

.PHONY: all
all:	lint test

.PHONY: lint
lint:
	@echo "Starting  lint"
	find . -name "*.yml" | xargs yamllint -s
	@echo "Completed lint"

.PHONY: test
test:
	@echo "Starting  role tests"
	export ANSIBLE_CONFIG=tests/ansible.cfg
	export openout_any=a
	ansible-playbook tests/test_playbook.yml -i tests/inv.yml
	@echo "Completed role tests"

.PHONY: setup
setup:
	@echo "Starting  setup"
	sudo apt-get update
	sudo apt-get install texlive-latex-recommended -y
	pip install -r requirements.txt
	@echo "Completed setup"

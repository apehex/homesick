.PHONY: help backup install install-all install-core install-dev install-dot install-media install-tools

help:
	@echo "backup.......... commit your local dotfiles to github"
	@echo "install-all..... install everything"
	@echo "install-core.... install the core packages"
	@echo "install-dev..... install the dev packages"
	@echo "install-dot..... pull the remote dotfiles and update the local configuration"
	@echo "install-media... install the media packages"
	@echo "install-tools... install the tools packages"

backup:
	bash ./backup.sh

install: install-all

install-all: install-core install-dev install-dot install-media install-tools

install-core:
	bash ./install.sh core

install-dev:
	bash ./install.sh dev

install-dot:
	bash ./install.sh dot

install-media:
	bash ./install.sh media

install-tools:
	bash ./install.sh tools
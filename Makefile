.PHONY: help backup install install-all install-core install-dev install-dot install-media install-tools

release = $(shell lsb_release -i -s)

install_script = install.apt.sh
backup_script = backup.apt.sh
ifneq ($(release), Debian)
	install_script = install.pacman.sh
	backup_script = backup.pacman.sh
endif

help:
	@echo "backup............. commit your local dotfiles to github"
	@echo "install-all........ install everything"
	@echo "install-admin...... install the administration  packages"
	@echo "install-desktop.... install the desktop packages"
	@echo "install-dev........ install the dev packages"
	@echo "install-dot........ pull the remote dotfiles and update the local configuration"
	@echo "install-gis........ install the GIS  packages"
	@echo "install-media...... install the media packages"
	@echo "install-network.... install the network packages"
	@echo "install-radio...... install the SDR packages"
	@echo "install-security... install the cyber security packages"

backup:
	bash ./backup.stow.sh

install: install-all

install-all: install-admin install-desktop install-dev install-dot install-gis install-media install-network install-radio install-security

install-admin:
	bash $(install_script) admin

install-desktop:
	bash $(install_script) desktop

install-dev:
	bash $(install_script) dev

install-dot:
	bash ./install.stow.sh

install-gis:
	bash $(install_script) gis

install-media:
	bash $(install_script) media

install-network:
	bash $(install_script) network

install-radio:
	bash $(install_script) radio

install-security:
	bash $(install_script) security

.PHONY: help backup backup-dotfiles clean-system configure-network install install-all install-admin install-desktop install-dev install-dotfiles install-gis install-live install-media install-network install-radio install-security install-terminal install-ui install-virtual

release = $(shell lsb_release -i -s)

install_script = install.apt.sh
backup_script = backup.apt.sh
ifneq ($(release), Debian)
	install_script = install.pacman.sh
	backup_script = backup.pacman.sh
endif

help:
	@echo "help............... show this help message"
	@echo "backup............. commit your local system to github"
	@echo "backup-dotfiles.... commit your local configuration to github"
	@echo "clean-system....... remove temporary files"
	@echo "configure-network.. configure the network"
	@echo "install-all........ install everything"
	@echo "install-admin...... install the administration  packages"
	@echo "install-desktop.... install the desktop packages"
	@echo "install-dev........ install the dev packages"
	@echo "install-dotfiles... pull the remote dotfiles and update the local configuration"
	@echo "install-gis........ install the GIS  packages"
	@echo "install-live....... install the live packages"
	@echo "install-media...... install the media packages"
	@echo "install-network.... install the network packages"
	@echo "install-radio...... install the SDR packages"
	@echo "install-security... install the cyber security packages"
	@echo "install-terminal... install tools for the terminal"
	@echo "install-ui......... install the window manager"
	@echo "install-virtual.... install virtualization tools"

backup: backup-dotfiles

backup-dotfiles:
	bash ./backup.dotfiles.sh

clean-system:
	bash ./clean.archlinux.sh

configure-network:
	bash ./configure.network.sh

install: install-all

install-all: install-admin install-desktop install-dev install-dotfiles install-gis install-media install-network install-radio install-security install-terminal install-ui install-virtual

install-admin:
	bash $(install_script) admin

install-desktop:
	bash $(install_script) desktop

install-dev:
	bash $(install_script) dev

install-dotfiles:
	bash ./install.dotfiles.sh

install-gis:
	bash $(install_script) gis

install-live:
	bash $(install_script) live

install-media:
	bash $(install_script) media

install-network:
	bash $(install_script) network

install-radio:
	bash $(install_script) radio

install-security:
	bash $(install_script) security

install-terminal:
	bash $(install_script) terminal

install-ui:
	bash $(install_script) ui

install-virtual:
	bash $(install_script) virtual

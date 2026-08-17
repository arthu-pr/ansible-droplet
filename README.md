# Ansible Droplets

This repository contains some personal Ansible projects that I use and update regularly.

It's meant to be re-usable and easy to understand.

## Current projects

- Ubuntu Server Setup - [ubuntu_server_setup](https://github.com/arthu-pr/ansible-droplet/tree/main/projects/ubuntu_server_setup)
- Software: install user software:
  - zsh with [prezto](https://github.com/sorin-ionescu/prezto)
  - nvm, Node and PM2
  - [Zellij](https://github.com/zellij-org/zellij) - terminal multiplexer similar to tmux
  - [Neovim](https://github.com/neovim/neovim)
- Nginx Setup Server Block: to automate the registration of a new domain on a server, with the default configuration on Nginx and Let's Encrypt SSL certificate (not fully working yet)
- Update packages and reboot if required: a playbook to update packages on your server and reboot if required — can run from a control machine, or self-hosted per server via `ansible-pull` (see [`projects/common/README.md`](projects/common/README.md))

## Disclaimer

This is my personal configuration (mostly Digital Ocean Ubuntu droplets).

It is Debian/Ubuntu oriented and the software I use might not be the same as yours.

## Directory structure

```graphql
inventories/
  host # main inventory
projects/
  proj1/
    inventory/
      host.yml # inventory for proj1
    roles/
      role1/
        tasks/
          main.yml
    playbook_proj1.yml
  proj2/
    inventory/
      host.yml # inventory for proj2
    roles/
      role1/
        tasks/
          main.yml
    playbook_proj2.yml
roles/ # main roles used in every project
  role1/
    tasks/
      main.yml
```

## Example commands

Assuming you have a `hosts.yml` file in `~/.ansible/` and a `secrets.yml` file in the current directory

```sh
ansible-playbook -i ~/.ansible/hosts.yml -e @secrets.yml --ask-vault-pass -K ubuntu_server_setup.yml
```

## Sources

- [Personal Ansible Desktop Configs](https://github.com/fabricesemti80/home.ansible.linux-config-with-ansible-pull) (forked of [LearnLinuxTV](https://github.com/LearnLinuxTV/personal_ansible_desktop_configs))
- [WordPress Ansible](https://github.com/spinupwp/wordpress-ansible) - for the Ubuntu Server Setup

### For the directory structure:

- [Code structure examples](https://github.com/varunpalekar/ansible-structure)
- [Ansible Multi-Project Directory Structure](https://github.com/smbambling/ansible-multi-project-repo)

### Helpful links:

- [Stack Overflow](https://stackoverflow.com/a/36361222/13172236) from [buzut](https://stackoverflow.com/users/1717735/buzut) / [kevin-c](https://stackoverflow.com/users/4834431/kevin-c) - prompt which let you decide interactively on which host you want to run a playbook.

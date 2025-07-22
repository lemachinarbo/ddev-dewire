[![add-on registry](https://img.shields.io/badge/DDEV-Add--on_Registry-blue)](https://addons.ddev.com)
[![tests](https://github.com/lemachinarbo/ddev-DeWired/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/lemachinarbo/ddev-DeWired/actions/workflows/tests.yml?query=branch%3Amain)
[![last commit](https://img.shields.io/github/last-commit/lemachinarbo/ddev-DeWired)](https://github.com/lemachinarbo/ddev-DeWired/commits)
[![release](https://img.shields.io/github/v/release/lemachinarbo/ddev-DeWired)](https://github.com/lemachinarbo/ddev-DeWired/releases/latest)

# DDEV DeWired

Simplify ProcessWire deployments with a single DDEV command: **De**fine once, **De**ploy everywhere.  
DeWired installs [ProcessWire](https://github.com/processwire/processwire) and automates GitHub as your deployment control center — manage dev, staging, and prod from a single source of truth.

With DeWired you can do 3 things:

1. [Download and install ProcessWire](#1-just-install-processwire) with one command.  
2. Install ProcessWire *and* [deploy your site](#2-set-up-deployment) (prod, staging, etc.) step by step — one command.  
3. [Do both at once](#3-install-and-deploy-in-one-command) in auto mode with minimal prompts… yep, one command.  
4. Nope, just 3.

## Why?

After reading the [RockMigrations Deployments guide](https://www.baumrock.com/en/processwire/modules/rockmigrations/docs/deploy/#update-config.php), I loved finally being able to publish/update a website with just a commit; that was a game changer for someone still using FTP. But wiring it all up the whole thing — ProcessWire, modules, repo, secrets, workflows, keys — was a time sucker.

DeWired builds on that idea, cutting the manual steps so your project is multi-environment deploy–ready from the start.


## Installation

```bash
ddev add-on get lemachinarbo/ddev-dewired
```

## Use Cases

### TL;DR

- `ddev dw-install` – Installs ProcessWire. No prerequisites required.
- `ddev dw-deploy` – Automates deployment to production, staging, or dev. Requires GitHub CLI, SSH keys, a personal access tokenm and a .env file.
- `ddev dewired` – Installs and deploys with minimal prompts. Same prerequisites as deploy.

### 1. Just install ProcessWire


## Commands

| Command | Description |
| ------- | ----------- |
| `ddev dewired` | Installs ProcessWire and automates publishing your site to production, staging, or dev with GitHub Actions |
| `ddev dw-install` | Install and bootstrap ProcessWire project |
| `ddev dw-deploy` | Automate all setup and deployment steps for publishing your site to any environment |
| `ddev dw-config-split` | Split config.php into config-local.php for a selected environment |
| `ddev dw-gh-env` | Automate setup of GitHub Actions repository variables and secrets |
| `ddev dw-gh-workflow` | Generate GitHub Actions workflow YAMLs for each environment/branch pair |
| `ddev dw-sshkeys-gen` | Generate personal and project SSH keys if they do not exist |
| `ddev dw-sshkeys-install` | Register personal and project SSH keys on a remote server and test authentication |
| `ddev dw-sync` | Sync files to the selected environment's server using rsync |
| `ddev rs` | Shorcut to run RockShell inside the web container |


## Credits

- Contributed and maintained by [@lemachinarbo](https://github.com/lemachinarbo)  
- Inspired by the lovely modules from [@BernhardBaumrock](https://github.com/BernhardBaumrock/)  
- Using [MoritzLost](https://github.com/moritzlost)'s [processwire.dev structure](https://github.com/MoritzLost/ProcessWireDev/blob/master/site/02-setup-and-structure/02-integrate-composer-with-processwire.md)  
- By the grace of [Ryan Cramer](https://github.com/ryancramerdesign) for creating ProcessWire  
- Powered by [DDEV](https://github.com/drud/ddev), which makes local dev painless   

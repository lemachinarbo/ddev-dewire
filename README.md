[![add-on registry](https://img.shields.io/badge/DDEV-Add--on_Registry-blue)](https://addons.ddev.com)
[![tests](https://github.com/lemachinarbo/ddev-dewire/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/lemachinarbo/ddev-dewire/actions/workflows/tests.yml?query=branch%3Amain)
[![last commit](https://img.shields.io/github/last-commit/lemachinarbo/ddev-DeWire)](https://github.com/lemachinarbo/ddev-dewire/commits)
[![release](https://img.shields.io/github/v/release/lemachinarbo/ddev-dewire)](https://github.com/lemachinarbo/ddev-dewire/releases/latest)

# DDEV DeWire
Simplify ProcessWire deployments with a single DDEV command: **De**fine once, **De**ploy everywhere.

DeWire installs [ProcessWire](https://github.com/processwire/processwire) and automates GitHub as your deployment control center — manage dev, staging, and prod from a single source of truth.

With DeWire you can do 3 things:

1. [Download and install ProcessWire](#1-installing-processwire) with one command.
2. Install ProcessWire *and* [deploy your site](#2-set-up-deployment) (prod, staging, etc.) step by step — one command.
3. [Do both at once](#3-install-and-deploy-in-one-command) in auto mode with minimal prompts… yep, one command.
4. Nope, just 3.

## Why?

After reading the [RockMigrations Deployments guide](https://www.baumrock.com/en/processwire/modules/rockmigrations/docs/deploy/#update-config.php), I loved finally being able to publish/update a website with just a commit; that was a game changer for someone still using FTP. But wiring it all up the whole thing —ProcessWire, modules, repo, secrets, workflows, keys— was a time sucker.

DeWire builds on that idea, cutting the manual steps so your project is multi-environment deploy–ready from the start.


## Installation

```bash
ddev add-on get lemachinarbo/ddev-dewire
```

## Use Cases

### 1. Installing Processwire

`ddev dw-install` *Installs ProcessWire. No prerequisites required.*

```bash
mkdir myproject
cd myproject
ddev config --auto
ddev add-on get lemachinarbo/ddev-dewired
ddev dw-install
```

### 2. Set up deployment

`ddev dw-deploy` *Automates deployment to production, staging, or dev. Requires GitHub CLI, SSH keys, a personal access tokenm and a .env file.*

To enable GitHub deployments, do a quick one-time setup:

1. Create your SSH keys (*only needed once. Future setups skip this step*).

```sh
ddev dw-sshkeys-gen
```

2. Install the [GitHub CLI](https://github.com/cli/cli#installation) and, once installed, authenticate by running (*also a one-time setup*):

```sh
gh auth login # Select `id_github.pub` as your public SSH key when prompted.
```

3. Edit the `.env` [file](https://raw.githubusercontent.com/lemachinarbo/ddev-compwser/dev/compwser/templates/.env.example), which was installed in your root (approot) by the `ddev dw-install` command.

2. Create a [new GitHub repository](https://github.com/new) for your project (private or public, your call):

```sh
gh repo create <reponame> --private

```

5. Create a [Personal Access Token](https://github.com/settings/personal-access-tokens). Under `Repository access` add your repository, and under `Repository permissions` add Read/Write access for `actions`, `contents`, `deployments`, `secrets`, `variables`, and `workflows`.
Copy the token in the `.env` file in this line `CI_TOKEN=xxxx`

6. Run the deployments script:

```sh
ddev dw-deploy
```

Once the installer finishes, update your web server configuration (using your hosting control panel) to point the `docroot` to `current`. For example, instead of `/var/www/html`, set your website root to `/var/www/html/current` to make your site visible.


### 3. Install and deploy in one command

The first time you create a deployment, there are a few requirements to set up (check steps one and two on [Setup a deployment](#2-set-up-deployment) ). But once that's done, all you need to start a project from scratch is:

- Complete the `.env` file.
- Create the repo and Personal Access Token with the right permissions, then copy it to the `CI_TOKEN` variable in your `.env` file.

And then just run:

```sh
ddev dewire
```

Nice. Time to enjoy some [cake](https://en.wikipedia.org/wiki/The_cake_is_a_lie).


## Guides

- How to [Install Processwire](https://github.com/lemachinarbo/ddev-dewire/wiki/(How-to)-Install-Processwire) from zero
- How to [customize Processwire installation](https://github.com/lemachinarbo/ddev-dewire/wiki/(How-to)-Install-Processwire#customizing-your-installation)

--- 


## Commands

> [!TIP]
> Check the [commands documentation](https://github.com/lemachinarbo/ddev-dewire/wiki) for a detailed overview of what happens under the hood each time you run a command.

| Command | Description |
| ------- | ----------- |
| [ddev dewire](https://github.com/lemachinarbo/ddev-dewire/wiki/dewire) | Installs ProcessWire and automates publishing your site to production, staging, or dev with GitHub Actions |
| [ddev dw-config-split](https://github.com/lemachinarbo/ddev-dewire/wiki/dw%E2%80%90config%E2%80%90split) | Split `config.php` into `config-local.php` for a selected environment |
| [ddev dw-db-import](https://github.com/lemachinarbo/ddev-dewire/wiki/dw%E2%80%90db%E2%80%90import) | Import a database dump into the current environment |
| [ddev dw-deploy](https://github.com/lemachinarbo/ddev-dewire/wiki/dw%E2%80%90deploy) | Automate all setup and deployment steps for publishing your site to any environment |
| [ddev dw-gh-env](https://github.com/lemachinarbo/ddev-dewire/wiki/dw%E2%80%90gh%E2%80%90env) | Automate setup of GitHub Actions repository variables and secrets |
| [ddev dw-gh-workflow](https://github.com/lemachinarbo/ddev-dewire/wiki/dw%E2%80%90gh%E2%80%90workflow) | Generate GitHub Actions workflow YAMLs for each environment/branch pair |
| [ddev dw-git-remote](https://github.com/lemachinarbo/ddev-dewire/wiki/dw%E2%80%90git%E2%80%90remote) | Manage git remotes for deployment |
| [ddev dw-install](https://github.com/lemachinarbo/ddev-dewire/wiki/dw%E2%80%90install) | Install and bootstrap ProcessWire project |
| [ddev dw-sshkeys-gen](https://github.com/lemachinarbo/ddev-dewire/wiki/dw%E2%80%90sshkeys%E2%80%90gen) | Generate personal and project SSH keys if they do not exist |
| [ddev dw-sshkeys-install](https://github.com/lemachinarbo/ddev-dewire/wiki/dw%E2%80%90sshkeys%E2%80%90install) | Register personal and project SSH keys on a remote server and test authentication |
| [ddev dw-sync](https://github.com/lemachinarbo/ddev-dewire/wiki/dw%E2%80%90sync) | Sync files to the selected environment's server using rsync |
| [ddev dw-transform](https://github.com/lemachinarbo/ddev-dewire/wiki/dw%E2%80%90transform) | Transform files or configuration for deployment |
| [ddev rs](https://github.com/lemachinarbo/ddev-dewire/wiki/rs) | Shortcut to run RockShell 🤍 inside the web container |


## Credits

- Contributed and maintained by [@lemachinarbo](https://github.com/lemachinarbo)
- Inspired by the lovely modules from [@BernhardBaumrock](https://github.com/BernhardBaumrock/)
- Using [MoritzLost](https://github.com/moritzlost)'s [processwire.dev structure](https://github.com/MoritzLost/ProcessWireDev/blob/master/site/02-setup-and-structure/02-integrate-composer-with-processwire.md)
- By the grace of [Ryan Cramer](https://github.com/ryancramerdesign) for creating ProcessWire
- Powered by [DDEV](https://github.com/drud/ddev), which makes local dev painless
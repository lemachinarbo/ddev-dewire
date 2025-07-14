[![add-on registry](https://img.shields.io/badge/DDEV-Add--on_Registry-blue)](https://addons.ddev.com)
[![tests](https://github.com/lemachinarbo/ddev-comPWser/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/lemachinarbo/ddev-comPWser/actions/workflows/tests.yml?query=branch%3Amain)
[![last commit](https://img.shields.io/github/last-commit/lemachinarbo/ddev-comPWser)](https://github.com/lemachinarbo/ddev-comPWser/commits)
[![release](https://img.shields.io/github/v/release/lemachinarbo/ddev-comPWser)](https://github.com/lemachinarbo/ddev-comPWser/releases/latest)

# DDEV comPWser

A one-ddev-command setup to install [ProcessWire](https://github.com/processwire/processwire) and wire up GitHub deploys to staging, prod, testing, or dev.

With comPWser you can do 3 things:
1. [Download and Install Processwire](#1-just-install-processwire) with one command.
2. Install Processwire and [deploy your site](#2-set-up-deployment) to production (or staging, testing, etc.), with… one command.
3. [The all-together](#3-install-and-deploy-in-one-command): steps 1 and 2 with minimal prompts in one command.
4. Nop, just 3.

## Why?

Because downloading, installing ProcessWire, adding the modules, setting up the repository, adding the actions, the secrets, the workflow… takes TIME. And, after reading the [RockMigrations Deployments guide](https://www.baumrock.com/en/processwire/modules/rockmigrations/docs/deploy/#update-config.php) I though: It will be so nice to have a blank ProcessWire installation synced to my repository, my local machine, my staging server, and my production environment in a few minutes — without monkey-clicking around between installers and setup screens.
(Being honest… I usually just have production… but now I can add staging and testing if I want!)


## Installation

```bash
ddev add-on get lemachinarbo/ddev-compwser
```


## Use Cases

### TL;DR

- `ddev cpw-install` – Installs ProcessWire. No prerequisites required.
- `ddev cpw-deploy` – Automates deployment to production, staging, or dev. Requires GitHub CLI, SSH keys, and a personal access token.
- `ddev compwser` – Installs and deploys with minimal prompts. Requires same prerequisites as deploy.

### 1. Just install ProcessWire

```bash
ddev cpw-install
```

**What It Does**
- Downloads [ProcessWire](https://github.com/processwire/processwire/)
- Installs ProcessWire in `/public`
- Initializes a local Git repository with main as the initial branch 
- Adds [RockMigrations](https://github.com/baumrock/RockMigrations) and [RockShell](https://github.com/baumrock/RockShell) as Git submodules
- Installs the RockMigrations module
- Backups Database
- Cleans up leftover core files
- Adds a `.gitignore` file for your repository
- Adds a .env template file
 
### 2. Set up deployment

To setup the deployment environments, we link each environment with its own branch:

- Production environment → main/master branch
- Staging environment → staging/develop branch
- testing environment → tests/testing branch
- And so on...

The branch names don’t matter, but keep in mind we’re assuming you’re following an environment-based branching model. This setup doesn’t fit workflows like [trunk-based development](https://atlassian.com/continuous-delivery/continuous-integration/trunk-based-development).


#### Steps

First time, we need to configure a few things so GitHub lets us automate the process; once that's done, you'll be able to create *deployment workflows* for any project just by creating the repo/token and filling your .env file. I promise.


1. Create your SSH keys (*only needed once. Future setups skip this step*).

```sh
ddev cpw-sshkeys-gen
```

2. Install the [GitHub CLI](https://github.com/cli/cli#installation) and, once installed, authenticate by running (*also a one-time setup*):

```sh
gh auth login
```

Select `id_github.pub` as your public SSH key when prompted.

3. Open and edit the `.env` file, which was installed in your project root by the `ddev cpw-install` command. If for any reason you don't have it, you can clone it using:

```sh
curl -sSL https://raw.githubusercontent.com/lemachinarbo/ddev-compwser/main/compwser/templates/.env.example -o .env
```

4. Create a [new GitHub repository](https://github.com/new) for your project (private or public, your call):

```sh
gh repo create <reponame> --private

```

5. Create a [Personal Access Token](https://github.com/settings/personal-access-tokens), under `Repository access` add your repository, and under `Repository permissions` add Read/Write access for `actions`, `contents`, `deployments`, `secrets`, `variables`, and `workflows`. 
Copy the token in the `.env` file in this line `CI_TOKEN=xxxx`  

6. Run the deployments script:

```sh
ddev cpw-deploy
```

Once the installer finishes, update your web server configuration (using your hosting control panel) to point the `docroot` to `current`. For example, instead of `/var/www/html`, set your website root to `/var/www/html/current` to make your site visible.

Test your website. From now on, simply commit and push to the branch for the environment you want to update, and your changes will go live automatically.

> [!IMPORTANT]
> If you need multiple environments (e.g., production, staging, testing), update the `.env` accordingly and run `ddev cpw-deploy` **once per environment**.

#### What `ddev cpw-deploy` Does
- Prompts you at each step so you can skip or rerun any part of the setup
- Checks for all requirements: `.env` file, SSH keys, GitHub CLI, and repository access
- Offers to generate missing SSH keys and register them with your server
- Checks and initializes your git remote and branch for deployment
- Sets up GitHub Actions variables and secrets for your chosen environment
- Lets you select which branch to link to your deployment environment and generates workflow files
- Creates or updates `config-local.php` from your `.env` file for environment-specific overrides
- Syncs all project files—including ProcessWire, RockShell, and modules—to your remote server
- Imports your local database to the server for the selected environment
- Updates the server folder structure and permissions for automated deployments

Where to go next? Check what else you can do when [moving to production](https://www.baumrock.com/en/processwire/modules/rockmigrations/docs/deploy/#rockshell-filesondemand) for tips on how to handle files, images, etc.


### 3. Install and deploy in one command

The first time you create a deployment, there are a few requirements to set up. But once that's done, all you need to start a project from scratch is:

- Complete the `.env` file.
- Create the repo and Personal Access Token with the right permissions, then copy it to the `CI_TOKEN` variable in your `.env` file.

And then just run:

```sh
ddev compwser
```

Nice. Time to enjoy some cake.

## Commands

| Command | Description |
| ------- | ----------- |
| `ddev compwser` | Installs ProcessWire and automates publishing your site to production, staging, or dev with GitHub Actions |
| `ddev cpw-install` | Install and bootstrap ProcessWire project |
| `ddev cpw-deploy` | Automate all setup and deployment steps for publishing your site to any environment |
| `ddev cpw-config-split` | Split config.php into config-local.php for a selected environment |
| `ddev cpw-gh-env` | Automate setup of GitHub Actions repository variables and secrets |
| `ddev cpw-gh-workflow` | Generate GitHub Actions workflow YAMLs for each environment/branch pair |
| `ddev cpw-sshkeys-gen` | Generate personal and project SSH keys if they do not exist |
| `ddev cpw-sshkeys-install` | Register personal and project SSH keys on a remote server and test authentication |
| `ddev cpw-sync` | Sync files to the selected environment's server using rsync |
| `ddev rs` | Shorcut to run RockShell inside the web container |


## Credits

- Contributed and maintained by [@lemachinarbo](https://github.com/lemachinarbo)
- Inspired by the lovely modules created by [@BernhardBaumrock](https://github.com/BernhardBaumrock/)
- Using [MoritzLost](https://github.com/moritzlost) [processwire.dev structure](https://github.com/MoritzLost/ProcessWireDev/blob/master/site/02-setup-and-structure/02-integrate-composer-with-processwire.md)

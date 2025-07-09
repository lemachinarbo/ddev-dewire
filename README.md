[![add-on registry](https://img.shields.io/badge/DDEV-Add--on_Registry-blue)](https://addons.ddev.com)
[![tests](https://github.com/lemachinarbo/ddev-comPWser/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/lemachinarbo/ddev-comPWser/actions/workflows/tests.yml?query=branch%3Amain)
[![last commit](https://img.shields.io/github/last-commit/lemachinarbo/ddev-comPWser)](https://github.com/lemachinarbo/ddev-comPWser/commits)
[![release](https://img.shields.io/github/v/release/lemachinarbo/ddev-comPWser)](https://github.com/lemachinarbo/ddev-comPWser/releases/latest)

# DDEV Compwser

## Overview

This add-on integrates Compwser into your [DDEV](https://ddev.com/) project.

## Installation

```bash
ddev add-on get lemachinarbo/ddev-comPWser
ddev restart
```

After installation, make sure to commit the `.ddev` directory to version control.

## Usage

| Command | Description |
| ------- | ----------- |
| `ddev describe` | View service status and used ports for Compwser |
| `ddev logs -s compwser` | Check Compwser logs |

## Advanced Customization

To change the Docker image:

```bash
ddev dotenv set .ddev/.env.compwser --compwser-docker-image="busybox:stable"
ddev add-on get lemachinarbo/ddev-comPWser
ddev restart
```

Make sure to commit the `.ddev/.env.compwser` file to version control.

All customization options (use with caution):

| Variable | Flag | Default |
| -------- | ---- | ------- |
| `COMPWSER_DOCKER_IMAGE` | `--compwser-docker-image` | `busybox:stable` |

## Credits

**Contributed and maintained by [@lemachinarbo](https://github.com/lemachinarbo)**

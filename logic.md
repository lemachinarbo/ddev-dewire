Our `dewire` script handles the full setup cycle of a ProcessWire project: install, SSH keys, pushing secrets to GitHub, loading `.env` values as GH vars/secrets, creating the config structure (with `config-local` logic to keep sensitive data out of version control), deploying with `rsync`, and reshaping the structure with RockMigrations.

### The Next Step: GitHub as the Source of Truth

We're moving towards using **GitHub Actions** and its secrets/vars as the canonical source of truth. That means:

1. The user defines a `.env.setup` file — this kicks off the whole flow (we are already parsing .env in xxx script).
2. The traditional processwire `config.php` setup (full of hardcoded secrets) becomes obsolete. Also our config split approach is obsolet. Instead, users put placeholders in `config.php`, like:

   ```php
   $config->dbPass = {DB_PASS}
   ```

   So later we can create a specific script that resolves those from the environment automatically — and can even update `config.php` for them.
3. So at the end of this setup:

   * `config.php` has **no sensitive data**
   * `config.php` is **shared across all environments**
   * Each environment has its own `.env` file with custom environment settings and sensible data
   * `.env` files are generated on the fly during deployment using GH secrets


### The Current Task

We have a script that reads a `.env` file, follows a `.env.schema`, and uploads secrets/vars to GitHub using the GH CLI.

Now we’re improving it by introducing:

#### 1. **Support for defaults in the schema**

We'll expand schema entries like this:

```
+DB_HOST|required|default=localhost
```

and if some cases, like this
!PW_ROOT|required|default=public|context=install

This enables:

* Skipping prompts when defaults exist
* filtering installer variables that are only for installation, no for uploading to GH

#### 2. **Wizard mode if no `.env` is found**

If `.env` is missing, the script prompts for all required variables and builds the file interactively. If a `.env.setup` exists, it uses whatever values are in it, and only asks for the missing required ones.

---

### Why this matters

Because `.env.setup` serves two roles:

* **Installer defaults** — to bootstrap ProcessWire
* **Runtime/env config** — to customize local/dev/prod setups

And users will hit different workflows:

---

### Scenarios

1. **User only wants to install ProcessWire**
   → Ask only for install vars (`context=install`)

2. **User wants install + local setup**
   → Ask for everything (`install`, `runtime`, `env`)

3. **User already has PW installed, just needs env setup**
   → Ask only for runtime/env vars

4. **User wants to prep multiple envs (e.g., local + staging)**
   → Prompt per env using prefixes (`PROD_`, `STAGING_`) filtered by `context=env`

---

### Control over non-schema variables

By default, we allow users to upload *any* variable defined in `.env`.

But we support opt-in behaviors via config entries inside `.env.setup`:

```env
# Optional flags for dewire behavior
DEWIRE_ALLOW_CUSTOM_VARS=true
DEWIRE_ASK_ON_CUSTOM_VARS=true
```

Behaviors:

* `ALLOW_CUSTOM_VARS=true` → Upload everything
* `ASK_ON_CUSTOM_VARS=true` (default) → Prompt per unknown var
* `ALLOW_CUSTOM_VARS=false` → Only upload vars defined in schema (ignore others)

We can still support `--dontaskme` to skip prompts and just upload known vars only.

---

### Final Notes

If needed, schema logic can be embedded directly into the script to make it portable. But for now, we keep it external for flexibility.

The key is: the schema drives structure and constraints, `.env.setup` drives flow, and the user gets full control without being forced into our logic.


## Task

Your job is to:

* Refactor the current `.env` handling script to support schema entries in the format:
  `+KEY|required|default=value|context=install` `+DB_HOST|required|default=localhost` skipping to upload the ones with context install

* Add an interactive menu when the script runs asking the user:

  ```
  What do you want to do?
  1. Setup local environment only
  2. Setup deployment environments (e.g., staging/prod)
  3. Setup all (local + environments)
  ```

* In wizard mode:

  * Load existing `.env.setup` if present
  * Prompt only for required missing values
  * Apply defaults from schema if available
  * Write the generated `.env` file

* Parse and respect behavior flags from `.env.setup`:

  * `DEWIRE_ALLOW_CUSTOM_VARS`
  * `DEWIRE_ASK_ON_CUSTOM_VARS`

* Handle non-schema variables:

  * If `DEWIRE_ALLOW_CUSTOM_VARS=true`, upload them all
  * If `DEWIRE_ASK_ON_CUSTOM_VARS=true`, prompt per unknown var
  * If `DEWIRE_ALLOW_CUSTOM_VARS=false`, silently skip unknown vars

* Add support for `--dontaskme` flag to skip all prompts and upload only schema-defined vars

* Keep existing GH CLI upload logic intact
# detox

![Bash 3.2+](https://img.shields.io/badge/Bash-3.2%2B-4eaa25?logo=gnubash&logoColor=white)
![Perl 5](https://img.shields.io/badge/Perl-5-39457e?logo=perl&logoColor=white)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

Strips invisible junk from text files in place: control characters left
behind by binary data, and zero-width characters (zero-width spaces and
joiners, byte-order marks). Everything else, including accented letters, emoji
and other non-ASCII text, is left byte-for-byte as it was.

## Install

Requires Bash 3.2+ and Perl 5, both of which ship with macOS and most Linux
distributions.

```sh
git clone https://github.com/blakesimpson-dev/detox.git ~/tools/detox
```

Then add an alias to `~/.zshrc` or `~/.bashrc` and restart your shell:

```sh
alias detox="$HOME/tools/detox/detox.sh"
```

detox reads `detox.conf` from its own folder, so run it in place (by alias, or
with the folder on your `PATH`) rather than copying the script elsewhere.

## Usage

```sh
detox -i ~/notes -n   # preview what would change
detox -i ~/notes -y   # clean everything without prompting
```

| Option              | Purpose                                       |
| ------------------- | --------------------------------------------- |
| `-i, --input <dir>` | Folder to scan for `.txt` files (`./data`)    |
| `-n, --dry-run`     | Show what would be cleaned, change nothing    |
| `-y, --yes`         | Clean without asking for each file            |
| `-d, --debug`       | Report how many lines changed in each file    |
| `--ignore-zwc`      | Only remove control characters                |
| `--quiet`           | Hide the progress bar                         |
| `-h, --help`        | Show help                                     |
| `-v, --version`     | Show the version                              |

## How it works

- **Scan:** finds every `.txt` file under the input folder, recursively.
- **Clean:** runs each through Perl in byte mode, so invalid or non-ASCII bytes
  can't be mangled. Files already clean are left untouched.
- **Write:** cleaned files are rewritten in place, keeping their permissions,
  and listed in `clean.log` in the input folder.
- **Configure:** colours and the two Perl substitutions live in `detox.conf`.

## Batch runs

`batcher.sh` runs detox on each subfolder of a directory, then renames the
folder, replacing one string with another, to mark it done:

```sh
./batcher.sh ./datasets ./detox.sh _raw _clean -- --yes
```

## License

MIT, see [LICENSE](LICENSE).

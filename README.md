# 🧼 detox.sh

> Clean your text files by removing binary and zero-width characters efficiently.

---

## 📦 Version

Version **1.3.5**

---

## 🚀 Usage

```bash
./detox.sh [OPTIONS]
```

### Options

| Flag                | Description                                                     |
|---------------------|-----------------------------------------------------------------|
| `-i, --input <dir>` | Input directory containing `.txt` files (default: `./data`)     |
| `-n, --dry-run`     | Show what would be cleaned without modifying files              |
| `-d, --debug`       | Enable verbose debug output                                     |
| `-y, --yes`         | Skip confirmation prompts                                       |
| `--ignore-zwc`      | Skip zero-width character cleaning                              |
| `--quiet`           | Suppress progress indicators and summary output                 |
| `-h, --help`        | Show this help message                                          |
| `-v, --version`     | Show detox version and exit                                     |

---

## ⚙️ Features

- **In-place cleaning**: Files are modified directly in the input directory
- **Binary cleaning**: Removes control characters `\x00-\x08,\x0B,\x0C,\x0E-\x1F,\x7F`
- **Zero-width cleaning**: Strips invisible Unicode characters like U+200B, U+FEFF
- **Progress bar**: Visual feedback for batch operations
- **Dry-run**: Preview changes without modifying files
- **Interactive confirmation**: Prompt before each file or skip with `-y`
- **Logging**:
  - In-place clean log stored in `clean.log`
  - Enhanced debug logging with per-file line diff stats (if enabled)
  - `[CLEAN]` messages show below the progress bar during cleaning
  - Any internal errors (e.g., Perl decode issues) are logged and deferred for post-clean review
- **Quiet mode**: Disable on-screen progress and summary

---

## 🧪 Testing

**`detox.test.sh`**
Automates test data creation and verifies cleaning logic:

```bash
bash detox.test.sh
```

Tests check for:

- Binary and ZWC removal
- Preservation of already-clean files
- Dry-run functionality
- Log output

---

## 🔧 Configuration

Settings are loaded from **`detox.conf`**:

```bash
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
RESET="\033[0m"

PERL_BINARY_REGEX='s/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]//g'
PERL_ZWC_REGEX='s/[\x{200B}\x{200C}\x{200D}\x{FEFF}]//g'
PERL_COMBINED_REGEX='s/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]//g; s/\x{200B}|\x{200C}|\x{200D}|\x{FEFF}//g'
```

---

## 📁 Project Structure

```text
detox.sh         # Main cleaning script
detox.conf       # Configuration file
README.md        # This documentation
LICENSE          # MIT License
detox.test.sh    # Automated tests
.gitattributes   # Git attributes
.editorconfig    # Formatting rules
.vscode/         # Editor settings
```

---

## 📄 License

MIT License. See [LICENSE](./LICENSE) for details.

---

_Last updated: Sun, May 25, 2025  06:32:33 PM_

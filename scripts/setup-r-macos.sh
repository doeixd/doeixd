#!/usr/bin/env bash
# One-command R + RStudio setup for a macOS statistics / data science class.
# Source: https://github.com/doeixd/doeixd/blob/main/scripts/setup-r-macos.sh
#
# Run:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/doeixd/doeixd/main/scripts/setup-r-macos.sh)"
#
# Optional flags:
#   --no-quarto     Do not install Quarto
#   --no-packages   Do not install common R packages
#
# Uses official Homebrew, R, RStudio, and CRAN distributions.

set -Eeuo pipefail

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }
trap 'die "Installation failed near line $LINENO. Review the error above, then rerun this script."' ERR

install_quarto=true
install_packages=true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-quarto) install_quarto=false ;;
    --no-packages) install_packages=false ;;
    -h|--help)
      echo "Usage: bash setup-r-macos.sh [--no-quarto] [--no-packages]"
      exit 0
      ;;
    *) die "Unknown option: $1" ;;
  esac
  shift
done

[[ "$(uname -s)" == "Darwin" ]] || die "This script only supports macOS."
[[ "$(id -u)" -ne 0 ]] || die "Run this as your regular Mac user, not with sudo."

log "Installing R + RStudio for macOS"
printf 'Mac architecture: %s\n' "$(uname -m)"

# Installing Homebrew normally also handles Apple's Command Line Tools.
if ! command -v brew >/dev/null 2>&1 &&
   [[ ! -x /opt/homebrew/bin/brew ]] &&
   [[ ! -x /usr/local/bin/brew ]]; then
  log "Installing Homebrew (you may be asked for your Mac password)"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  log "Homebrew is already installed"
fi

# Homebrew may not be in PATH yet on a new Mac. Persist the setup for zsh.
case "$(uname -m)" in
  arm64)
    if [[ -x /opt/homebrew/bin/brew ]]; then
      brew_bin=/opt/homebrew/bin/brew
    else
      brew_bin="$(command -v brew || true)"
    fi
    ;;
  *)
    if [[ -x /usr/local/bin/brew ]]; then
      brew_bin=/usr/local/bin/brew
    else
      brew_bin="$(command -v brew || true)"
    fi
    ;;
esac
[[ -n "$brew_bin" ]] || die "Homebrew installed but its executable was not found."

path_line="eval \"\$($brew_bin shellenv)\""
touch "$HOME/.zprofile"
if ! grep -Fqx "$path_line" "$HOME/.zprofile"; then
  printf '\n%s\n' "$path_line" >> "$HOME/.zprofile"
fi
eval "$("$brew_bin" shellenv)"
log "Homebrew ready: $(brew --version | head -n 1)"

# Official R binary installer; suitable for RStudio on Apple Silicon and Intel.
if command -v Rscript >/dev/null 2>&1 ||
   [[ -x /Library/Frameworks/R.framework/Resources/bin/Rscript ]]; then
  log "R is already installed"
else
  log "Installing R"
  brew install --cask r-app
fi

# The official R macOS installer typically provides a PATH link, but be safe.
if ! command -v Rscript >/dev/null 2>&1; then
  export PATH="/Library/Frameworks/R.framework/Resources/bin:$PATH"
fi
command -v Rscript >/dev/null 2>&1 || die "Rscript was not found after installing R."

if [[ -d /Applications/RStudio.app ]] ||
   brew list --cask rstudio >/dev/null 2>&1; then
  log "RStudio is already installed"
else
  log "Installing RStudio"
  brew install --cask rstudio
fi

if [[ "$install_quarto" == true ]]; then
  if command -v quarto >/dev/null 2>&1 ||
     brew list --cask quarto >/dev/null 2>&1; then
    log "Quarto is already installed"
  else
    log "Installing Quarto (for .qmd course reports)"
    brew install --cask quarto
  fi
fi

if [[ "$install_packages" == true ]]; then
  log "Installing common classroom R packages from CRAN"
  Rscript --vanilla - <<'RSCRIPT'
packages <- c("tidyverse", "readxl", "janitor", "rmarkdown", "knitr")
missing <- setdiff(packages, rownames(installed.packages()))

if (length(missing)) {
  message("Installing: ", paste(missing, collapse = ", "))
  install.packages(missing, repos = "https://cloud.r-project.org")
} else {
  message("All requested R packages are already installed.")
}

failed <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(failed)) {
  stop("These packages could not be loaded: ", paste(failed, collapse = ", "))
}

message("All requested R packages are available.")
RSCRIPT
fi

log "Installation complete!"
printf '\nR: %s\n' "$(Rscript --version 2>&1)"
if [[ "$install_quarto" == true ]] && command -v quarto >/dev/null 2>&1; then
  printf 'Quarto: %s\n' "$(quarto --version)"
fi
printf '\nOpen RStudio from Applications, then try this in its Console:\n\n'
printf '  library(tidyverse)\n'
printf '  ggplot(mtcars, aes(wt, mpg)) + geom_point()\n\n'
printf 'You should see a scatter plot in the Plots pane.\n'
printf 'If your class uses additional packages, install them with install.packages("packageName").\n'

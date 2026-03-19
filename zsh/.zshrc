###############################################################################
# ZSH Configuration for Optimal Performance and Readability
###############################################################################

# un comment zprof for performance reports
# zmodload zsh/zprof

# --------------------------------------------------------------------------
# Environment Variables & Paths
# --------------------------------------------------------------------------
# Set Homebrew path
export PATH="/opt/homebrew/bin:$PATH"

# Add local bin directory to PATH
export PATH="$HOME/.local/bin:$PATH"

# JAVA_HOME (using Java 21)
export JAVA_HOME=$(/usr/libexec/java_home -v 21)

# OpenJDK 21
export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"

# Android SDK configuration
export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
export PATH="$PATH:$ANDROID_SDK_ROOT/{emulator,tools,tools/bin,platform-tools}"

# Load secrets (tokens, API keys) from a non-tracked file
[[ -f "$HOME/.secrets" ]] && source "$HOME/.secrets"

# Set path to your oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Disable automatic oh‑my‑zsh updates (optional)
export DISABLE_AUTO_UPDATE=true

# --------------------------------------------------------------------------
# Plugin Configuration
# --------------------------------------------------------------------------
# Define essential plugins
plugins=(
  git
  zsh-autosuggestions
  # zsh-syntax-highlighting
  fast-syntax-highlighting
  zsh-autocomplete
)

# Optionally load additional plugins if the commands exist on your system
if [[ -x "$(command -v aws)" ]]; then
  plugins+=(aws)
fi

if [[ -x "$(command -v brew)" ]]; then
  plugins+=(brew)
fi

# yazi wrapper
function yz() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

# --------------------------------------------------------------------------
# Completion System Optimization
# --------------------------------------------------------------------------
autoload -Uz compinit
# Use cached completions if the dump is up-to-date; otherwise, rebuild
if [ "$(date +'%j')" != "$(stat -f '%Sm' -t '%j' ~/.zcompdump 2>/dev/null)" ]; then
  compinit
else
  compinit -C
fi

# Background precompilation of zcompdump for a faster next shell start
{
  zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"
  if [[ -s "$zcompdump" && (! -s "${zcompdump}.zwc" || "$zcompdump" -nt "${zcompdump}.zwc") ]]; then
    zcompile "$zcompdump"
  fi
} &!

# --------------------------------------------------------------------------
# Load oh-my-zsh & Custom Settings
# --------------------------------------------------------------------------
# This will load oh-my-zsh along with your plugins and theme
source "$ZSH/oh-my-zsh.sh"

# Load custom aliases and functions
source "$HOME/.config/zsh/aliases"

# --------------------------------------------------------------------------
# Tool-Specific Initializations
# --------------------------------------------------------------------------
# Initialize fast node manager (fnm)
eval "$(fnm env --use-on-cd --version-file-strategy=recursive --shell zsh)"

# Initialize Starship Prompt (if used)
eval "$(starship init zsh)"

# Configure zsh-syntax-highlighting styles (optional)
(( ${+ZSH_HIGHLIGHT_STYLES} )) || typeset -A ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[path]=none
ZSH_HIGHLIGHT_STYLES[path_prefex]=none

# Initialize zoxide for smarter directory navigation (skip in Claude Code)
if [[ "$CLAUDECODE" != "1" ]]; then
  eval "$(/opt/homebrew/bin/zoxide init zsh)"
fi

# --------------------------------------------------------------------------
# Aliases & Additional Tools
# --------------------------------------------------------------------------

# Claude
alias cld='claude'
alias bucld='brew upgrade claude-code'
cldsid() {
  CLAUDE_CODE_TASK_LIST_ID="$1" claude
}

# zoxide as 'cd' (skip in Claude Code)
if [[ "$CLAUDECODE" != "1" ]]; then
  alias cd='z'
  alias cdi='zi'
fi

# eza aliases for improved directory listings without the eza plugin overhead
alias ls="eza --color=always --icons=always --no-user --group-directories-first -h"
alias la="eza --long -a --color=always --icons=always --no-user -h --group-directories-first"

# bat for 'better cat'
# alias cat="bat"
# alias ccat="cat"

# fzf configuration
eval "$(fzf --zsh)"

fgco() {
  local branch
  branch=$(git for-each-ref --format='%(refname:short)' refs/heads/ refs/remotes/ \
    | sort -u \
    | grep -vE 'HEAD$' \
    | fzf --ansi --height=40% --reverse \
           --prompt='Checkout > ' \
           --preview="git log --oneline --color=always {} | head -20" \
           --preview-window=right:60%)

  [[ -n "$branch" ]] && git checkout "${branch##*/}"
}

# use fzf to search git logs.  selecting one will copy the hash into the clipboard
flog() {
  local selected
  selected=$(
    git log --color=always --date=relative \
      --pretty=format:'%C(auto)%h %s %C(white)%cr %C(green)%an%x1f%H' |
    fzf --ansi --no-sort --reverse --delimiter='\x1f' \
        --with-nth=1 \
        --preview 'git show --color=always {2}' \
        --preview-window=right:70%:wrap
  )

  if [[ -n "$selected" ]]; then
    local full_hash=${selected##*$'\x1f'}
    echo -n "$full_hash" | pbcopy
    echo "✓ Copied to clipboard: $full_hash"
  fi
}

# use fzf to fuzzy find commits from git log, and pipe them into the git cherry-pick -n command
fgcp() {
  local commits
  commits=$(git log --color=always --date=relative \
    --pretty=format:'%C(auto)%h %s %C(white)%cr %C(green)%an%x1f%H' |
    fzf --ansi -m --no-sort --reverse --delimiter='\x1f' \
        --with-nth=1 \
        --preview 'git show --color=always {2}' \
        --preview-window=right:70%:wrap |
    awk -F '\x1f' '{print $2}')

  [[ -n "$commits" ]] && gcp -n $commits
}

# fzf command options
export FZF_DEFAULT_OPTS="--style=full --layout=reverse --preview 'bat --color=always -n --line-range :500 {}'"
export FZF_DEFAULT_COMMAND="fd -tf --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_OPTS="--preview 'bat --color=always -n --line-range :500 {}'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"
export FZF_CTRL_R_OPTS="--prompt='History > ' --preview 'echo {}' --preview-window=down:3:wrap"

# Use fd (https://github.com/sharkdp/fd) for listing path candidates.
# - The first argument to the function ($1) is the base path to start traversal
# - See the source code (completion.{bash,zsh}) for the details.
_fzf_compgen_path() {
  fd --hidden --follow --exclude ".git" . "$1"
}

# Use fd to generate the list for directory completion
_fzf_compgen_dir() {
  fd --type d --hidden --follow --exclude ".git" . "$1"
}

# Use ~~ as the trigger sequence instead of the default **
export FZF_COMPLETION_TRIGGER='~~'
# Advanced customization of fzf options via _fzf_comprun function
# - The first argument to the function is the name of the command.
# - You should make sure to pass the rest of the arguments ($@) to fzf.
_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    # cd)           fzf --preview 'eza --tree --color=always {} | head -200'   "$@" ;;
    cd|z)           fzf --preview 'eza --tree --color=always {} | head -200'   "$@"  < <(fd --type d --hidden --strip-cwd-prefix --exclude .git) ;;
    export|unset) fzf --preview "eval 'echo \$'{}"         "$@" ;;
    ssh)          fzf --preview 'dig {}'                   "$@" ;;
    code|cursor|zed)    fzf --preview 'bat -n --color=always {}' "$@" < <(fd -tf --hidden --strip-cwd-prefix --exclude .git) ;;
    *)            fzf --preview 'bat -n --color=always {}' "$@" ;;
  esac
}

###############################################################################
# End of .zshrc Configuration
###############################################################################

#uncomment for performance reports
#zprof

# bun completions
[ -s "$HOME/.oh-my-zsh/completions/_bun" ] && source "$HOME/.oh-my-zsh/completions/_bun"

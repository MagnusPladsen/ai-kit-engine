#!/bin/bash
# AI Kit Engine — Bootstrap
# Scaffolds a new AI Kit content repo with kit.toml, install.sh wrapper, and directory structure.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/MagnusPladsen/ai-kit-engine/main/bootstrap.sh | bash
#
# Or clone and run locally:
#   bash bootstrap.sh

set -euo pipefail

# ─── Colors ──────────────────────────────────────────────────────────────────

RESET=$'\033[0m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
WHITE=$'\033[97m'
GREEN=$'\033[38;2;100;210;140m'
RED=$'\033[38;2;220;80;80m'
WARN=$'\033[38;2;220;180;60m'
CYAN=$'\033[38;2;125;207;255m'
LIME=$'\033[38;2;158;206;106m'
GOLD=$'\033[38;2;224;175;104m'
TEAL=$'\033[38;2;62;205;198m'

# ─── Helpers ─────────────────────────────────────────────────────────────────

info()    { printf '%s%s %s%s\n' "$CYAN" "  >" "$1" "$RESET"; }
success() { printf '%s%s %s%s\n' "$GREEN" "  ✓" "$1" "$RESET"; }
warn()    { printf '%s%s %s%s\n' "$WARN" "  !" "$1" "$RESET"; }
error()   { printf '%s%s %s%s\n' "$RED" "  ✗" "$1" "$RESET"; }

ask() {
    local prompt="$1" default="$2" var="$3"
    if [ -n "$default" ]; then
        printf '%s%s  %s %s[%s]%s: ' "$BOLD" "$LIME" "$prompt" "$DIM" "$default" "$RESET"
    else
        printf '%s%s  %s%s: ' "$BOLD" "$LIME" "$prompt" "$RESET"
    fi
    read -r _input < /dev/tty
    eval "$var=\"\${_input:-\$default}\""
}

ask_yn() {
    local prompt="$1" default="$2" var="$3"
    local hint
    if [ "$default" = "y" ]; then hint="Y/n"; else hint="y/N"; fi
    printf '%s%s  %s %s[%s]%s: ' "$BOLD" "$LIME" "$prompt" "$DIM" "$hint" "$RESET"
    read -r _input < /dev/tty
    _input="${_input:-$default}"
    case "$_input" in
        [Yy]*) eval "$var=y" ;;
        *)     eval "$var=n" ;;
    esac
}

slugify() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//'
}

dotify() {
    echo ".$(echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')"
}

upper_short() {
    # Derive short name: take first letters of each word, uppercase
    local words
    words=$(echo "$1" | sed 's/[^a-zA-Z0-9 ]/ /g')
    local short=""
    for word in $words; do
        short="${short}$(echo "${word:0:1}" | tr '[:lower:]' '[:upper:]')"
    done
    # If too short (1 char), use first 3 chars uppercase
    if [ ${#short} -lt 2 ]; then
        short=$(echo "$1" | tr '[:lower:]' '[:upper:]' | sed 's/[^A-Z0-9]//g' | cut -c1-4)
    fi
    echo "$short"
}

# ─── Banner ──────────────────────────────────────────────────────────────────

printf '\n'
printf '%s' "$LIME"
cat << 'BANNER'
       _    ___   _  ___ _     _____            _
      / \  |_ _| | |/ (_) |_  | ____|_ __   __ _(_)_ __   ___
     / _ \  | |  | ' /| | __| |  _| | '_ \ / _` | | '_ \ / _ \
    / ___ \ | |  | . \| | |_  | |___| | | | (_| | | | | |  __/
   /_/   \_\___| |_|\_\_|\__| |_____|_| |_|\__, |_|_| |_|\___|
                                            |___/
BANNER
printf '%s' "$RESET"
printf '%s%s  Bootstrap — Create a new AI Kit content repo%s\n\n' "$BOLD" "$DIM" "$RESET"

# ─── Preflight checks ───────────────────────────────────────────────────────

if ! command -v git &>/dev/null; then
    error "git is required but not found. Please install git first."
    exit 1
fi

# ─── Interactive questions ───────────────────────────────────────────────────

printf '%s%s  Kit Identity%s\n' "$BOLD" "$GOLD" "$RESET"
printf '%s  ─────────────────────────────────────────%s\n\n' "$DIM" "$RESET"

ask "Kit name" "My AI Kit" KIT_NAME

DEFAULT_SHORT=$(upper_short "$KIT_NAME")
ask "Short name / abbreviation" "$DEFAULT_SHORT" SHORT_NAME
SHORT_NAME=$(echo "$SHORT_NAME" | tr '[:lower:]' '[:upper:]')

DEFAULT_CONFIG_DIR=$(dotify "$KIT_NAME")
ask "Config directory name" "$DEFAULT_CONFIG_DIR" CONFIG_DIR

DEFAULT_WATERMARK=$(slugify "$KIT_NAME")
ask "Watermark" "$DEFAULT_WATERMARK" WATERMARK

ask "Tagline" "AI rules and skills for my team" TAGLINE

DEFAULT_DIR=$(slugify "$KIT_NAME")
ask "Directory name for the repo" "$DEFAULT_DIR" REPO_DIR

printf '\n'
printf '%s%s  Stack Selection%s\n' "$BOLD" "$GOLD" "$RESET"
printf '%s  ─────────────────────────────────────────%s\n' "$DIM" "$RESET"
printf '%s  Select which stacks to include (comma-separated numbers)%s\n\n' "$DIM" "$RESET"

# Stack definitions
STACK_IDS=(    react              dotnet       python                   go   ruby           rust)
STACK_NAMES=(  "React / Next.js / React Native / Expo"
               ".NET / C#"
               "Python / FastAPI / Django"
               "Go"
               "Ruby / Rails"
               "Rust" )
STACK_DETECT=( '"package.json", "tsconfig.json"'
               '"*.csproj", "*.sln"'
               '"pyproject.toml", "requirements.txt", "Pipfile"'
               '"go.mod"'
               '"Gemfile"'
               '"Cargo.toml"' )

for i in "${!STACK_IDS[@]}"; do
    local_default=""
    case "${STACK_IDS[$i]}" in
        react|dotnet) local_default=" ${DIM}(default)${RESET}" ;;
    esac
    printf '  %s%s%d%s  %s%s\n' "$LIME" "$BOLD" $((i+1)) "$RESET" "${STACK_NAMES[$i]}" "$local_default"
done

printf '\n'
ask "Stacks to include" "1,2" STACK_SELECTION

# Parse selection
SELECTED_STACKS=()
IFS=',' read -ra _selections <<< "$STACK_SELECTION"
for sel in "${_selections[@]}"; do
    sel=$(echo "$sel" | tr -d ' ')
    if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le ${#STACK_IDS[@]} ]; then
        SELECTED_STACKS+=("${STACK_IDS[$((sel-1))]}")
    fi
done

if [ ${#SELECTED_STACKS[@]} -eq 0 ]; then
    warn "No valid stacks selected, defaulting to react + dotnet"
    SELECTED_STACKS=(react dotnet)
fi

printf '\n'
ask_yn "Include integrations stack? (GitHub, Jira, Azure DevOps, Bitbucket)" "y" INCLUDE_INTEGRATIONS

printf '\n'
printf '%s%s  Theming%s\n' "$BOLD" "$GOLD" "$RESET"
printf '%s  ─────────────────────────────────────────%s\n\n' "$DIM" "$RESET"

ask_yn "Add a custom color theme?" "n" CUSTOM_THEME

THEME_NAME=""
THEME_LIME_RGB=""
THEME_TEAL_RGB=""
THEME_GOLD_RGB=""

if [ "$CUSTOM_THEME" = "y" ]; then
    ask "Theme name" "$KIT_NAME" THEME_NAME
    printf '%s  Enter RGB values as R,G,B (e.g. 200,214,75)%s\n' "$DIM" "$RESET"
    ask "Primary color (lime) RGB" "158,206,106" THEME_LIME_RGB
    ask "Secondary color (teal) RGB" "125,207,255" THEME_TEAL_RGB
    ask "Accent color (gold) RGB" "224,175,104" THEME_GOLD_RGB
fi

# ─── Summary ─────────────────────────────────────────────────────────────────

printf '\n'
printf '%s%s  Summary%s\n' "$BOLD" "$GOLD" "$RESET"
printf '%s  ─────────────────────────────────────────%s\n\n' "$DIM" "$RESET"

printf '  %s%-18s%s %s\n' "$BOLD" "Kit name:" "$RESET" "$KIT_NAME"
printf '  %s%-18s%s %s\n' "$BOLD" "Short name:" "$RESET" "$SHORT_NAME"
printf '  %s%-18s%s %s\n' "$BOLD" "Config dir:" "$RESET" "$CONFIG_DIR"
printf '  %s%-18s%s %s\n' "$BOLD" "Watermark:" "$RESET" "$WATERMARK"
printf '  %s%-18s%s %s\n' "$BOLD" "Tagline:" "$RESET" "$TAGLINE"
printf '  %s%-18s%s %s\n' "$BOLD" "Directory:" "$RESET" "$REPO_DIR"

_stack_display=""
for s in "${SELECTED_STACKS[@]}"; do _stack_display="$_stack_display $s"; done
if [ "$INCLUDE_INTEGRATIONS" = "y" ]; then _stack_display="$_stack_display integrations"; fi
printf '  %s%-18s%s%s\n' "$BOLD" "Stacks:" "$RESET" "$_stack_display"

if [ "$CUSTOM_THEME" = "y" ]; then
    printf '  %s%-18s%s %s (%s / %s / %s)\n' "$BOLD" "Theme:" "$RESET" "$THEME_NAME" "$THEME_LIME_RGB" "$THEME_TEAL_RGB" "$THEME_GOLD_RGB"
fi

printf '\n'
ask_yn "Proceed?" "y" CONFIRM
if [ "$CONFIRM" != "y" ]; then
    warn "Aborted."
    exit 0
fi

# ─── Create directory structure ──────────────────────────────────────────────

printf '\n'
info "Creating directory structure..."

if [ -d "$REPO_DIR" ]; then
    error "Directory '$REPO_DIR' already exists. Aborting."
    exit 1
fi

mkdir -p "$REPO_DIR"

# Rules directories
mkdir -p "$REPO_DIR/rules/shared"
touch "$REPO_DIR/rules/shared/.gitkeep"

for stack in "${SELECTED_STACKS[@]}"; do
    mkdir -p "$REPO_DIR/rules/$stack"
    touch "$REPO_DIR/rules/$stack/.gitkeep"
done

if [ "$INCLUDE_INTEGRATIONS" = "y" ]; then
    mkdir -p "$REPO_DIR/rules/integrations"
    touch "$REPO_DIR/rules/integrations/.gitkeep"
fi

# Other directories
mkdir -p "$REPO_DIR/skills"
touch "$REPO_DIR/skills/.gitkeep"

mkdir -p "$REPO_DIR/profiles"
touch "$REPO_DIR/profiles/.gitkeep"

mkdir -p "$REPO_DIR/branding"
touch "$REPO_DIR/branding/.gitkeep"

success "Directory structure created"

# ─── Generate kit.toml ──────────────────────────────────────────────────────

info "Generating kit.toml..."

{
    cat << TOML
# kit.toml — ${KIT_NAME} configuration
# This file drives the AI Kit Engine. Edit branding, stacks, and themes here.

[branding]
name = "${KIT_NAME}"
short_name = "${SHORT_NAME}"
tagline = "${TAGLINE}"
watermark = "${WATERMARK}"
config_dir = "${CONFIG_DIR}"
ascii_art_file = "branding/ascii.txt"

[settings]
default_theme = "Tokyo Night"

[defaults]
rules = true
skills = true
registry = true
profiles = true
TOML

    # Custom theme
    if [ "$CUSTOM_THEME" = "y" ]; then
        # Parse RGB values
        IFS=',' read -r LR LG LB <<< "$THEME_LIME_RGB"
        IFS=',' read -r TR TG TB <<< "$THEME_TEAL_RGB"
        IFS=',' read -r GR GG GB <<< "$THEME_GOLD_RGB"
        cat << TOML

[[custom_themes]]
name = "${THEME_NAME}"
lime = [${LR}, ${LG}, ${LB}]
teal = [${TR}, ${TG}, ${TB}]
gold = [${GR}, ${GG}, ${GB}]
TOML
        # default_theme will be updated via sed after file is written
    fi

    # Stack blocks
    for i in "${!STACK_IDS[@]}"; do
        for sel in "${SELECTED_STACKS[@]}"; do
            if [ "$sel" = "${STACK_IDS[$i]}" ]; then
                cat << TOML

[stacks.${STACK_IDS[$i]}]
name = "${STACK_NAMES[$i]}"
detect = [${STACK_DETECT[$i]}]
rules_dir = "${STACK_IDS[$i]}"
TOML
                break
            fi
        done
    done

    # Integrations stack (no detect)
    if [ "$INCLUDE_INTEGRATIONS" = "y" ]; then
        cat << TOML

[stacks.integrations]
name = "Integrations (GitHub, Jira, Azure DevOps, Bitbucket)"
rules_dir = "integrations"
TOML
    fi

} > "$REPO_DIR/kit.toml"

# Fix the default_theme if custom theme was set (sed approach above may fail in heredoc)
if [ "$CUSTOM_THEME" = "y" ] && [ -n "$THEME_NAME" ]; then
    if command -v sed &>/dev/null; then
        sed -i.bak "s/default_theme = \"Tokyo Night\"/default_theme = \"${THEME_NAME}\"/" "$REPO_DIR/kit.toml"
        rm -f "$REPO_DIR/kit.toml.bak"
    fi
fi

success "kit.toml generated"

# ─── Generate install.sh wrapper ─────────────────────────────────────────────

info "Generating install.sh wrapper..."

cat > "$REPO_DIR/install.sh" << 'WRAPPER'
#!/bin/bash
# KIT_NAME_PLACEHOLDER — Installer
# Thin wrapper that delegates to the AI Kit Engine submodule.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENGINE="$SCRIPT_DIR/engine/install.sh"

if [ ! -f "$ENGINE" ]; then
    echo "Fetching installer engine..."
    git -C "$SCRIPT_DIR" submodule update --init --recursive 2>/dev/null
    if [ ! -f "$ENGINE" ]; then
        echo "Error: Could not fetch engine. Run: git submodule update --init"
        exit 1
    fi
fi

_ENGINE_TMP="$(mktemp)"
cp "$ENGINE" "$_ENGINE_TMP"
trap 'rm -f "$_ENGINE_TMP"' EXIT
git -C "$SCRIPT_DIR" submodule update --remote engine 2>/dev/null &
exec bash "$_ENGINE_TMP" --kit-dir "$SCRIPT_DIR" "$@"
WRAPPER

# Replace placeholder with actual kit name
sed -i.bak "s/KIT_NAME_PLACEHOLDER/${KIT_NAME}/" "$REPO_DIR/install.sh"
rm -f "$REPO_DIR/install.sh.bak"

chmod +x "$REPO_DIR/install.sh"
success "install.sh wrapper generated"

# ─── Initialize git repo ────────────────────────────────────────────────────

info "Initializing git repository..."
git -C "$REPO_DIR" init -q
success "Git repository initialized"

# ─── Add engine submodule ───────────────────────────────────────────────────

info "Adding AI Kit Engine as submodule..."
git -C "$REPO_DIR" submodule add https://github.com/MagnusPladsen/ai-kit-engine.git engine 2>/dev/null || {
    warn "Could not add submodule automatically."
    warn "Run manually: cd $REPO_DIR && git submodule add https://github.com/MagnusPladsen/ai-kit-engine.git engine"
}
success "Engine submodule added"

# ─── Initial commit ─────────────────────────────────────────────────────────

info "Creating initial commit..."
git -C "$REPO_DIR" add -A
git -C "$REPO_DIR" commit -q -m "Initial scaffold via AI Kit Engine bootstrap"
success "Initial commit created"

# ─── Done ────────────────────────────────────────────────────────────────────

printf '\n'
printf '%s%s' "$LIME" "$BOLD"
printf '  ┌─────────────────────────────────────────────────┐\n'
printf '  │                                                 │\n'
printf '  │   ✓  Your AI Kit has been created!              │\n'
printf '  │                                                 │\n'
printf '  └─────────────────────────────────────────────────┘\n'
printf '%s\n' "$RESET"

printf '%s%s  Next steps:%s\n\n' "$BOLD" "$WHITE" "$RESET"
printf '  %s1.%s  cd %s\n' "$LIME" "$RESET" "$REPO_DIR"
printf '  %s2.%s  Add your rules to %srules/shared/%s and %srules/{stack}/%s\n' "$LIME" "$RESET" "$BOLD" "$RESET" "$BOLD" "$RESET"
printf '  %s3.%s  Add skills to %sskills/%s\n' "$LIME" "$RESET" "$BOLD" "$RESET"
printf '  %s4.%s  Customize %sbranding/ascii.txt%s with your ASCII art\n' "$LIME" "$RESET" "$BOLD" "$RESET"
printf '  %s5.%s  Edit %skit.toml%s to fine-tune configuration\n' "$LIME" "$RESET" "$BOLD" "$RESET"
printf '  %s6.%s  Test the installer: %sbash install.sh%s\n' "$LIME" "$RESET" "$BOLD" "$RESET"
printf '  %s7.%s  Push to your remote and share with your team!\n\n' "$LIME" "$RESET"

printf '  %sDocumentation:%s https://github.com/MagnusPladsen/ai-kit-engine\n\n' "$DIM" "$RESET"

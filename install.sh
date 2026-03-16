#!/bin/bash
# AI Kit Engine — Install script
# Usage: bash install.sh

set -e

ENGINE_DIR="$(cd "$(dirname "$0")" && pwd)"
KIT_DIR="$ENGINE_DIR"  # default: engine IS the kit (no wrapper)

# ─── Parse flags ─────────────────────────────────────────────────────────────

MODE="install"
IS_WINDOWS=false
DRY_RUN=false
FLAG_ACTION=false  # true if --check, --update, or --dry-run was passed

for arg in "$@"; do
    case "$arg" in
        --help|-h)
            echo "Usage: bash install.sh [options]"
            echo ""
            echo "Options:"
            echo "  --check     Verify installed rules/skills are in sync with kit source"
            echo "  --update    Re-install, overwriting existing rules/skills with latest"
            echo "  --uninstall Remove all kit-installed files (with backup)"
            echo "  --list      Show installed rules, skills, and plugins"
            echo "  --dry-run   Show what would be installed without making changes"
            echo "  --kit-dir <path>  Path to content repo (set by wrapper)"
            echo "  --windows   Simulate Windows mode (for testing on macOS/Linux)"
            exit 0
            ;;
        --check)     MODE="check"; FLAG_ACTION=true ;;
        --update)    MODE="update"; FLAG_ACTION=true ;;
        --uninstall) MODE="uninstall"; FLAG_ACTION=true ;;
        --list)      MODE="list"; FLAG_ACTION=true ;;
        --dry-run)   DRY_RUN=true; FLAG_ACTION=true ;;
        --kit-dir)   :;; # value handled below
        --windows) IS_WINDOWS=true ;;
    esac
done

# Handle --kit-dir <path> (two-arg flag)
_prev=""
for arg in "$@"; do
    if [ "$_prev" = "--kit-dir" ]; then
        KIT_DIR="$arg"
    fi
    _prev="$arg"
done
unset _prev

# When invoked via wrapper (--kit-dir), ENGINE_DIR resolves to the temp
# file location. Fix it to point at the actual engine submodule directory.
if [ "$KIT_DIR" != "$ENGINE_DIR" ] && [ -d "$KIT_DIR/engine" ]; then
    ENGINE_DIR="$KIT_DIR/engine"
fi

if [ "$MODE" != "install" ] && [ "$MODE" != "update" ] && [ "$MODE" != "check" ] && [ "$MODE" != "uninstall" ] && [ "$MODE" != "manage" ] && [ "$MODE" != "list" ]; then
    MODE="install"
fi

# ─── kit.toml parsing ────────────────────────────────────────────────────────

KT_NAME="AI Kit"
KT_SHORT_NAME="AI-KIT"
KT_TAGLINE=""
KT_WATERMARK="ai-kit"
KT_CONFIG_DIR=".ai-kit"
KT_ASCII_ART_FILE=""
KT_DEFAULT_THEME="Tokyo Night"
KT_DEFAULTS_RULES=true
KT_DEFAULTS_SKILLS=true
KT_DEFAULTS_REGISTRY=true
KT_DEFAULTS_PROFILES=true

# Stacks — parallel arrays
_STACK_KEYS=()
_STACK_NAMES=()
_STACK_DETECT=()
_STACK_RULES_DIRS=()
_STACK_ACTIVE=()

# Custom themes — parallel arrays
_CT_NAMES=()
_CT_LIME=()
_CT_TEAL=()
_CT_GOLD=()

# Wrapper files
_WRAPPER_FILES=("CLAUDE.md" "COPILOT.md" "CURSOR.md" "CODEX.md" "GEMINI.md" "OPENCODE.md" "CRUSH.md")

# Global symlinks — parallel arrays
_SYM_KEYS=()
_SYM_NAMES=()
_SYM_CLI=()
_SYM_ALT_CLI=()
_SYM_PATHS=()  # serialized as "src1|dst1,src2|dst2"

_parse_kit_toml() {
    local file="$1"
    [ -f "$file" ] || return 0 0

    local section="" subsection="" stack_key="" sym_key=""
    local in_paths_array=false
    local paths_buf=""
    local ct_name="" ct_lime="" ct_teal="" ct_gold=""
    local in_ct=false  # tracking if we've started a [[custom_themes]] block

    while IFS= read -r line || [ -n "$line" ]; do
        # Strip line-level comments (lines starting with # after optional whitespace)
        # For value lines, # inside quotes is preserved by not stripping mid-line
        if [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        # Trim leading/trailing whitespace
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [ -z "$line" ] && continue

        # Detect [[double bracket]] sections
        if [[ "$line" =~ ^\[\[([a-z_]+)\]\]$ ]]; then
            local dbl_section="${BASH_REMATCH[1]}"
            if [ "$dbl_section" = "custom_themes" ]; then
                # Flush previous theme if any
                if [ "$in_ct" = true ] && [ -n "$ct_name" ]; then
                    _CT_NAMES+=("$ct_name")
                    _CT_LIME+=("$ct_lime")
                    _CT_TEAL+=("$ct_teal")
                    _CT_GOLD+=("$ct_gold")
                fi
                in_ct=true
                ct_name="" ct_lime="" ct_teal="" ct_gold=""
                section="custom_themes"
                subsection=""
            fi
            continue
        fi

        # Detect [single bracket] sections
        if [[ "$line" =~ ^\[([a-z_.]+)\]$ ]]; then
            # Flush any open paths array from previous symlink section
            if [ "$in_paths_array" = true ]; then
                in_paths_array=false
                # Remove trailing comma from paths_buf
                paths_buf="${paths_buf%,}"
                _SYM_PATHS+=("$paths_buf")
                paths_buf=""
            fi
            # Flush last custom_themes block if switching away
            if [ "$in_ct" = true ] && [ -n "$ct_name" ]; then
                _CT_NAMES+=("$ct_name")
                _CT_LIME+=("$ct_lime")
                _CT_TEAL+=("$ct_teal")
                _CT_GOLD+=("$ct_gold")
                in_ct=false
                ct_name="" ct_lime="" ct_teal="" ct_gold=""
            fi

            local full="${BASH_REMATCH[1]}"
            if [[ "$full" =~ ^stacks\.(.+)$ ]]; then
                section="stacks"
                stack_key="${BASH_REMATCH[1]}"
                _STACK_KEYS+=("$stack_key")
                _STACK_NAMES+=("")
                _STACK_DETECT+=("")
                _STACK_RULES_DIRS+=("")
                _STACK_ACTIVE+=(true)
            elif [[ "$full" =~ ^global_symlinks\.(.+)$ ]]; then
                section="global_symlinks"
                sym_key="${BASH_REMATCH[1]}"
                _SYM_KEYS+=("$sym_key")
                _SYM_NAMES+=("")
                _SYM_CLI+=("")
                _SYM_ALT_CLI+=("")
                paths_buf=""
            else
                section="$full"
                subsection=""
            fi
            continue
        fi

        # Parse key = value
        if [[ "$line" =~ ^([a-z_]+)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local val="${BASH_REMATCH[2]}"

            # Strip surrounding quotes from string values
            if [[ "$val" =~ ^\"(.*)\"$ ]]; then
                val="${BASH_REMATCH[1]}"
            fi

            case "$section" in
                branding)
                    case "$key" in
                        name)           KT_NAME="$val" ;;
                        short_name)     KT_SHORT_NAME="$val" ;;
                        tagline)        KT_TAGLINE="$val" ;;
                        watermark)      KT_WATERMARK="$val" ;;
                        config_dir)     KT_CONFIG_DIR="$val" ;;
                        ascii_art_file) KT_ASCII_ART_FILE="$val" ;;
                    esac
                    ;;
                settings)
                    case "$key" in
                        default_theme) KT_DEFAULT_THEME="$val" ;;
                    esac
                    ;;
                defaults)
                    case "$key" in
                        rules)    KT_DEFAULTS_RULES="$val" ;;
                        skills)   KT_DEFAULTS_SKILLS="$val" ;;
                        registry) KT_DEFAULTS_REGISTRY="$val" ;;
                        profiles) KT_DEFAULTS_PROFILES="$val" ;;
                    esac
                    ;;
                stacks)
                    local idx=$(( ${#_STACK_KEYS[@]} - 1 ))
                    case "$key" in
                        name)
                            _STACK_NAMES[$idx]="$val"
                            ;;
                        detect)
                            # Parse array: ["a", "b"] → "a,b"
                            local arr_val="$val"
                            arr_val="${arr_val#\[}"
                            arr_val="${arr_val%\]}"
                            # Remove quotes and spaces
                            arr_val="$(echo "$arr_val" | sed 's/"//g; s/ *, */,/g; s/^ *//; s/ *$//')"
                            _STACK_DETECT[$idx]="$arr_val"
                            ;;
                        rules_dir)
                            _STACK_RULES_DIRS[$idx]="$val"
                            ;;
                    esac
                    ;;
                wrapper_files)
                    if [ "$key" = "items" ]; then
                        local arr_val="$val"
                        arr_val="${arr_val#\[}"
                        arr_val="${arr_val%\]}"
                        arr_val="$(echo "$arr_val" | sed 's/"//g; s/ *, */,/g; s/^ *//; s/ *$//')"
                        IFS=',' read -ra _WRAPPER_FILES <<< "$arr_val"
                    fi
                    ;;
                global_symlinks)
                    local idx=$(( ${#_SYM_KEYS[@]} - 1 ))
                    case "$key" in
                        name)    _SYM_NAMES[$idx]="$val" ;;
                        cli)     _SYM_CLI[$idx]="$val" ;;
                        alt_cli) _SYM_ALT_CLI[$idx]="$val" ;;
                        paths)
                            # Could be single-line: paths = [{ src = "...", dst = "..." }]
                            # or multi-line starting with [
                            if [[ "$val" =~ ^\[ ]] && [[ "$val" =~ \]$ ]] && [[ "$val" =~ \{ ]]; then
                                # Single-line array of objects
                                local objs="$val"
                                objs="${objs#\[}"
                                objs="${objs%\]}"
                                local plist=""
                                while [[ "$objs" =~ \{[[:space:]]*src[[:space:]]*=[[:space:]]*\"([^\"]+)\"[[:space:]]*,[[:space:]]*dst[[:space:]]*=[[:space:]]*\"([^\"]+)\"[[:space:]]*\} ]]; do
                                    [ -n "$plist" ] && plist="${plist},"
                                    plist="${plist}${BASH_REMATCH[1]}|${BASH_REMATCH[2]}"
                                    objs="${objs#*\}}"
                                done
                                _SYM_PATHS+=("$plist")
                            elif [[ "$val" =~ ^\[$ ]] || [[ "$val" =~ ^\[ ]]; then
                                # Multi-line array starts
                                in_paths_array=true
                                paths_buf=""
                                # Check if there's content on this line after [
                                local after="${val#\[}"
                                after="${after#"${after%%[![:space:]]*}"}"
                                if [ -n "$after" ] && [[ "$after" != "]" ]]; then
                                    # Inline objects on first line
                                    while [[ "$after" =~ \{[[:space:]]*src[[:space:]]*=[[:space:]]*\"([^\"]+)\"[[:space:]]*,[[:space:]]*dst[[:space:]]*=[[:space:]]*\"([^\"]+)\"[[:space:]]*\} ]]; do
                                        [ -n "$paths_buf" ] && paths_buf="${paths_buf},"
                                        paths_buf="${paths_buf}${BASH_REMATCH[1]}|${BASH_REMATCH[2]}"
                                        after="${after#*\}}"
                                    done
                                fi
                            fi
                            ;;
                    esac
                    ;;
                custom_themes)
                    case "$key" in
                        name) ct_name="$val" ;;
                        lime|teal|gold)
                            # Parse RGB array: [200, 214, 75] → "200,214,75"
                            local rgb="$val"
                            rgb="${rgb#\[}"
                            rgb="${rgb%\]}"
                            rgb="$(echo "$rgb" | sed 's/ //g')"
                            case "$key" in
                                lime) ct_lime="$rgb" ;;
                                teal) ct_teal="$rgb" ;;
                                gold) ct_gold="$rgb" ;;
                            esac
                            ;;
                    esac
                    ;;
            esac
            continue
        fi

        # Handle multi-line paths array entries
        if [ "$in_paths_array" = true ]; then
            # Check for closing bracket
            if [[ "$line" =~ ^\] ]]; then
                in_paths_array=false
                paths_buf="${paths_buf%,}"
                _SYM_PATHS+=("$paths_buf")
                paths_buf=""
                continue
            fi
            # Parse { src = "...", dst = "..." }
            if [[ "$line" =~ \{[[:space:]]*src[[:space:]]*=[[:space:]]*\"([^\"]+)\"[[:space:]]*,[[:space:]]*dst[[:space:]]*=[[:space:]]*\"([^\"]+)\"[[:space:]]*\} ]]; then
                [ -n "$paths_buf" ] && paths_buf="${paths_buf},"
                paths_buf="${paths_buf}${BASH_REMATCH[1]}|${BASH_REMATCH[2]}"
            fi
        fi
    done < "$file"

    # Flush any remaining open state
    if [ "$in_paths_array" = true ]; then
        paths_buf="${paths_buf%,}"
        _SYM_PATHS+=("$paths_buf")
    fi
    if [ "$in_ct" = true ] && [ -n "$ct_name" ]; then
        _CT_NAMES+=("$ct_name")
        _CT_LIME+=("$ct_lime")
        _CT_TEAL+=("$ct_teal")
        _CT_GOLD+=("$ct_gold")
    fi
}

# Parse kit.toml (content repo config)
if [ -f "$KIT_DIR/kit.toml" ]; then
    _parse_kit_toml "$KIT_DIR/kit.toml"
elif [ -f "$ENGINE_DIR/defaults/kit.toml" ]; then
    _parse_kit_toml "$ENGINE_DIR/defaults/kit.toml"
fi

# ─── Stack helper functions ───────────────────────────────────────────────────

_stack_index() {
    local key="$1"
    for i in "${!_STACK_KEYS[@]}"; do
        [ "${_STACK_KEYS[$i]}" = "$key" ] && echo "$i" && return
    done
    echo "-1"
}

_stack_active() {
    local key="$1"
    local idx=$(_stack_index "$key")
    [ "$idx" -ge 0 ] && [ "${_STACK_ACTIVE[$idx]}" = true ]
}

_activate_stack() {
    local key="$1"
    local idx=$(_stack_index "$key")
    [ "$idx" -ge 0 ] && _STACK_ACTIVE[$idx]=true
}

_activate_all_stacks() {
    for i in "${!_STACK_ACTIVE[@]}"; do _STACK_ACTIVE[$i]=true; done
}

_stack_name_by_key() {
    local key="$1"
    local idx=$(_stack_index "$key")
    [ "$idx" -ge 0 ] && echo "${_STACK_NAMES[$idx]}"
}

# Compatibility: map stack arrays to legacy booleans
_sync_legacy_stacks() {
    HAS_REACT=false; HAS_DOTNET=false; HAS_INTEGRATIONS=false
    for _si in "${!_STACK_KEYS[@]}"; do
        if [ "${_STACK_ACTIVE[$_si]}" = true ]; then
            case "${_STACK_KEYS[$_si]}" in
                react) HAS_REACT=true ;;
                dotnet) HAS_DOTNET=true ;;
                integrations) HAS_INTEGRATIONS=true ;;
            esac
        fi
    done
}

# ─── Platform detection ──────────────────────────────────────────────────────

if [ "$IS_WINDOWS" = false ]; then
    case "$(uname -s)" in
        CYGWIN*|MINGW*|MSYS*|Windows_NT*)
            IS_WINDOWS=true
            ;;
    esac
fi

# ─── Colors ──────────────────────────────────────────────────────────────────

RESET=$'\033[0m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
FAINT=$'\033[38;2;80;80;80m'   # weaker than DIM for unselected non-matches
WHITE=$'\033[97m'

# Semantic colors (constant across all themes)
GREEN=$'\033[38;2;100;210;140m'     # success green
RED=$'\033[38;2;220;80;80m'         # error red
WARN=$'\033[38;2;220;180;60m'       # warning yellow

# ─── Theme engine ────────────────────────────────────────────────────────────

# Interpolate 8 gradient stops between two RGB colors
# Usage: make_gradient R1 G1_c B1 R2 G2_c B2
make_gradient() {
    local r1=$1 g1=$2 b1=$3 r2=$4 g2=$5 b2=$6
    local i
    for i in 0 1 2 3 4 5 6 7; do
        local r=$(( r1 + (r2 - r1) * i / 7 ))
        local g=$(( g1 + (g2 - g1) * i / 7 ))
        local b=$(( b1 + (b2 - b1) * i / 7 ))
        eval "G$((i+1))=\$'\\033[38;2;${r};${g};${b}m'"
    done
}

# Set theme colors: LIME (primary), TEAL (secondary), GOLD (mid-tone), G1-G8 (gradient)
# Usage: set_theme "Theme Name"
CURRENT_THEME="$KT_DEFAULT_THEME"
set_theme() {
    CURRENT_THEME="$1"
    case "$1" in
        "Tokyo Night")
            LIME=$'\033[38;2;158;206;106m'   TEAL=$'\033[38;2;125;207;255m'  GOLD=$'\033[38;2;224;175;104m'
            make_gradient 158 206 106  125 207 255 ;;
        "Monokai Pro")
            LIME=$'\033[38;2;166;226;46m'    TEAL=$'\033[38;2;102;217;239m'  GOLD=$'\033[38;2;230;219;116m'
            make_gradient 166 226 46  102 217 239 ;;
        "GitHub Dark")
            LIME=$'\033[38;2;126;231;135m'   TEAL=$'\033[38;2;121;192;255m'  GOLD=$'\033[38;2;210;153;34m'
            make_gradient 126 231 135  121 192 255 ;;
        "Rider Dark")
            LIME=$'\033[38;2;106;185;89m'    TEAL=$'\033[38;2;104;151;187m'  GOLD=$'\033[38;2;204;120;50m'
            make_gradient 106 185 89  104 151 187 ;;
        "Dracula")
            LIME=$'\033[38;2;80;250;123m'    TEAL=$'\033[38;2;139;233;253m'  GOLD=$'\033[38;2;241;250;140m'
            make_gradient 80 250 123  139 233 253 ;;
        "One Dark")
            LIME=$'\033[38;2;152;195;121m'   TEAL=$'\033[38;2;86;182;194m'   GOLD=$'\033[38;2;229;192;123m'
            make_gradient 152 195 121  86 182 194 ;;
        "Catppuccin")
            LIME=$'\033[38;2;166;227;161m'   TEAL=$'\033[38;2;137;220;235m'  GOLD=$'\033[38;2;249;226;175m'
            make_gradient 166 227 161  137 220 235 ;;
        "Nord")
            LIME=$'\033[38;2;163;190;140m'   TEAL=$'\033[38;2;136;192;208m'  GOLD=$'\033[38;2;235;203;139m'
            make_gradient 163 190 140  136 192 208 ;;
        "Gruvbox")
            LIME=$'\033[38;2;184;187;38m'    TEAL=$'\033[38;2;131;165;152m'  GOLD=$'\033[38;2;250;189;47m'
            make_gradient 184 187 38  131 165 152 ;;
        "Solarized")
            LIME=$'\033[38;2;133;153;0m'     TEAL=$'\033[38;2;42;161;152m'   GOLD=$'\033[38;2;181;137;0m'
            make_gradient 133 153 0  42 161 152 ;;
        *)
            for _cti in "${!_CT_NAMES[@]}"; do
                if [ "${_CT_NAMES[$_cti]}" = "$1" ]; then
                    local _lr _lg _lb _tr _tg _tb _gr _gg _gb
                    IFS=',' read -r _lr _lg _lb <<< "${_CT_LIME[$_cti]}"
                    IFS=',' read -r _tr _tg _tb <<< "${_CT_TEAL[$_cti]}"
                    IFS=',' read -r _gr _gg _gb <<< "${_CT_GOLD[$_cti]}"
                    LIME=$'\033[38;2;'"${_lr};${_lg};${_lb}m"
                    TEAL=$'\033[38;2;'"${_tr};${_tg};${_tb}m"
                    GOLD=$'\033[38;2;'"${_gr};${_gg};${_gb}m"
                    make_gradient "$_lr" "$_lg" "$_lb" "$_tr" "$_tg" "$_tb"
                    break
                fi
            done
            ;;
    esac
}

# Available themes list (custom themes first, then built-ins)
THEMES=()
for _ctn in "${_CT_NAMES[@]}"; do THEMES+=("$_ctn"); done
THEMES+=("Tokyo Night" "Monokai Pro" "GitHub Dark" "Rider Dark" "Dracula" "One Dark" "Catppuccin" "Nord" "Gruvbox" "Solarized")

# ─── Settings file ────────────────────────────────────────────────────────────
# Simple TOML-like key = "value" store, human-editable

ABARIS_CONFIG="$HOME/$KT_CONFIG_DIR/.config"

# Read a value from config. Returns empty string if key not found.
# Usage: val=$(config_read "theme")
config_read() {
    local key="$1"
    if [ ! -f "$ABARIS_CONFIG" ]; then echo ""; return; fi
    local line
    line=$(grep -E "^${key} *= *" "$ABARIS_CONFIG" 2>/dev/null | head -1)
    if [ -z "$line" ]; then echo ""; return; fi
    # Strip key, equals, quotes, whitespace
    echo "$line" | sed 's/^[^=]*= *//; s/^"//; s/"$//'
}

# Write a value to config. Creates file if needed. Updates existing key or appends.
# Usage: config_write "theme" "Tokyo Night"
config_write() {
    local key="$1" value="$2"
    mkdir -p "$(dirname "$ABARIS_CONFIG")"
    if [ ! -f "$ABARIS_CONFIG" ]; then
        printf '# %s settings\n' "$KT_NAME" > "$ABARIS_CONFIG"
    fi
    if grep -qE "^${key} *= *" "$ABARIS_CONFIG" 2>/dev/null; then
        # Update existing key (portable sed -i)
        local tmp="${ABARIS_CONFIG}.tmp"
        sed "s|^${key} *= *.*|${key} = \"${value}\"|" "$ABARIS_CONFIG" > "$tmp" && mv "$tmp" "$ABARIS_CONFIG"
    else
        printf '%s = "%s"\n' "$key" "$value" >> "$ABARIS_CONFIG"
    fi
}

# Initialize theme from config (or default to kit default)
_saved_theme=$(config_read "theme")
if [ -n "$_saved_theme" ]; then
    set_theme "$_saved_theme"
else
    set_theme "$KT_DEFAULT_THEME"
fi
unset _saved_theme

bar() {
    echo "${TEAL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

STEP_NUM=0
START_TIME=$(date +%s)

progress_bar() {
    local current=$1 total=$2 width=20
    local filled=$((current * width / total))
    local empty=$((width - filled))
    local bar_filled="" bar_empty=""
    for ((i=0; i<filled; i++)); do bar_filled+="█"; done
    for ((i=0; i<empty; i++)); do bar_empty+="░"; done
    printf "\r  ${TEAL}[${GREEN}%s${DIM}%s${TEAL}]${RESET} ${BOLD}%d/%d${RESET}" "$bar_filled" "$bar_empty" "$current" "$total"
}

spinner() {
    local pid=$1 msg=$2
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local i=0
    tput civis 2>/dev/null
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${TEAL}%s${RESET} %s" "${frames[$((i % 10))]}" "$msg"
        i=$((i + 1))
        sleep 0.1
    done
    tput cnorm 2>/dev/null
    printf "\r  ${GREEN}✓${RESET} %s\n" "$msg"
}

ENV_LINE=""
init_env_line() {
    DETECTED_OS="$(uname -s)"
    case "$DETECTED_OS" in
        Darwin*)  OS_LABEL="macOS" ;;
        Linux*)   OS_LABEL="Linux" ;;
        CYGWIN*)  OS_LABEL="Windows (Cygwin)" ;;
        MINGW*)   OS_LABEL="Windows (Git Bash)" ;;
        MSYS*)    OS_LABEL="Windows (MSYS)" ;;
        *)        OS_LABEL="$DETECTED_OS" ;;
    esac
    if [ "$IS_WINDOWS" = true ] && [ "$OS_LABEL" = "macOS" -o "$OS_LABEL" = "Linux" ]; then
        OS_LABEL="$OS_LABEL ${DIM}(--windows)${RESET}"
    fi
    ENV_LINE="  ${DIM}OS:${RESET} ${BOLD}${OS_LABEL}${RESET}  ${DIM}|${RESET}  ${DIM}Shell:${RESET} ${BOLD}bash ${BASH_VERSION%%(*}${RESET}  ${DIM}|${RESET}  ${DIM}Theme:${RESET} ${BOLD}${LIME}${CURRENT_THEME}${RESET}  ${DIM}[t to change]${RESET}"
}

show_logo() {
    echo ""
    if [ -n "$KT_ASCII_ART_FILE" ] && [ -f "$KIT_DIR/$KT_ASCII_ART_FILE" ]; then
        local _i=0
        while IFS= read -r _line || [ -n "$_line" ]; do
            local _ci=$((_i % 8 + 1))
            local _color="G${_ci}"
            printf '%s%s%s%s\n' "${!_color}" "$BOLD" "  $_line" "$RESET"
            _i=$((_i + 1))
        done < "$KIT_DIR/$KT_ASCII_ART_FILE"
    else
        echo "${G1}${BOLD}   ${KT_SHORT_NAME}${RESET}"
    fi
    echo ""
    # Space out the short name for the subtitle (e.g. "ABARIS" → "A B A R I S")
    local _spaced=""
    local _i
    for ((_i=0; _i<${#KT_SHORT_NAME}; _i++)); do
        [ $_i -gt 0 ] && _spaced+=" "
        _spaced+="${KT_SHORT_NAME:$_i:1}"
    done
    echo "${G6}${BOLD}   ─── ${_spaced} ───${RESET}  ${DIM}v${KIT_VERSION}${RESET}"
    echo ""
}

# ─── Theme picker (callable from any step via 't' key) ──────────────────────

theme_picker() {
    local prev_theme="$CURRENT_THEME"
    local count=${#THEMES[@]}
    local cursor=0

    # Find current theme index
    for i in "${!THEMES[@]}"; do
        if [ "${THEMES[$i]}" = "$CURRENT_THEME" ]; then cursor=$i; break; fi
    done

    # Full-screen redraw with live preview
    _tp_redraw_screen() {
        clear
        show_logo
        init_env_line
        echo "$ENV_LINE"
        echo ""
        bar
        echo "  ${BOLD}${LIME}THEME${RESET}  ${DIM}—  Pick a color theme for this session${RESET}"
        bar
        echo ""
        echo "  ${BOLD}${WHITE}Select a theme:${RESET}"
        echo ""
        for i in "${!THEMES[@]}"; do
            set_theme "${THEMES[$i]}"
            if [ "$i" = "$cursor" ]; then
                printf '  %s▸%s %s%s%s  %s●%s %s●%s %s●%s\n' "$LIME" "$RESET" "$BOLD" "${THEMES[$i]}" "$RESET" "$LIME" "$RESET" "$GOLD" "$RESET" "$TEAL" "$RESET"
            else
                printf '  %s  %s  %s●%s %s●%s %s●%s\n' "$DIM" "${THEMES[$i]}" "$LIME" "$RESET" "$GOLD" "$RESET" "$TEAL" "$RESET"
            fi
        done
        # Apply the hovered theme for the hints line too
        set_theme "${THEMES[$cursor]}"
        echo ""
        printf '  %s↑↓ move  ⏎ select  ← / b cancel%s\n' "$DIM" "$RESET"
    }

    _tp_redraw_screen

    printf '%s' "$HIDE_CURSOR"
    trap 'printf "%s" "$SHOW_CURSOR"' EXIT

    while true; do
        IFS= read -rsn1 key
        if [ "$key" = "" ]; then
            # Enter — confirm selection
            set_theme "${THEMES[$cursor]}"
            config_write "theme" "${THEMES[$cursor]}"
            break
        elif [ "$key" = "b" ] || [ "$key" = "B" ]; then
            set_theme "$prev_theme"
            break
        elif [ "$key" = $'\x1b' ]; then
            local arrow
            arrow=$(read_arrow)
            case "$arrow" in
                up)
                    if [ "$cursor" -gt 0 ]; then cursor=$((cursor - 1)); else cursor=$((count - 1)); fi
                    set_theme "${THEMES[$cursor]}"
                    _tp_redraw_screen
                    ;;
                down)
                    if [ "$cursor" -lt $((count - 1)) ]; then cursor=$((cursor + 1)); else cursor=0; fi
                    set_theme "${THEMES[$cursor]}"
                    _tp_redraw_screen
                    ;;
                left)
                    set_theme "$prev_theme"
                    break
                    ;;
            esac
        fi
    done

    printf '%s' "$SHOW_CURSOR"
    trap - EXIT
}

step_header() {
    local title="$1"
    if [ -n "${2:-}" ]; then
        STEP_NUM=$2
    else
        STEP_NUM=$((STEP_NUM + 1))
    fi
    if [ -t 0 ]; then
        clear
    fi
    show_logo
    init_env_line
    echo "$ENV_LINE"
    echo ""
    bar
    echo "  ${BOLD}${LIME}STEP ${STEP_NUM}  —  ${title}${RESET}"
    bar
    echo ""
}

# ─── Windows greeting ─────────────────────────────────────────────────────────

if [ "$IS_WINDOWS" = true ]; then
    echo ""
    echo "  ${WARN}Waaaaat...${RESET} you're on ${BOLD}Windows${RESET}?! ${LIME}For real??${RESET}"
    echo "  Well... ${DIM}your loss.${RESET} But hey, we'll make it work anyway."
    echo ""
    echo "  ${DIM}(Symlinks won't work — files will be copied instead)${RESET}"
    echo ""
fi

# ─── Init version and env ─────────────────────────────────────────────────────

KIT_VERSION="$(cat "$KIT_DIR/VERSION" 2>/dev/null || echo "unknown")"
init_env_line
show_logo

# ─── What's New ──────────────────────────────────────────────────────────────

_last_ver=$(config_read "last_version")
if [ -n "$_last_ver" ] && [ "$_last_ver" != "$KIT_VERSION" ] && [ -f "$KIT_DIR/CHANGELOG.md" ] && [ "$IS_TTY" = true ]; then
    echo "  ${LIME}${BOLD}What's new since v${_last_ver}:${RESET}"
    echo ""
    _show=false
    while IFS= read -r line; do
        # Start showing at current version, stop at last_version
        if echo "$line" | grep -qE "^## "; then
            _ver=$(echo "$line" | sed 's/^## //')
            if [ "$_ver" = "$_last_ver" ]; then break; fi
            _show=true
            echo "  ${TEAL}${BOLD}v${_ver}${RESET}"
            continue
        fi
        if [ "$_show" = true ] && [ -n "$line" ]; then
            echo "  ${DIM}${line}${RESET}"
        fi
    done < "$KIT_DIR/CHANGELOG.md"
    echo ""
    bar
    echo ""
    read -rsn1 -p "  ${DIM}Press any key to continue...${RESET}"
    echo ""
    clear
    show_logo
fi
config_write "last_version" "$KIT_VERSION"

# ─── Engine update notification ──────────────────────────────────────────────
ENGINE_VERSION="$(cat "$ENGINE_DIR/VERSION" 2>/dev/null || echo "unknown")"
_last_engine_ver=$(config_read "last_engine_version")
if [ -n "$_last_engine_ver" ] && [ "$_last_engine_ver" != "$ENGINE_VERSION" ] && [ "$IS_TTY" = true ]; then
    echo "  ${TEAL}⬆${RESET}  Engine updated: ${DIM}v${_last_engine_ver}${RESET} → ${BOLD}${LIME}v${ENGINE_VERSION}${RESET}"
    echo ""
fi
config_write "last_engine_version" "$ENGINE_VERSION"
unset _last_ver _show _ver _last_engine_ver

# ─── Check mode: verify sync status and exit ─────────────────────────────────

if [ "$MODE" = "check" ]; then
    echo "  ${BOLD}${WHITE}Checking sync status...${RESET}"
    echo ""

    # Detect target directory
    if [ -d "$HOME/$KT_CONFIG_DIR/.claude" ]; then
        CHECK_DIR="$HOME/$KT_CONFIG_DIR"
        echo "  ${DIM}Checking global install at ~/$KT_CONFIG_DIR/${RESET}"
    elif [ -d "$(pwd)/.claude/rules" ]; then
        CHECK_DIR="$(pwd)"
        echo "  ${DIM}Checking project install at $(pwd)/${RESET}"
    else
        echo "  ${RED}✗${RESET} No ${KT_NAME} installation found."
        echo "  ${DIM}Run: bash install.sh${RESET}"
        exit 1
    fi
    echo ""

    out_of_sync=0
    in_sync=0

    # Check rules (from both engine defaults and content repo)
    _check_rule() {
        local kit_rule="$1"
        [ -f "$kit_rule" ] || return 0
        local name
        name=$(basename "$kit_rule")
        local installed="$CHECK_DIR/.claude/rules/$name"
        if [ -f "$installed" ]; then
            if diff -q "$kit_rule" "$installed" >/dev/null 2>&1; then
                in_sync=$((in_sync + 1))
            elif [ -L "$installed" ]; then
                in_sync=$((in_sync + 1))
            else
                echo "  ${WARN}↻${RESET} ${name} ${DIM}(out of date)${RESET}"
                out_of_sync=$((out_of_sync + 1))
            fi
        fi
    }
    for _rule_base in "$ENGINE_DIR/defaults/rules" "$KIT_DIR/rules"; do
        for kit_rule in "$_rule_base"/*/*.md; do
            _check_rule "$kit_rule"
        done
    done

    # Check skills (from both engine defaults and content repo)
    _check_skill() {
        local kit_skill="$1"
        [ -f "$kit_skill" ] || return 0
        local name
        name=$(basename "$(dirname "$kit_skill")")
        local installed="$CHECK_DIR/.claude/skills/$name/SKILL.md"
        if [ -f "$installed" ]; then
            if diff -q "$kit_skill" "$installed" >/dev/null 2>&1; then
                in_sync=$((in_sync + 1))
            elif [ -L "$installed" ]; then
                in_sync=$((in_sync + 1))
            else
                echo "  ${WARN}↻${RESET} skills/${name} ${DIM}(out of date)${RESET}"
                out_of_sync=$((out_of_sync + 1))
            fi
        fi
    }
    for _skill_base in "$ENGINE_DIR/defaults/skills" "$KIT_DIR/skills"; do
        for kit_skill in "$_skill_base"/*/SKILL.md; do
            _check_skill "$kit_skill"
        done
    done

    if [ "$in_sync" -eq 0 ] && [ "$out_of_sync" -eq 0 ]; then
        echo "  ${DIM}No installed rules or skills found.${RESET}"
        echo "  ${DIM}Run: bash install.sh${RESET}"
        exit 1
    elif [ "$out_of_sync" -eq 0 ]; then
        echo "  ${GREEN}✓${RESET} All ${in_sync} installed files are in sync."
    else
        echo ""
        echo "  ${WARN}${out_of_sync} file(s) out of date${RESET}, ${GREEN}${in_sync} in sync${RESET}"
        echo "  ${DIM}Run: bash install.sh --update${RESET}"
        exit 1
    fi
    exit 0
fi

# ─── List mode (--list) ─────────────────────────────────────────────────────

if [ "$MODE" = "list" ]; then
    # Detect install location
    if [ -d "$HOME/$KT_CONFIG_DIR/.claude" ]; then
        LIST_DIR="$HOME/$KT_CONFIG_DIR"
        echo "  ${DIM}Global install at ~/$KT_CONFIG_DIR/${RESET}"
    elif [ -d "$(pwd)/.claude/rules" ]; then
        LIST_DIR="$(pwd)"
        echo "  ${DIM}Project install at $(pwd)/${RESET}"
    else
        echo "  No ${KT_NAME} installation found."
        exit 1
    fi
    echo ""

    echo "  Rules:"
    found_rules=0
    for f in "$LIST_DIR"/.claude/rules/*.md; do
        [ -f "$f" ] || continue
        name=$(basename "$f" .md)
        echo "    ● $name"
        found_rules=$((found_rules + 1))
    done
    [ "$found_rules" -eq 0 ] && echo "    (none)"
    echo ""

    echo "  Skills:"
    found_skills=0
    for f in "$LIST_DIR"/.claude/skills/*/SKILL.md; do
        [ -f "$f" ] || continue
        name=$(basename "$(dirname "$f")")
        echo "    ● /$name"
        found_skills=$((found_skills + 1))
    done
    [ "$found_skills" -eq 0 ] && echo "    (none)"
    echo ""

    echo "  Total: ${found_rules} rules, ${found_skills} skills"
    exit 0
fi

# ─── Token counting ──────────────────────────────────────────────────────────
# Estimate token count from file (words x 1.3, rounded)
count_tokens() {
    local words
    words=$(wc -w < "$1" 2>/dev/null | tr -d ' ')
    echo $(( (words * 13 + 5) / 10 ))
}

# Total tokens for all rules in a category directory (checks both engine defaults and content repo)
count_category_tokens() {
    local total=0
    # Engine defaults
    if [ "$KT_DEFAULTS_RULES" = true ] && [ -d "$ENGINE_DIR/defaults/rules/$1" ]; then
        for f in "$ENGINE_DIR/defaults/rules/$1"/*.md; do
            [ -f "$f" ] || continue
            total=$((total + $(count_tokens "$f")))
        done
    fi
    # Content repo (wrapper mode)
    if [ "$KIT_DIR" != "$ENGINE_DIR" ] && [ -d "$KIT_DIR/rules/$1" ]; then
        for f in "$KIT_DIR"/rules/"$1"/*.md; do
            [ -f "$f" ] || continue
            total=$((total + $(count_tokens "$f")))
        done
    fi
    echo $total
}

# ─── Uninstall mode ──────────────────────────────────────────────────────────

if [ "$MODE" = "uninstall" ]; then
    echo "  ${BOLD}${WHITE}Uninstalling...${RESET}"
    echo ""

    # Detect where the kit is installed
    if [ -d "$HOME/$KT_CONFIG_DIR/.claude" ]; then
        UNINST_DIR="$HOME/$KT_CONFIG_DIR"
        echo "  ${DIM}Found global install at ~/$KT_CONFIG_DIR/${RESET}"
    elif [ -d "$(pwd)/.claude/rules" ]; then
        UNINST_DIR="$(pwd)"
        echo "  ${DIM}Found project install at $(pwd)/${RESET}"
    else
        echo "  ${RED}✗${RESET} No ${KT_NAME} installation found."
        exit 1
    fi
    echo ""

    removed=0

    # Helper: safely remove a file, restoring .before-${KT_WATERMARK} backup if it exists
    safe_remove() {
        local file="$1"
        local label="$2"
        local bak="${file}.before-${KT_WATERMARK}"

        if [ ! -f "$file" ] && [ ! -L "$file" ]; then return; fi

        if [ -f "$bak" ]; then
            mv "$bak" "$file"
            echo "  ${GREEN}↩${RESET} $label ${DIM}(restored original)${RESET}"
        else
            rm -f "$file"
            echo "  ${RED}✗${RESET} $label ${DIM}(removed)${RESET}"
        fi
        removed=$((removed + 1))
    }

    # Remove rules installed by kit (from both engine defaults and content repo)
    for _rule_base in "$ENGINE_DIR/defaults/rules" "$KIT_DIR/rules"; do
        for kit_rule in "$_rule_base"/*/*.md; do
            [ -f "$kit_rule" ] || continue
            name=$(basename "$kit_rule")
            safe_remove "$UNINST_DIR/.claude/rules/$name" "rules/$name"
        done
    done

    # Remove skills installed by kit (from both engine defaults and content repo)
    for _skill_base in "$ENGINE_DIR/defaults/skills" "$KIT_DIR/skills"; do
        for kit_skill in "$_skill_base"/*/SKILL.md; do
            [ -f "$kit_skill" ] || continue
            skill_name=$(basename "$(dirname "$kit_skill")")
            safe_remove "$UNINST_DIR/.claude/skills/$skill_name/SKILL.md" "skills/$skill_name"
            rmdir "$UNINST_DIR/.claude/skills/$skill_name" 2>/dev/null
        done
    done

    # Remove AI tool files (only if they match kit AGENT.md content)
    for name in AGENT.md "${_WRAPPER_FILES[@]}"; do
        target="$UNINST_DIR/$name"
        if [ -f "$target" ]; then
            if diff -q "$KIT_DIR/AGENT.md" "$target" >/dev/null 2>&1; then
                safe_remove "$target" "$name"
            else
                echo "  ${DIM}· $name (has custom content — kept)${RESET}"
            fi
        fi
    done

    # Remove plugins and MCP servers (if claude CLI is available)
    if command -v claude >/dev/null 2>&1; then
        # Uninstall plugins from registry
        for _pi in "${!_REG_PLUGIN_NAMES[@]}"; do
            _pn="${_REG_PLUGIN_NAMES[$_pi]}"
            echo -n "  Removing plugin ${WHITE}${_pn}${RESET}... "
            if claude plugin remove "$_pn" >/dev/null 2>&1; then
                echo "${GREEN}✓${RESET}"
                removed=$((removed + 1))
            else
                echo "${DIM}(not installed)${RESET}"
            fi
        done
        # Remove MCP servers from registry
        for _mi in "${!_REG_MCP_NAMES[@]}"; do
            _mn="${_REG_MCP_NAMES[$_mi]}"
            echo -n "  Removing MCP server ${WHITE}${_mn}${RESET}... "
            if claude mcp remove "$_mn" >/dev/null 2>&1; then
                echo "${GREEN}✓${RESET}"
                removed=$((removed + 1))
            else
                echo "${DIM}(not installed)${RESET}"
            fi
        done
        echo ""
    fi

    # Remove global symlinks if this was a global install
    if [ "$UNINST_DIR" = "$HOME/$KT_CONFIG_DIR" ]; then
        # Claude Code symlinks
        for f in "$HOME/.claude/CLAUDE.md" "$HOME/.claude/rules/"*.md "$HOME/.claude/skills/"*/SKILL.md; do
            if [ -L "$f" ]; then
                link_target=$(readlink "$f")
                if echo "$link_target" | grep -q "$KT_CONFIG_DIR" 2>/dev/null; then
                    rm "$f"
                    echo "  ${RED}✗${RESET} $(echo "$f" | sed "s|$HOME|~|") ${DIM}(symlink removed)${RESET}"
                    removed=$((removed + 1))
                fi
            fi
        done
        # Other tool symlinks
        for f in "$HOME/.gemini/GEMINI.md" "$HOME/.codex/AGENTS.md" \
                 "$HOME/.codeium/windsurf/memories/global_rules.md" \
                 "$HOME/.config/opencode/AGENTS.md" \
                 "$HOME/.config/crush/CRUSH.md"; do
            if [ -L "$f" ]; then
                link_target=$(readlink "$f")
                if echo "$link_target" | grep -q "$KT_CONFIG_DIR" 2>/dev/null; then
                    # Restore backup if exists
                    bak="${f}.before-${KT_WATERMARK}"
                    if [ -f "$bak" ]; then
                        mv "$bak" "$f"
                        echo "  ${GREEN}↩${RESET} $(echo "$f" | sed "s|$HOME|~|") ${DIM}(restored original)${RESET}"
                    else
                        rm "$f"
                        echo "  ${RED}✗${RESET} $(echo "$f" | sed "s|$HOME|~|") ${DIM}(symlink removed)${RESET}"
                    fi
                    removed=$((removed + 1))
                fi
            fi
        done
    fi

    echo ""
    bar
    echo ""
    echo "  ${BOLD}${LIME}✓ Uninstalled ${removed} file(s)${RESET}"
    echo ""
    if [ "$UNINST_DIR" = "$HOME/$KT_CONFIG_DIR" ]; then
        echo "  ${DIM}The ~/$KT_CONFIG_DIR/ directory was left in place.${RESET}"
        echo "  ${DIM}Remove it manually if you want: rm -rf ~/$KT_CONFIG_DIR${RESET}"
    fi
    echo ""
    bar
    echo ""
    exit 0
fi


# ─── Dry-run helper ──────────────────────────────────────────────────────────

if [ "$DRY_RUN" = true ]; then
    echo "  ${WARN}DRY RUN${RESET} — no files will be modified"
    echo ""
fi

do_cp() {
    local src="$1"
    local dst="$2"

    # If dst is a directory, append the filename
    if [ -d "$dst" ]; then
        dst="$dst/$(basename "$src")"
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "  ${DIM}would copy: $(basename "$src") → $dst${RESET}"
        return
    fi

    # Back up existing file if it differs from source
    if [ -f "$dst" ]; then
        if ! diff -q "$src" "$dst" >/dev/null 2>&1; then
            local bak="${dst}.before-${KT_WATERMARK}"
            if [ ! -f "$bak" ]; then
                cp "$dst" "$bak"
                echo "  ${DIM}backed up: $(basename "$dst") → $(basename "$bak")${RESET}"
            fi
        fi
    fi

    cp "$src" "$dst"
}

do_mkdir() {
    if [ "$DRY_RUN" = false ]; then
        mkdir -p "$1"
    fi
}

# ─── TUI helpers ─────────────────────────────────────────────────────────────

# Global arrays for checkbox token display (set before calling checkbox_select)
CB_TOKENS=()      # token count per item (empty = no token display)
CB_INSTALLED=()    # 1 if already installed, 0 if not
CB_HEAVY=()        # 1 if heavy/recommended item

HIDE_CURSOR=$'\033[?25l'
SHOW_CURSOR=$'\033[?25h'
CLEAR_LINE=$'\033[2K'
MOVE_UP=$'\033[A'

if [ -t 0 ]; then IS_TTY=true; else IS_TTY=false; fi

# Read arrow key escape sequences (bash 3 compatible)
# Terminal emulators send escape sequences atomically, so bytes are buffered
read_arrow() {
    local key2="" key3=""
    read -rsn1 -t 1 key2
    read -rsn1 -t 1 key3
    if [ "$key2" = "[" ]; then
        case "$key3" in
            A) echo "up" ;;
            B) echo "down" ;;
            D) echo "left" ;;
            *) echo "" ;;
        esac
    fi
}

# ─── single_select: arrow keys + Enter for single choice ─────────────────────
# Usage: single_select "Header" "Option 1" "Description 1" "Option 2" "Description 2" ...
# Sets SELECTED_INDEX (0-based) and SELECTED_ITEM

single_select() {
    local header="$1"
    shift

    local labels=()
    local descs=()
    while [ $# -gt 0 ]; do
        labels[${#labels[@]}]="$1"
        descs[${#descs[@]}]="${2:-}"
        shift
        [ $# -gt 0 ] && shift
    done

    local count=${#labels[@]}
    local cursor=0

    echo "  ${BOLD}${WHITE}$header${RESET}"
    echo ""

    # Fallback for piped input
    if [ "$IS_TTY" = false ]; then
        for i in "${!labels[@]}"; do
            if [ -n "${descs[$i]}" ]; then
                echo "  ${LIME}$((i + 1)))${RESET} ${BOLD}${labels[$i]}${RESET}  ${DIM}${descs[$i]}${RESET}"
            else
                echo "  ${LIME}$((i + 1)))${RESET} ${BOLD}${labels[$i]}${RESET}"
            fi
        done
        echo ""
        read -rp "  ${TEAL}>${RESET} " choice
        SELECTED_INDEX=$((choice - 1))
        if [ "$SELECTED_INDEX" -lt 0 ] || [ "$SELECTED_INDEX" -ge "$count" ]; then
            SELECTED_INDEX=0
        fi
        SELECTED_ITEM="${labels[$SELECTED_INDEX]}"
        echo ""
        echo "  ${GREEN}✓${RESET} ${SELECTED_ITEM}"
        echo ""
        return
    fi

    local help_lines=2

    _ss_draw_row() {
        local i=$1
        if [ "$i" = "$cursor" ]; then
            if [ -n "${descs[$i]}" ]; then
                printf '  %s▸%s %s%s%s  %s%s%s\n' "$LIME" "$RESET" "$BOLD" "${labels[$i]}" "$RESET" "$DIM" "${descs[$i]}" "$RESET"
            else
                printf '  %s▸%s %s%s%s\n' "$LIME" "$RESET" "$BOLD" "${labels[$i]}" "$RESET"
            fi
        else
            if [ -n "${descs[$i]}" ]; then
                printf '  %s  %s  %s%s%s\n' "$DIM" "${labels[$i]}" "" "${descs[$i]}" "$RESET"
            else
                printf '  %s  %s%s\n' "$DIM" "${labels[$i]}" "$RESET"
            fi
        fi
    }

    local _ss_help="↑↓ move  ⏎ select  ← / b back"
    if [ "${STEP_NUM:-0}" = "1" ]; then
        _ss_help="↑↓ move  ⏎ select  t theme  ← / b back"
    fi

    _ss_draw() {
        local total=$((count + help_lines))
        for ((j=0; j<total; j++)); do
            printf '%s%s\r' "$MOVE_UP" "$CLEAR_LINE"
        done
        for i in "${!labels[@]}"; do _ss_draw_row "$i"; done
        echo ""
        printf '  %s%s%s\n' "$DIM" "$_ss_help" "$RESET"
    }

    for i in "${!labels[@]}"; do _ss_draw_row "$i"; done
    echo ""
    printf '  %s%s%s\n' "$DIM" "$_ss_help" "$RESET"

    printf '%s' "$HIDE_CURSOR"
    trap 'printf "%s" "$SHOW_CURSOR"' EXIT

    SELECTED_ITEM=""
    while true; do
        IFS= read -rsn1 key
        if [ "$key" = "" ]; then
            break
        elif [ "$key" = "t" ] || [ "$key" = "T" ]; then
            if [ "${STEP_NUM:-0}" = "1" ]; then
                SELECTED_ITEM="__THEME__"
                break
            fi
        elif [ "$key" = "b" ] || [ "$key" = "B" ]; then
            SELECTED_ITEM="__BACK__"
            break
        elif [ "$key" = $'\x1b' ]; then
            local arrow
            arrow=$(read_arrow)
            case "$arrow" in
                up)
                    if [ "$cursor" -gt 0 ]; then cursor=$((cursor - 1)); else cursor=$((count - 1)); fi
                    _ss_draw
                    ;;
                down)
                    if [ "$cursor" -lt $((count - 1)) ]; then cursor=$((cursor + 1)); else cursor=0; fi
                    _ss_draw
                    ;;
                left)
                    SELECTED_ITEM="__BACK__"
                    break
                    ;;
            esac
        fi
    done

    printf '%s' "$SHOW_CURSOR"
    trap - EXIT

    local total=$((count + help_lines))
    for ((j=0; j<total; j++)); do
        printf '%s%s\r' "$MOVE_UP" "$CLEAR_LINE"
    done

    if [ "$SELECTED_ITEM" = "__BACK__" ]; then
        echo "  ${DIM}← Back${RESET}"
        echo ""
        return
    fi
    if [ "$SELECTED_ITEM" = "__THEME__" ]; then
        return
    fi
    SELECTED_INDEX=$cursor
    SELECTED_ITEM="${labels[$cursor]}"
    echo "  ${GREEN}✓${RESET} ${SELECTED_ITEM}"
    echo ""
}

# ─── Fuzzy match: characters appear in order (not contiguous) ─────────────────
# Usage: fuzzy_match "query" "text" → returns 0 (match) or 1 (no match)
fuzzy_match() {
    local query="$1" text="$2"
    local q t
    q=$(printf '%s' "$query" | tr '[:upper:]' '[:lower:]')
    t=$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]')
    local qi=0 ti=0 qlen=${#q} tlen=${#t}
    while [ $qi -lt $qlen ] && [ $ti -lt $tlen ]; do
        if [ "${q:$qi:1}" = "${t:$ti:1}" ]; then qi=$((qi+1)); fi
        ti=$((ti+1))
    done
    [ $qi -eq $qlen ]
}

# ─── checkbox_select: arrow keys + space for multi-choice ────────────────────
# Usage: checkbox_select "Header" "item1" "item2" ... [-- "default1" "default2"]
# Sets SELECTED array

checkbox_select() {
    local header="$1"
    shift

    local items=()
    local defaults=()
    local reading_defaults=false

    for arg in "$@"; do
        if [ "$arg" = "--" ]; then
            reading_defaults=true
            continue
        fi
        if [ "$reading_defaults" = true ]; then
            defaults[${#defaults[@]}]="$arg"
        else
            items[${#items[@]}]="$arg"
        fi
    done

    local selected=()
    for i in "${!items[@]}"; do
        selected[$i]=1
        if [ ${#defaults[@]} -gt 0 ]; then
            local found=false
            for d in "${defaults[@]}"; do
                if [ "$d" = "${items[$i]}" ]; then found=true; break; fi
            done
            if [ "$found" = false ]; then selected[$i]=0; fi
        fi
    done

    echo "  ${BOLD}${WHITE}$header${RESET}"
    echo ""

    # Fallback for piped input
    if [ "$IS_TTY" = false ]; then
        for i in "${!items[@]}"; do
            if [ "${selected[$i]}" = 1 ]; then
                echo "  ${GREEN}[✓]${RESET} ${WHITE}$((i + 1)))${RESET} ${items[$i]}"
            else
                echo "  ${DIM}[ ]${RESET} ${WHITE}$((i + 1)))${RESET} ${DIM}${items[$i]}${RESET}"
            fi
        done
        echo ""
        echo "  ${DIM}Toggle by number (e.g. 1,3). Press Enter to confirm.${RESET}"
        echo ""
        read -rp "  ${TEAL}>${RESET} " toggle_input
        if [ -n "$toggle_input" ]; then
            IFS=',' read -ra toggles <<< "$toggle_input"
            for t in "${toggles[@]}"; do
                t=$(echo "$t" | tr -d ' ')
                if ! [[ "$t" =~ ^[0-9]+$ ]]; then continue; fi
                idx=$((t - 1))
                if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#items[@]}" ]; then
                    if [ "${selected[$idx]}" = 1 ]; then selected[$idx]=0; else selected[$idx]=1; fi
                fi
            done
        fi
        SELECTED=()
        echo ""
        for i in "${!items[@]}"; do
            if [ "${selected[$i]}" = 1 ]; then
                SELECTED[${#SELECTED[@]}]="${items[$i]}"
                echo "  ${GREEN}✓${RESET} ${items[$i]}"
            fi
        done
        if [ ${#SELECTED[@]} -eq 0 ]; then echo "  ${DIM}(none selected)${RESET}"; fi
        echo ""
        return
    fi

    # Interactive TUI
    local cursor=0
    local count=${#items[@]}
    local has_tokens=false
    if [ ${#CB_TOKENS[@]} -gt 0 ]; then has_tokens=true; fi
    local help_lines=2
    if [ "$has_tokens" = true ]; then help_lines=3; fi

    # Search state
    local _cb_search=""
    local _cb_searching=false
    local _cb_order=()       # display order (indices into items[])
    local _cb_matched=()     # 1=matches search, 0=doesn't
    for i in "${!items[@]}"; do _cb_order+=($i); _cb_matched+=( 1); done

    _cb_reorder() {
        _cb_order=()
        _cb_matched=()
        if [ -z "$_cb_search" ]; then
            for i in "${!items[@]}"; do _cb_order+=($i); _cb_matched+=(1); done
            return
        fi
        local matches=() nonmatches=()
        for i in "${!items[@]}"; do
            if fuzzy_match "$_cb_search" "${items[$i]}"; then
                matches+=($i)
            else
                nonmatches+=($i)
            fi
        done
        _cb_order=("${matches[@]}" "${nonmatches[@]}")
        _cb_matched=()
        for i in "${!items[@]}"; do _cb_matched[$i]=0; done
        for m in "${matches[@]}"; do _cb_matched[$m]=1; done
    }

    _cb_token_suffix() {
        local i=$1
        if [ "$has_tokens" = false ] || [ -z "${CB_TOKENS[$i]:-}" ]; then return; fi
        local tk=${CB_TOKENS[$i]}
        local is_inst=${CB_INSTALLED[$i]:-0}
        local is_heavy=${CB_HEAVY[$i]:-0}
        local name_len=${#items[$i]}
        local pad=$((38 - name_len))
        [ $pad -lt 2 ] && pad=2
        local sp=""
        for ((p=0; p<pad; p++)); do sp+=" "; done
        if [ "$is_inst" = 1 ] && [ "${selected[$i]}" = 0 ]; then
            # Unchecking an installed item → red minus
            printf '%s%s−~%d tk%s' "$sp" "$RED" "$tk" "$RESET"
        elif [ "$is_inst" = 1 ]; then
            # Already installed and still checked → dim with green dot
            printf '%s%s~%d tk %s●%s' "$sp" "$DIM" "$tk" "$GREEN" "$RESET"
        elif [ "${selected[$i]}" = 1 ] && [ "$is_heavy" = 1 ]; then
            # New heavy plugin selected → yellow bolt + green plus
            printf '%s%s⚡%s %s+~%d tk%s' "$sp" "$WARN" "$RESET" "$GREEN" "$tk" "$RESET"
        elif [ "${selected[$i]}" = 1 ]; then
            # New item selected → green plus
            printf '%s%s+~%d tk%s' "$sp" "$GREEN" "$tk" "$RESET"
        else
            # New item not selected → dim
            printf '%s%s~%d tk%s' "$sp" "$DIM" "$tk" "$RESET"
        fi
    }

    _cb_token_total() {
        if [ "$has_tokens" = false ]; then return; fi
        local tk_total=0
        for i in "${!items[@]}"; do
            local tk=${CB_TOKENS[$i]:-0}
            if [ "${selected[$i]}" = 1 ] && [ "${CB_INSTALLED[$i]:-0}" = 0 ]; then
                tk_total=$((tk_total + tk))
            elif [ "${selected[$i]}" = 0 ] && [ "${CB_INSTALLED[$i]:-0}" = 1 ]; then
                tk_total=$((tk_total - tk))
            fi
        done
        if [ $tk_total -gt 0 ]; then
            printf '  %s+~%d tokens to context%s\n' "$TEAL" "$tk_total" "$RESET"
        elif [ $tk_total -lt 0 ]; then
            printf '  %s~%d tokens from context%s\n' "$RED" "$tk_total" "$RESET"
        else
            printf '  %sno token change%s\n' "$DIM" "$RESET"
        fi
    }

    _cb_draw_row_at() {
        local pos=$1  # position in display order
        local i=${_cb_order[$pos]}
        local is_match=${_cb_matched[$i]}
        local suffix
        suffix=$(_cb_token_suffix "$i")

        if [ "$pos" = "$cursor" ]; then
            if [ "${selected[$i]}" = 1 ]; then
                printf '  %s▸ %s[✓]%s %s%s%s%s\n' "$LIME" "$GREEN" "$RESET" "$BOLD" "${items[$i]}" "$RESET" "$suffix"
            else
                printf '  %s▸ %s[ ]%s %s%s%s%s\n' "$LIME" "$DIM" "$RESET" "$BOLD" "${items[$i]}" "$RESET" "$suffix"
            fi
        elif [ "$is_match" = 0 ] && [ -n "$_cb_search" ]; then
            # Non-matching during search
            if [ "${selected[$i]}" = 1 ]; then
                printf '  %s  [✓] %s%s\n' "$DIM" "${items[$i]}" "$RESET"
            else
                printf '  %s  [ ] %s%s\n' "$FAINT" "${items[$i]}" "$RESET"
            fi
        else
            if [ "${selected[$i]}" = 1 ]; then
                printf '  %s  [✓]%s %s%s\n' "$GREEN" "$RESET" "${items[$i]}" "$suffix"
            else
                printf '  %s  [ ] %s%s%s\n' "$DIM" "${items[$i]}" "$RESET" "$suffix"
            fi
        fi
    }

    _cb_draw() {
        local search_line=0
        if [ "$_cb_searching" = true ]; then search_line=1; fi
        local total=$((count + help_lines + search_line))
        for ((j=0; j<total; j++)); do
            printf '%s%s\r' "$MOVE_UP" "$CLEAR_LINE"
        done
        if [ "$_cb_searching" = true ]; then
            printf '  %s/%s %s%s%s\n' "$TEAL" "$RESET" "$BOLD" "$_cb_search" "$RESET"
        fi
        for pos in "${!_cb_order[@]}"; do _cb_draw_row_at "$pos"; done
        _cb_token_total
        echo ""
        if [ "$_cb_searching" = true ]; then
            printf '  %stype to filter  ⏎/esc clear search  ⎵ toggle%s\n' "$DIM" "$RESET"
        else
            printf '  %s↑↓ move  ⎵ toggle  ⏎ confirm  ← / b back  / search%s\n' "$DIM" "$RESET"
        fi
    }

    for pos in "${!_cb_order[@]}"; do _cb_draw_row_at "$pos"; done
    _cb_token_total
    echo ""
    printf '  %s↑↓ move  ⎵ toggle  ⏎ confirm  ← / b back  / search%s\n' "$DIM" "$RESET"

    printf '%s' "$HIDE_CURSOR"
    trap 'printf "%s" "$SHOW_CURSOR"' EXIT

    CHECKBOX_BACK=false
    while true; do
        IFS= read -rsn1 key

        # Search mode: capture chars
        if [ "$_cb_searching" = true ]; then
            if [ "$key" = "" ]; then
                # Enter: exit search mode, keep current order
                _cb_searching=false
                _cb_draw
                continue
            elif [ "$key" = $'\x1b' ]; then
                # Could be Esc or start of arrow sequence — check for more
                local _s_arrow
                _s_arrow=$(read_arrow)
                if [ "$_s_arrow" = "up" ]; then
                    if [ "$cursor" -gt 0 ]; then cursor=$((cursor - 1)); else cursor=$((count - 1)); fi
                    _cb_draw
                elif [ "$_s_arrow" = "down" ]; then
                    if [ "$cursor" -lt $((count - 1)) ]; then cursor=$((cursor + 1)); else cursor=0; fi
                    _cb_draw
                else
                    # Plain Esc: clear search and reset order
                    _cb_search=""
                    _cb_reorder
                    cursor=0
                    _cb_searching=false
                    _cb_draw
                fi
                continue
            elif [ "$key" = $'\x7f' ] || [ "$key" = $'\x08' ]; then
                # Backspace
                if [ ${#_cb_search} -gt 0 ]; then
                    _cb_search="${_cb_search%?}"
                    _cb_reorder
                    cursor=0
                    _cb_draw
                fi
                continue
            elif [ "$key" = " " ]; then
                # Space in search mode: toggle current item
                local real_i=${_cb_order[$cursor]}
                if [ "${selected[$real_i]}" = 1 ]; then selected[$real_i]=0; else selected[$real_i]=1; fi
                _cb_draw
                continue
            else
                # Append char to search
                _cb_search="${_cb_search}${key}"
                _cb_reorder
                cursor=0
                _cb_draw
                continue
            fi
        fi

        # Normal mode
        if [ "$key" = "" ]; then
            break
        elif [ "$key" = "b" ] || [ "$key" = "B" ]; then
            CHECKBOX_BACK=true
            break
        elif [ "$key" = "/" ]; then
            _cb_searching=true
            _cb_search=""
            _cb_draw
        elif [ "$key" = " " ]; then
            local real_i=${_cb_order[$cursor]}
            if [ "${selected[$real_i]}" = 1 ]; then selected[$real_i]=0; else selected[$real_i]=1; fi
            _cb_draw
        elif [ "$key" = $'\x1b' ]; then
            local arrow
            arrow=$(read_arrow)
            case "$arrow" in
                up)
                    if [ "$cursor" -gt 0 ]; then cursor=$((cursor - 1)); else cursor=$((count - 1)); fi
                    _cb_draw
                    ;;
                down)
                    if [ "$cursor" -lt $((count - 1)) ]; then cursor=$((cursor + 1)); else cursor=0; fi
                    _cb_draw
                    ;;
                left)
                    CHECKBOX_BACK=true
                    break
                    ;;
            esac
        fi
    done

    printf '%s' "$SHOW_CURSOR"
    trap - EXIT

    local search_line_cleanup=0
    if [ "$_cb_searching" = true ]; then search_line_cleanup=1; fi
    local total=$((count + help_lines + search_line_cleanup))
    for ((j=0; j<total; j++)); do
        printf '%s%s\r' "$MOVE_UP" "$CLEAR_LINE"
    done

    if [ "$CHECKBOX_BACK" = true ]; then
        echo "  ${DIM}← Back${RESET}"
        echo ""
        return
    fi

    SELECTED=()
    for i in "${!items[@]}"; do
        if [ "${selected[$i]}" = 1 ]; then
            SELECTED[${#SELECTED[@]}]="${items[$i]}"
            echo "  ${GREEN}✓${RESET} ${items[$i]}"
        fi
    done
    if [ ${#SELECTED[@]} -eq 0 ]; then echo "  ${DIM}(none selected)${RESET}"; fi
    echo ""
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  Team config auto-detection (.${KT_WATERMARK}-config)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Parse a TOML array: items = ["a", "b", "c"] → one item per line
_parse_toml_array() {
    local file="$1" section="$2"
    local in_section=false
    while IFS= read -r line; do
        if echo "$line" | grep -qE "^\[${section}\]"; then
            in_section=true; continue
        fi
        if [ "$in_section" = true ] && echo "$line" | grep -qE "^\["; then
            break  # hit next section
        fi
        if [ "$in_section" = true ] && echo "$line" | grep -qE "^items *= *\["; then
            echo "$line" | sed 's/^items *= *\[//; s/\].*//; s/"//g' | tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep -v '^$'
        fi
    done < "$file"
}

# ── Registry parsing ──────────────────────────────────────────────────────
# Parses registry.toml into parallel arrays for plugins and MCPs.
# Called once at startup. No external dependencies.

_REG_PLUGIN_NAMES=()
_REG_PLUGIN_TOKENS=()
_REG_PLUGIN_HEAVY=()
_REG_PLUGIN_STACKS=()
_REG_MCP_NAMES=()
_REG_MCP_URLS=()

_parse_registry() {
    local file="$1"
    [ -f "$file" ] || return 0

    local section="" kind="" name=""
    while IFS= read -r line || [ -n "$line" ]; do
        # Strip comments and trim
        line="${line%%#*}"
        line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -z "$line" ] && continue

        # Section header: [plugins.name] or [mcps.name]
        if echo "$line" | grep -qE '^\['; then
            section="$(echo "$line" | sed 's/^\[//;s/\]$//')"
            kind="${section%%.*}"
            name="${section#*.}"
            if [ "$kind" = "plugins" ] && [ "$name" != "$kind" ]; then
                _REG_PLUGIN_NAMES+=("$name")
                _REG_PLUGIN_TOKENS+=(0)
                _REG_PLUGIN_HEAVY+=(0)
                _REG_PLUGIN_STACKS+=("")
            elif [ "$kind" = "mcps" ] && [ "$name" != "$kind" ]; then
                _REG_MCP_NAMES+=("$name")
                _REG_MCP_URLS+=("")
            fi
            continue
        fi

        # Key = value pairs
        local key val
        key="$(echo "$line" | sed 's/[[:space:]]*=.*//')"
        val="$(echo "$line" | sed 's/[^=]*=[[:space:]]*//')"
        val="$(echo "$val" | sed 's/^"//;s/"$//')"  # strip quotes

        if [ "$kind" = "plugins" ]; then
            local idx=$(( ${#_REG_PLUGIN_NAMES[@]} - 1 ))
            case "$key" in
                tokens) _REG_PLUGIN_TOKENS[$idx]="$val" ;;
                heavy)  [ "$val" = "true" ] && _REG_PLUGIN_HEAVY[$idx]=1 ;;
                stack)  _REG_PLUGIN_STACKS[$idx]="$val" ;;
            esac
        elif [ "$kind" = "mcps" ]; then
            local idx=$(( ${#_REG_MCP_NAMES[@]} - 1 ))
            case "$key" in
                url) _REG_MCP_URLS[$idx]="$val" ;;
            esac
        fi
    done < "$file"
}

# Registry-driven mcp_server_url() — lookup from parsed registry
mcp_server_url() {
    local name="$1"
    for i in "${!_REG_MCP_NAMES[@]}"; do
        if [ "${_REG_MCP_NAMES[$i]}" = "$name" ]; then
            echo "${_REG_MCP_URLS[$i]}"
            return
        fi
    done
    echo ""
}

# Registry-driven is_mcp_server() — check if name exists in MCP registry
is_mcp_server() {
    local name="$1"
    for i in "${!_REG_MCP_NAMES[@]}"; do
        if [ "${_REG_MCP_NAMES[$i]}" = "$name" ]; then
            return 0
        fi
    done
    return 1
}

# ── Profile parsing ───────────────────────────────────────────────────────
# Reads profiles/*.toml and populates arrays for the profile menu.

_PROFILE_FILES=()
_PROFILE_DISPLAY_NAMES=()
_PROFILE_DESCRIPTIONS=()

_discover_profiles() {
    local dir="$1"
    _PROFILE_FILES=()
    _PROFILE_DISPLAY_NAMES=()
    _PROFILE_DESCRIPTIONS=()

    [ -d "$dir" ] || return 0
    for f in "$dir"/*.toml; do
        [ -f "$f" ] || continue
        _PROFILE_FILES+=("$f")
        local name="" desc=""
        while IFS= read -r line || [ -n "$line" ]; do
            line="${line%%#*}"
            line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            # Stop at first section
            echo "$line" | grep -qE '^\[' && break
            local key val
            key="$(echo "$line" | sed 's/[[:space:]]*=.*//')"
            val="$(echo "$line" | sed 's/[^=]*=[[:space:]]*//' | sed 's/^"//;s/"$//')"
            case "$key" in
                name) name="$val" ;;
                description) desc="$val" ;;
            esac
        done < "$f"
        _PROFILE_DISPLAY_NAMES+=("${name:-$(basename "$f" .toml)}")
        _PROFILE_DESCRIPTIONS+=("${desc:-}")
    done
}

# Load a profile TOML into PROFILE_* arrays
_load_profile_toml() {
    local file="$1"
    PROFILE_STACKS=()
    PROFILE_RULES=()
    PROFILE_SKILLS=()
    PROFILE_PLUGINS=()

    # Parse stacks from top-level key
    local _raw_stacks
    _raw_stacks="$(grep -E '^stacks *=' "$file" | head -1 | sed 's/^stacks *= *\[//;s/\].*//;s/"//g')"
    IFS=',' read -ra _s_arr <<< "$_raw_stacks"
    for s in "${_s_arr[@]}"; do
        s="$(echo "$s" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -z "$s" ] && continue
        # Look up display name from _STACK_NAMES
        local _matched=false
        for _si in "${!_STACK_KEYS[@]}"; do
            if [ "${_STACK_KEYS[$_si]}" = "$s" ]; then
                PROFILE_STACKS+=("${_STACK_NAMES[$_si]}")
                _matched=true
                break
            fi
        done
        if [ "$_matched" = false ]; then
            PROFILE_STACKS+=("$s")
        fi
    done

    # Parse rules, skills, plugins arrays
    while IFS= read -r r; do PROFILE_RULES+=("$r"); done < <(_parse_toml_array "$file" "rules")
    while IFS= read -r s; do PROFILE_SKILLS+=("$s"); done < <(_parse_toml_array "$file" "skills")
    while IFS= read -r p; do PROFILE_PLUGINS+=("$p"); done < <(_parse_toml_array "$file" "plugins")
}

# Initialize registry and profiles at startup — engine defaults first, then content repo
if [ "$KT_DEFAULTS_REGISTRY" = true ] && [ -f "$ENGINE_DIR/defaults/registry.toml" ]; then
    _parse_registry "$ENGINE_DIR/defaults/registry.toml"
fi
if [ "$KIT_DIR" != "$ENGINE_DIR" ] && [ -f "$KIT_DIR/registry.toml" ]; then
    _parse_registry "$KIT_DIR/registry.toml"
fi

if [ "$KT_DEFAULTS_PROFILES" = true ] && [ -d "$ENGINE_DIR/defaults/profiles" ]; then
    _discover_profiles "$ENGINE_DIR/defaults/profiles"
fi
if [ "$KIT_DIR" != "$ENGINE_DIR" ] && [ -d "$KIT_DIR/profiles" ]; then
    _discover_profiles "$KIT_DIR/profiles"
fi

USE_TEAM_CONFIG=false
HAS_TEAM_CONFIG=false

# Pre-parse team config if present (shown as option in start menu)
if [ "$FLAG_ACTION" = false ] && [ "$IS_TTY" = true ] && [ -f "$(pwd)/.${KT_WATERMARK}-config" ]; then
    HAS_TEAM_CONFIG=true
    _tc_file="$(pwd)/.${KT_WATERMARK}-config"
    _tc_stacks=()
    while IFS= read -r s; do _tc_stacks+=("$s"); done < <(_parse_toml_array "$_tc_file" "stacks")
    _tc_rules=()
    while IFS= read -r r; do _tc_rules+=("$r"); done < <(_parse_toml_array "$_tc_file" "rules")
    _tc_skills=()
    while IFS= read -r s; do _tc_skills+=("$s"); done < <(_parse_toml_array "$_tc_file" "skills")
    _tc_plugins=()
    while IFS= read -r p; do _tc_plugins+=("$p"); done < <(_parse_toml_array "$_tc_file" "plugins")
fi

# Helper: find a rule file path by name, checking content repo then engine defaults
# Sets _found_rule_path and _found_rule_source, returns 0 if found
_find_rule_file() {
    local name="$1"
    _found_rule_path=""
    _found_rule_source=""

    # Check content repo first (wrapper mode)
    if [ "$KIT_DIR" != "$ENGINE_DIR" ]; then
        for _sk in "${_STACK_KEYS[@]}"; do
            local _si=$(_stack_index "$_sk")
            local _rd="${_STACK_RULES_DIRS[$_si]}"
            [ -z "$_rd" ] && _rd="$_sk"
            if [ -f "$KIT_DIR/rules/$_rd/$name.md" ]; then
                _found_rule_path="$KIT_DIR/rules/$_rd/$name.md"
                _found_rule_source="$_rd"
                return 0
            fi
        done
        for _cat in shared custom; do
            if [ -f "$KIT_DIR/rules/$_cat/$name.md" ]; then
                _found_rule_path="$KIT_DIR/rules/$_cat/$name.md"
                _found_rule_source="$_cat"
                return 0
            fi
        done
    fi

    # Check engine defaults
    for _sk in "${_STACK_KEYS[@]}"; do
        local _si=$(_stack_index "$_sk")
        local _rd="${_STACK_RULES_DIRS[$_si]}"
        [ -z "$_rd" ] && _rd="$_sk"
        if [ -f "$ENGINE_DIR/defaults/rules/$_rd/$name.md" ]; then
            _found_rule_path="$ENGINE_DIR/defaults/rules/$_rd/$name.md"
            _found_rule_source="$_rd"
            return 0
        fi
    done
    for _cat in shared custom; do
        if [ -f "$ENGINE_DIR/defaults/rules/$_cat/$name.md" ]; then
            _found_rule_path="$ENGINE_DIR/defaults/rules/$_cat/$name.md"
            _found_rule_source="$_cat"
            return 0
        fi
    done
    return 1
}

# Helper: apply team config selections
_apply_team_config() {
    TARGET_DIR="$(pwd)"
    INSTALL_GLOBAL=false
    # Activate stacks from team config
    for s in "${_tc_stacks[@]}"; do
        for _si in "${!_STACK_NAMES[@]}"; do
            if [[ "${_STACK_NAMES[$_si]}" == "$s"* ]] || [[ "$s" == "${_STACK_KEYS[$_si]}"* ]]; then
                _STACK_ACTIVE[$_si]=true
            fi
        done
    done
    _sync_legacy_stacks
    CHOSEN_RULES=("${_tc_rules[@]}")
    CHOSEN_RULE_NAMES=()
    CHOSEN_RULE_SOURCES=()
    CHOSEN_RULE_PATHS=()
    for r in "${_tc_rules[@]}"; do
        CHOSEN_RULE_NAMES+=("$r")
        if _find_rule_file "$r"; then
            CHOSEN_RULE_SOURCES+=("$_found_rule_source")
            CHOSEN_RULE_PATHS+=("$_found_rule_path")
        else
            CHOSEN_RULE_SOURCES+=("unknown")
            CHOSEN_RULE_PATHS+=("")
        fi
    done
    CHOSEN_SKILLS=("${_tc_skills[@]}")
    CHOSEN_PLUGINS=("${_tc_plugins[@]}")
}

# ─── Startup loading animation ────────────────────────────────────────────────
if [ "$FLAG_ACTION" = false ] && [ "$IS_TTY" = true ]; then
    _loading_frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    _loading_msgs=("Scanning rules & skills" "Loading profiles & registry" "Detecting environment")
    tput civis 2>/dev/null
    for _msg in "${_loading_msgs[@]}"; do
        for _f in 0 1 2 3 4; do
            printf "\r  ${TEAL}%s${RESET} %s" "${_loading_frames[$_f]}" "$_msg..."
            sleep 0.06
        done
        printf "\r  ${GREEN}✓${RESET} %s   \n" "$_msg"
    done
    tput cnorm 2>/dev/null
    sleep 0.2
    unset _loading_frames _loading_msgs _msg _f
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  STEP 1: What do you want to do?
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

BACK_TO_ACTION=true
while [ "$BACK_TO_ACTION" = true ]; do
BACK_TO_ACTION=false

if [ "$FLAG_ACTION" = false ] && [ "${SKIP_MENU:-false}" != true ]; then
    while true; do
        step_header "What do you want to do?" 1

        # Show team config banner if detected
        if [ "$HAS_TEAM_CONFIG" = true ]; then
            echo "  ${LIME}${BOLD}▸ Team config found${RESET}  ${DIM}(.${KT_WATERMARK}-config)${RESET}"
            echo "    ${DIM}${#_tc_rules[@]} rules, ${#_tc_skills[@]} skills, ${#_tc_plugins[@]} plugins${RESET}"
            echo ""
        fi

        if [ "$HAS_TEAM_CONFIG" = true ]; then
            single_select "Select an action:" \
                "★ Install from team config" "— Apply .${KT_WATERMARK}-config (${#_tc_rules[@]} rules, ${#_tc_skills[@]} skills, ${#_tc_plugins[@]} plugins)" \
                "Install (customize)" "— Use team config as defaults, then tweak" \
                "Install (fresh)" "— Ignore config, pick everything yourself" \
                "Delete team config" "— Remove .${KT_WATERMARK}-config from this project" \
                "Manage" "— View, add, remove, update, or check installed items" \
                "Uninstall" "— Remove all kit files (restores backups)" \
                "Exit" "— Quit installer"
        else
            single_select "Select an action:" \
                "Install" "— Fresh install (rules, skills, plugins)" \
                "Manage" "— View, add, remove, update, or check installed items" \
                "Uninstall" "— Remove all kit files (restores backups)" \
                "Exit" "— Quit installer"
        fi

        if [ "$SELECTED_ITEM" = "__BACK__" ]; then continue; fi
        if [ "$SELECTED_ITEM" = "__THEME__" ]; then
            theme_picker
            continue
        fi
        break
    done

    case "$SELECTED_ITEM" in
        "★ Install from team config")
            USE_TEAM_CONFIG=true
            _apply_team_config
            MODE="install"
            ;;
        "Install (customize)")
            _apply_team_config
            PROFILE_NAME="Team Config"
            PROFILE_RULES=("${_tc_rules[@]}")
            PROFILE_SKILLS=("${_tc_skills[@]}")
            PROFILE_PLUGINS=("${_tc_plugins[@]}")
            MODE="install"
            ;;
        "Install (fresh)"|"Install") MODE="install" ;;
        "Delete team config")
            _tc_path="$(pwd)/.${KT_WATERMARK}-config"
            echo ""
            echo "  ${BOLD}${WHITE}Delete team config?${RESET}"
            echo "  ${DIM}${_tc_path}${RESET}"
            echo ""
            single_select "Are you sure?" \
                "Yes, delete it" "— Remove .${KT_WATERMARK}-config" \
                "Cancel" "— Keep the file"
            if [ "$SELECTED_ITEM" = "Yes, delete it" ]; then
                rm -f "$_tc_path"
                HAS_TEAM_CONFIG=false
                echo ""
                echo "  ${GREEN}✓${RESET} Team config deleted."
                echo ""
                echo "  ${DIM}Press any key to continue...${RESET}"
                read -rsn1
            fi
            BACK_TO_ACTION=true
            continue
            ;;
        "Manage") MODE="manage" ;;
        "Uninstall") MODE="uninstall" ;;
        "Exit"|"__BACK__") exit 0 ;;
    esac
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  Uninstall mode (interactive)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

if [ "$MODE" = "uninstall" ] && [ "$FLAG_ACTION" = false ]; then
    echo "  ${BOLD}${WHITE}Uninstalling...${RESET}"
    echo ""
    if [ -d "$HOME/$KT_CONFIG_DIR/.claude" ]; then
        UNINST_DIR="$HOME/$KT_CONFIG_DIR"
        echo "  ${DIM}Found global install at ~/$KT_CONFIG_DIR/${RESET}"
    elif [ -d "$(pwd)/.claude/rules" ]; then
        UNINST_DIR="$(pwd)"
        echo "  ${DIM}Found project install at $(pwd)/${RESET}"
    else
        echo "  ${RED}✗${RESET} No ${KT_NAME} installation found."
        exit 1
    fi
    echo ""
    removed=0
    safe_remove() {
        local file="$1" label="$2" bak="${1}.before-${KT_WATERMARK}"
        if [ ! -f "$file" ] && [ ! -L "$file" ]; then return; fi
        if [ -f "$bak" ]; then
            mv "$bak" "$file"
            echo "  ${GREEN}↩${RESET} $label ${DIM}(restored original)${RESET}"
        else
            rm -f "$file"
            echo "  ${RED}✗${RESET} $label ${DIM}(removed)${RESET}"
        fi
        removed=$((removed + 1))
    }
    # Remove rules from both engine defaults and content repo
    for _rule_base in "$ENGINE_DIR/defaults/rules" "$KIT_DIR/rules"; do
        for kit_rule in "$_rule_base"/*/*.md; do
            [ -f "$kit_rule" ] || continue
            name=$(basename "$kit_rule")
            safe_remove "$UNINST_DIR/.claude/rules/$name" "rules/$name"
        done
    done
    # Remove skills from both engine defaults and content repo
    for _skill_base in "$ENGINE_DIR/defaults/skills" "$KIT_DIR/skills"; do
        for kit_skill in "$_skill_base"/*/SKILL.md; do
            [ -f "$kit_skill" ] || continue
            skill_name=$(basename "$(dirname "$kit_skill")")
            safe_remove "$UNINST_DIR/.claude/skills/$skill_name/SKILL.md" "skills/$skill_name"
            rmdir "$UNINST_DIR/.claude/skills/$skill_name" 2>/dev/null
        done
    done
    for name in AGENT.md "${_WRAPPER_FILES[@]}"; do
        target="$UNINST_DIR/$name"
        if [ -f "$target" ]; then
            if diff -q "$KIT_DIR/AGENT.md" "$target" >/dev/null 2>&1; then
                safe_remove "$target" "$name"
            else
                echo "  ${DIM}· $name (has custom content — kept)${RESET}"
            fi
        fi
    done
    echo ""
    bar
    echo ""
    echo "  ${BOLD}${LIME}✓ Uninstalled ${removed} file(s)${RESET}"
    echo ""
    bar
    echo ""
    echo "  ${DIM}Press ${BOLD}m${RESET}${DIM} for menu or any other key to exit${RESET}"
    read -rsn1 _key
    if [ "$_key" = "m" ] || [ "$_key" = "M" ]; then
        BACK_TO_ACTION=true
    fi
fi

if [ "$BACK_TO_ACTION" = true ]; then continue; fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  Manage mode: view installed items and add/remove
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

if [ "$MODE" = "manage" ]; then
  SKIP_MENU=false
  MANAGE_LOOP=true
  while [ "$MANAGE_LOOP" = true ]; do
    step_header "Manage" 1
    # Detect install location
    if [ -d "$HOME/$KT_CONFIG_DIR/.claude" ]; then
        MANAGE_DIR="$HOME/$KT_CONFIG_DIR"
        echo "  ${DIM}Global install at ~/$KT_CONFIG_DIR/${RESET}"
    elif [ -d "$(pwd)/.claude/rules" ]; then
        MANAGE_DIR="$(pwd)"
        echo "  ${DIM}Project install at $(pwd)/${RESET}"
    else
        echo "  ${RED}✗${RESET} No ${KT_NAME} installation found."
        echo "  ${DIM}Run install first.${RESET}"
        exit 1
    fi
    echo ""

    # Scan installed rules with token counts (both engine defaults and content repo)
    installed_rules=()
    installed_rule_labels=()
    _seen_manage_rules=()
    total_installed_tk=0
    _manage_scan_rule() {
        local kit_rule="$1"
        [ -f "$kit_rule" ] || return 0
        local name category tk pad sp
        name=$(basename "$kit_rule" .md)
        category=$(basename "$(dirname "$kit_rule")")
        # Dedup: content repo overrides engine defaults
        for _sr in "${_seen_manage_rules[@]}"; do [ "$_sr" = "$name" ] && return 0; done
        _seen_manage_rules+=("$name")
        tk=$(count_tokens "$kit_rule")
        installed_rules+=("$name")
        if [ -f "$MANAGE_DIR/.claude/rules/$name.md" ] || [ -L "$MANAGE_DIR/.claude/rules/$name.md" ]; then
            total_installed_tk=$((total_installed_tk + tk))
            pad=$((30 - ${#name} - ${#category} - 3))
            [ $pad -lt 2 ] && pad=2
            sp=""
            for ((p=0; p<pad; p++)); do sp+=" "; done
            installed_rule_labels+=("${GREEN}●${RESET} ${name} ${DIM}(${category})${RESET}${sp}${DIM}~${tk} tk${RESET}")
        else
            pad=$((30 - ${#name} - ${#category} - 3))
            [ $pad -lt 2 ] && pad=2
            sp=""
            for ((p=0; p<pad; p++)); do sp+=" "; done
            installed_rule_labels+=("${DIM}○ ${name} (${category})${sp}~${tk} tk${RESET}")
        fi
    }
    # Content repo first (takes precedence for same-named files)
    if [ "$KIT_DIR" != "$ENGINE_DIR" ]; then
        for kit_rule in "$KIT_DIR"/rules/*/*.md; do
            _manage_scan_rule "$kit_rule"
        done
    fi
    # Then engine defaults
    if [ "$KT_DEFAULTS_RULES" = true ]; then
        for kit_rule in "$ENGINE_DIR"/defaults/rules/*/*.md; do
            _manage_scan_rule "$kit_rule"
        done
    fi
    unset _seen_manage_rules

    # Scan installed skills (both engine defaults and content repo)
    installed_skills=()
    installed_skill_labels=()
    _seen_manage_skills=()
    _manage_scan_skill() {
        local kit_skill="$1"
        [ -f "$kit_skill" ] || return 0
        local name
        name=$(basename "$(dirname "$kit_skill")")
        for _ss in "${_seen_manage_skills[@]}"; do [ "$_ss" = "$name" ] && return; done
        _seen_manage_skills+=("$name")
        installed_skills+=("$name")
        if [ -f "$MANAGE_DIR/.claude/skills/$name/SKILL.md" ] || [ -L "$MANAGE_DIR/.claude/skills/$name/SKILL.md" ]; then
            installed_skill_labels+=("${GREEN}●${RESET} ${name} ${DIM}(0 tk)${RESET}")
        else
            installed_skill_labels+=("${DIM}○ ${name} (0 tk)${RESET}")
        fi
    }
    # Content repo first (takes precedence)
    if [ "$KIT_DIR" != "$ENGINE_DIR" ]; then
        for kit_skill in "$KIT_DIR"/skills/*/SKILL.md; do
            _manage_scan_skill "$kit_skill"
        done
    fi
    # Then engine defaults
    if [ "$KT_DEFAULTS_SKILLS" = true ] && [ -d "$ENGINE_DIR/defaults/skills" ]; then
        for kit_skill in "$ENGINE_DIR"/defaults/skills/*/SKILL.md; do
            _manage_scan_skill "$kit_skill"
        done
    fi
    unset _seen_manage_skills

    # Display status
    echo "  ${BOLD}${WHITE}Rules${RESET}  ${DIM}(${GREEN}●${RESET}${DIM} installed  ○ available)${RESET}  ${TEAL}~${total_installed_tk} tk in context${RESET}"
    echo ""
    for label in "${installed_rule_labels[@]}"; do
        echo "    $label"
    done
    echo ""
    echo "  ${BOLD}${WHITE}Skills${RESET}  ${DIM}(0 tokens until invoked)${RESET}"
    echo ""
    for label in "${installed_skill_labels[@]}"; do
        echo "    $label"
    done
    echo ""
    bar
    echo ""

    # Ask what to do
    single_select "What would you like to do?" \
        "Add rules/skills" "— Install additional items" \
        "Remove individual items" "— Uninstall specific rules or skills" \
        "Update" "— Re-sync installed files with latest kit version" \
        "Check sync" "— Verify installed files match kit source" \
        "Done" "— Back to main menu"

    case "$SELECTED_ITEM" in
        "Add rules/skills")
            add_items=()
            add_sources=()
            add_types=()
            CB_TOKENS=()
            CB_INSTALLED=()
            CB_HEAVY=()
            # Scan rules from both engine defaults and content repo (deduplicated)
            _seen_add_rules=()
            _manage_add_rule() {
                local kit_rule="$1"
                [ -f "$kit_rule" ] || return 0
                local name category
                name=$(basename "$kit_rule" .md)
                category=$(basename "$(dirname "$kit_rule")")
                for _sr in "${_seen_add_rules[@]}"; do [ "$_sr" = "$name" ] && return; done
                _seen_add_rules+=("$name")
                if [ ! -f "$MANAGE_DIR/.claude/rules/$name.md" ] && [ ! -L "$MANAGE_DIR/.claude/rules/$name.md" ]; then
                    add_items+=("$name (${category})")
                    add_sources+=("$kit_rule")
                    add_types+=("rule")
                    CB_TOKENS+=("$(count_tokens "$kit_rule")")
                    CB_INSTALLED+=(0)
                    CB_HEAVY+=(0)
                fi
            }
            # Content repo first (takes precedence)
            if [ "$KIT_DIR" != "$ENGINE_DIR" ]; then
                for kit_rule in "$KIT_DIR"/rules/*/*.md; do
                    _manage_add_rule "$kit_rule"
                done
            fi
            if [ "$KT_DEFAULTS_RULES" = true ]; then
                for kit_rule in "$ENGINE_DIR"/defaults/rules/*/*.md; do
                    _manage_add_rule "$kit_rule"
                done
            fi
            unset _seen_add_rules
            # Scan skills from both engine defaults and content repo (deduplicated)
            _seen_add_skills=()
            _manage_add_skill() {
                local kit_skill="$1"
                [ -f "$kit_skill" ] || return 0
                local name
                name=$(basename "$(dirname "$kit_skill")")
                for _ss in "${_seen_add_skills[@]}"; do [ "$_ss" = "$name" ] && return; done
                _seen_add_skills+=("$name")
                if [ ! -f "$MANAGE_DIR/.claude/skills/$name/SKILL.md" ] && [ ! -L "$MANAGE_DIR/.claude/skills/$name/SKILL.md" ]; then
                    add_items+=("skill: $name")
                    add_sources+=("$kit_skill")
                    add_types+=("skill")
                    CB_TOKENS+=(0)
                    CB_INSTALLED+=(0)
                    CB_HEAVY+=(0)
                fi
            }
            # Content repo first (takes precedence)
            if [ "$KIT_DIR" != "$ENGINE_DIR" ]; then
                for kit_skill in "$KIT_DIR"/skills/*/SKILL.md; do
                    _manage_add_skill "$kit_skill"
                done
            fi
            if [ "$KT_DEFAULTS_SKILLS" = true ] && [ -d "$ENGINE_DIR/defaults/skills" ]; then
                for kit_skill in "$ENGINE_DIR"/defaults/skills/*/SKILL.md; do
                    _manage_add_skill "$kit_skill"
                done
            fi
            unset _seen_add_skills
            if [ ${#add_items[@]} -eq 0 ]; then
                echo ""
                echo "  ${GREEN}✓${RESET} Everything is already installed!"
            else
                echo ""
                checkbox_select "Select items to add:" "${add_items[@]}"
                CB_TOKENS=(); CB_INSTALLED=(); CB_HEAVY=()
                added=0
                for item in "${SELECTED[@]}"; do
                    for i in "${!add_items[@]}"; do
                        if [ "${add_items[$i]}" = "$item" ]; then
                            src="${add_sources[$i]}"
                            if [ "${add_types[$i]}" = "rule" ]; then
                                do_cp "$src" "$MANAGE_DIR/.claude/rules/"
                            else
                                skill_name=$(basename "$(dirname "$src")")
                                do_mkdir "$MANAGE_DIR/.claude/skills/$skill_name"
                                do_cp "$src" "$MANAGE_DIR/.claude/skills/$skill_name/"
                            fi
                            added=$((added + 1))
                            break
                        fi
                    done
                done
                echo ""
                echo "  ${GREEN}✓${RESET} Added ${added} item(s)"
            fi
            echo ""
            echo "  ${DIM}Press any key to continue...${RESET}"
            read -rsn1
            ;;
        "Remove individual items")
            rm_items=()
            rm_paths=()
            CB_TOKENS=()
            CB_INSTALLED=()
            CB_HEAVY=()
            # Scan rules from both engine defaults and content repo (deduplicated)
            _seen_rm_rules=()
            _manage_rm_rule() {
                local kit_rule="$1"
                [ -f "$kit_rule" ] || return 0
                local name category target
                name=$(basename "$kit_rule" .md)
                category=$(basename "$(dirname "$kit_rule")")
                for _sr in "${_seen_rm_rules[@]}"; do [ "$_sr" = "$name" ] && return; done
                _seen_rm_rules+=("$name")
                target="$MANAGE_DIR/.claude/rules/$name.md"
                if [ -f "$target" ] || [ -L "$target" ]; then
                    rm_items+=("$name (${category})")
                    rm_paths+=("$target")
                    CB_TOKENS+=("$(count_tokens "$kit_rule")")
                    CB_INSTALLED+=(1)
                    CB_HEAVY+=(0)
                fi
            }
            # Content repo first (takes precedence)
            if [ "$KIT_DIR" != "$ENGINE_DIR" ]; then
                for kit_rule in "$KIT_DIR"/rules/*/*.md; do
                    _manage_rm_rule "$kit_rule"
                done
            fi
            if [ "$KT_DEFAULTS_RULES" = true ]; then
                for kit_rule in "$ENGINE_DIR"/defaults/rules/*/*.md; do
                    _manage_rm_rule "$kit_rule"
                done
            fi
            unset _seen_rm_rules
            # Scan skills from both engine defaults and content repo (deduplicated)
            _seen_rm_skills=()
            _manage_rm_skill() {
                local kit_skill="$1"
                [ -f "$kit_skill" ] || return 0
                local name target
                name=$(basename "$(dirname "$kit_skill")")
                for _ss in "${_seen_rm_skills[@]}"; do [ "$_ss" = "$name" ] && return; done
                _seen_rm_skills+=("$name")
                target="$MANAGE_DIR/.claude/skills/$name/SKILL.md"
                if [ -f "$target" ] || [ -L "$target" ]; then
                    rm_items+=("skill: $name")
                    rm_paths+=("$target")
                    CB_TOKENS+=(0)
                    CB_INSTALLED+=(1)
                    CB_HEAVY+=(0)
                fi
            }
            # Content repo first (takes precedence)
            if [ "$KIT_DIR" != "$ENGINE_DIR" ]; then
                for kit_skill in "$KIT_DIR"/skills/*/SKILL.md; do
                    _manage_rm_skill "$kit_skill"
                done
            fi
            if [ "$KT_DEFAULTS_SKILLS" = true ] && [ -d "$ENGINE_DIR/defaults/skills" ]; then
                for kit_skill in "$ENGINE_DIR"/defaults/skills/*/SKILL.md; do
                    _manage_rm_skill "$kit_skill"
                done
            fi
            unset _seen_rm_skills
            if [ ${#rm_items[@]} -eq 0 ]; then
                echo ""
                echo "  ${DIM}Nothing installed to remove.${RESET}"
            else
                echo ""
                checkbox_select "Select items to remove:" "${rm_items[@]}"
                CB_TOKENS=(); CB_INSTALLED=(); CB_HEAVY=()
                removed_count=0
                for item in "${SELECTED[@]}"; do
                    for i in "${!rm_items[@]}"; do
                        if [ "${rm_items[$i]}" = "$item" ]; then
                            path="${rm_paths[$i]}"
                            bak="${path}.before-${KT_WATERMARK}"
                            if [ -f "$bak" ]; then
                                mv "$bak" "$path"
                                echo "  ${GREEN}↩${RESET} $(basename "$path") ${DIM}(restored original)${RESET}"
                            else
                                rm -f "$path"
                                echo "  ${RED}✗${RESET} $(basename "$path") ${DIM}(removed)${RESET}"
                            fi
                            dir=$(dirname "$path")
                            rmdir "$dir" 2>/dev/null
                            removed_count=$((removed_count + 1))
                            break
                        fi
                    done
                done
                echo ""
                echo "  ${GREEN}✓${RESET} Removed ${removed_count} item(s)"
            fi
            echo ""
            echo "  ${DIM}Press any key to continue...${RESET}"
            read -rsn1
            ;;
        "Update")
            MODE="update"
            UPDATE_FROM_MANAGE=true
            ;;
        "Check sync")
            echo ""
            echo "  ${BOLD}${WHITE}Checking sync status...${RESET}"
            echo ""
            if [ -d "$HOME/$KT_CONFIG_DIR/.claude" ]; then
                CHECK_DIR="$HOME/$KT_CONFIG_DIR"
                echo "  ${DIM}Checking global install at ~/$KT_CONFIG_DIR/${RESET}"
            elif [ -d "$(pwd)/.claude/rules" ]; then
                CHECK_DIR="$(pwd)"
                echo "  ${DIM}Checking project install at $(pwd)/${RESET}"
            else
                echo "  ${RED}✗${RESET} No ${KT_NAME} installation found."
                exit 1
            fi
            echo ""
            out_of_sync=0; in_sync=0
            # Check rules from both engine defaults and content repo (deduplicated)
            _seen_sync_rules=()
            _manage_check_rule() {
                local kit_rule="$1"
                [ -f "$kit_rule" ] || return 0
                local name installed
                name=$(basename "$kit_rule")
                for _sr in "${_seen_sync_rules[@]}"; do [ "$_sr" = "$name" ] && return; done
                _seen_sync_rules+=("$name")
                installed="$CHECK_DIR/.claude/rules/$name"
                if [ -f "$installed" ]; then
                    if diff -q "$kit_rule" "$installed" >/dev/null 2>&1 || [ -L "$installed" ]; then
                        in_sync=$((in_sync + 1))
                    else
                        echo "  ${WARN}↻${RESET} ${name} ${DIM}(out of date)${RESET}"
                        out_of_sync=$((out_of_sync + 1))
                    fi
                fi
            }
            # Content repo first (takes precedence)
            if [ "$KIT_DIR" != "$ENGINE_DIR" ]; then
                for kit_rule in "$KIT_DIR"/rules/*/*.md; do
                    _manage_check_rule "$kit_rule"
                done
            fi
            if [ "$KT_DEFAULTS_RULES" = true ]; then
                for kit_rule in "$ENGINE_DIR"/defaults/rules/*/*.md; do
                    _manage_check_rule "$kit_rule"
                done
            fi
            unset _seen_sync_rules
            # Check skills from both engine defaults and content repo (deduplicated)
            _seen_sync_skills=()
            _manage_check_skill() {
                local kit_skill="$1"
                [ -f "$kit_skill" ] || return 0
                local name installed
                name=$(basename "$(dirname "$kit_skill")")
                for _ss in "${_seen_sync_skills[@]}"; do [ "$_ss" = "$name" ] && return; done
                _seen_sync_skills+=("$name")
                installed="$CHECK_DIR/.claude/skills/$name/SKILL.md"
                if [ -f "$installed" ]; then
                    if diff -q "$kit_skill" "$installed" >/dev/null 2>&1 || [ -L "$installed" ]; then
                        in_sync=$((in_sync + 1))
                    else
                        echo "  ${WARN}↻${RESET} skills/${name} ${DIM}(out of date)${RESET}"
                        out_of_sync=$((out_of_sync + 1))
                    fi
                fi
            }
            # Content repo first (takes precedence)
            if [ "$KIT_DIR" != "$ENGINE_DIR" ]; then
                for kit_skill in "$KIT_DIR"/skills/*/SKILL.md; do
                    _manage_check_skill "$kit_skill"
                done
            fi
            if [ "$KT_DEFAULTS_SKILLS" = true ] && [ -d "$ENGINE_DIR/defaults/skills" ]; then
                for kit_skill in "$ENGINE_DIR"/defaults/skills/*/SKILL.md; do
                    _manage_check_skill "$kit_skill"
                done
            fi
            unset _seen_sync_skills
            if [ "$out_of_sync" -eq 0 ]; then
                echo "  ${GREEN}✓${RESET} All ${in_sync} installed files are in sync."
            else
                echo ""
                echo "  ${WARN}${out_of_sync} file(s) out of date${RESET}, ${GREEN}${in_sync} in sync${RESET}"
                echo "  ${DIM}Select Update to re-sync${RESET}"
            fi
            echo ""
            echo "  ${DIM}Press any key to continue...${RESET}"
            read -rsn1
            ;;
        "Done"|"__BACK__")
            MANAGE_LOOP=false
            ;;
    esac

    if [ "$MODE" = "update" ]; then
        MANAGE_LOOP=false
    fi

  done  # end MANAGE_LOOP

    if [ "$MODE" != "update" ]; then
        BACK_TO_ACTION=true
        continue
    fi
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  Update mode: auto-detect and overwrite existing install
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

if [ "$MODE" = "update" ]; then
    _pre_update_ver="$KIT_VERSION"
    # Pull latest kit source if it's a git repo
    if [ -d "$KIT_DIR/.git" ]; then
        git -C "$KIT_DIR" pull --ff-only >/dev/null 2>&1 &
        pull_pid=$!
        spinner "$pull_pid" "Pulling latest kit source..."
        pull_status=0
        wait "$pull_pid" 2>/dev/null || pull_status=$?
        if [ $pull_status -ne 0 ]; then
            echo "  ${WARN}Pull failed — using local version${RESET}"
            echo "  ${DIM}Try manually: cd $KIT_DIR && git fetch && git pull${RESET}"
        fi
        echo ""
    fi

    echo "  ${BOLD}${WHITE}Updating...${RESET}"
    echo ""

    # Detect where the kit is installed
    if [ -d "$HOME/$KT_CONFIG_DIR/.claude" ]; then
        UPDATE_DIR="$HOME/$KT_CONFIG_DIR"
        echo "  ${DIM}Found global install at ~/$KT_CONFIG_DIR/${RESET}"
    elif [ -d "$(pwd)/.claude/rules" ]; then
        UPDATE_DIR="$(pwd)"
        echo "  ${DIM}Found project install at $(pwd)/${RESET}"
    else
        echo "  ${RED}✗${RESET} No ${KT_NAME} installation found."
        echo "  ${DIM}Run: bash install.sh${RESET}"
        exit 1
    fi
    echo ""

    updated=0

    # Helper: backup-aware copy for update mode
    update_file() {
        local src="$1"
        local dst="$2"
        local label="$3"
        if [ -f "$dst" ] && ! diff -q "$src" "$dst" >/dev/null 2>&1; then
            local bak="${dst}.before-${KT_WATERMARK}"
            if [ ! -f "$bak" ]; then
                cp "$dst" "$bak"
                echo "  ${DIM}backed up: $(basename "$dst") → $(basename "$bak")${RESET}"
            fi
            cp "$src" "$dst"
            echo "  ${GREEN}✓${RESET} $label ${DIM}(updated)${RESET}"
            updated=$((updated + 1))
        elif [ -f "$dst" ]; then
            echo "  ${DIM}· $label (already up to date)${RESET}"
        fi
    }

    # Update AGENT.md
    if [ -f "$UPDATE_DIR/AGENT.md" ]; then
        update_file "$KIT_DIR/AGENT.md" "$UPDATE_DIR/AGENT.md" "AGENT.md"
    fi

    # Update AI tool copies (project install)
    for name in "${_WRAPPER_FILES[@]}"; do
        if [ -f "$UPDATE_DIR/$name" ]; then
            update_file "$KIT_DIR/AGENT.md" "$UPDATE_DIR/$name" "$name"
        fi
    done

    # Update rules (check content repo first, then engine defaults)
    for installed_rule in "$UPDATE_DIR/.claude/rules/"*.md; do
        [ -f "$installed_rule" ] || continue
        name=$(basename "$installed_rule")
        _rule_updated=false
        # Content repo takes priority
        if [ "$KIT_DIR" != "$ENGINE_DIR" ]; then
            for kit_rule in "$KIT_DIR"/rules/*/"$name"; do
                if [ -f "$kit_rule" ]; then
                    update_file "$kit_rule" "$installed_rule" "rules/$name"
                    _rule_updated=true
                    break
                fi
            done
        fi
        # Fall back to engine defaults
        if [ "$_rule_updated" = false ]; then
            for kit_rule in "$ENGINE_DIR"/defaults/rules/*/"$name"; do
                if [ -f "$kit_rule" ]; then
                    update_file "$kit_rule" "$installed_rule" "rules/$name"
                    break
                fi
            done
        fi
    done

    # Update skills (check content repo first, then engine defaults)
    for installed_skill in "$UPDATE_DIR/.claude/skills/"*/SKILL.md; do
        [ -f "$installed_skill" ] || continue
        skill_name=$(basename "$(dirname "$installed_skill")")
        _skill_updated=false
        if [ "$KIT_DIR" != "$ENGINE_DIR" ] && [ -f "$KIT_DIR/skills/$skill_name/SKILL.md" ]; then
            update_file "$KIT_DIR/skills/$skill_name/SKILL.md" "$installed_skill" "skills/$skill_name"
            _skill_updated=true
        fi
        if [ "$_skill_updated" = false ] && [ -f "$ENGINE_DIR/defaults/skills/$skill_name/SKILL.md" ]; then
            update_file "$ENGINE_DIR/defaults/skills/$skill_name/SKILL.md" "$installed_skill" "skills/$skill_name"
        fi
    done

    echo ""
    bar
    echo ""
    if [ "$updated" -eq 0 ]; then
        echo "  ${BOLD}${LIME}✓ All files are already up to date${RESET}"
    else
        echo "  ${BOLD}${LIME}✓ Updated ${updated} file(s)${RESET}"
    fi
    echo ""

    # Show what's new since pre-update version
    _post_update_ver="$(cat "$KIT_DIR/VERSION" 2>/dev/null || echo "unknown")"
    if [ "$_pre_update_ver" != "$_post_update_ver" ] && [ -f "$KIT_DIR/CHANGELOG.md" ]; then
        echo "  ${LIME}${BOLD}What's new (v${_pre_update_ver} → v${_post_update_ver}):${RESET}"
        echo ""
        _show=false
        while IFS= read -r line; do
            if echo "$line" | grep -qE "^## "; then
                _ver=$(echo "$line" | sed 's/^## //')
                if [ "$_ver" = "$_pre_update_ver" ]; then break; fi
                _show=true
                echo "  ${TEAL}${BOLD}v${_ver}${RESET}"
                continue
            fi
            if [ "$_show" = true ] && [ -n "$line" ]; then
                echo "  ${DIM}${line}${RESET}"
            fi
        done < "$KIT_DIR/CHANGELOG.md"
        echo ""
        bar
        echo ""
        KIT_VERSION="$_post_update_ver"
        config_write "last_version" "$KIT_VERSION"
    fi
    unset _pre_update_ver _post_update_ver _show _ver

    if [ "${UPDATE_FROM_MANAGE:-false}" = true ]; then
        UPDATE_FROM_MANAGE=false
        echo "  ${DIM}Press any key to return to Manage...${RESET}"
        read -rsn1
        MODE="manage"
        SKIP_MENU=true
        BACK_TO_ACTION=true
        continue
    else
        echo "  ${DIM}Press ${BOLD}m${RESET}${DIM} for menu or any other key to exit${RESET}"
        read -rsn1 _key
        if [ "$_key" = "m" ] || [ "$_key" = "M" ]; then
            BACK_TO_ACTION=true
            continue
        fi
    fi
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  Install flow (with back navigation)
#  Steps: location → tools → stack → rules → skills → plugins → apply
#  Global:  steps 2,3,4,5,6,7
#  Project: steps 2,5,6,7 (tools/stack auto-detected)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Flow steps: 1=location 2=tools 3=stack 4=rules 5=skills 6=plugins 7=confirm 8=done
if [ "$USE_TEAM_CONFIG" = true ]; then
    # Team config already set CHOSEN_ arrays + TARGET_DIR — skip to confirmation
    FLOW=7
elif [ "$PROFILE_NAME" = "Team Config" ]; then
    # "Customize" from team config — keep TARGET_DIR/stacks, start at rules step
    FLOW=4
    SELECTED_TOOLS=()
    CHOSEN_RULES=()
    CHOSEN_RULE_NAMES=()
    CHOSEN_RULE_SOURCES=()
    CHOSEN_SKILLS=()
    CHOSEN_PLUGINS=()
else
    FLOW=1
    INSTALL_GLOBAL=false
    TARGET_DIR=""
    SELECTED_TOOLS=()
    HAS_REACT=false
    HAS_DOTNET=false
    HAS_INTEGRATIONS=false
    CHOSEN_RULES=()
    CHOSEN_RULE_NAMES=()
    CHOSEN_RULE_SOURCES=()
    CHOSEN_SKILLS=()
    CHOSEN_PLUGINS=()

    # Profile defaults (empty = no preset, user picks everything)
    PROFILE_NAME=""
    PROFILE_STACKS=()
    PROFILE_RULES=()
    PROFILE_SKILLS=()
    PROFILE_PLUGINS=()
fi

# Apply a named profile — sets default arrays for subsequent steps
apply_profile() {
    PROFILE_NAME="$1"

    # Special: Everything — select all discovered items
    if [ "$1" = "★ Everything" ] || [ "$1" = "Everything" ]; then
        PROFILE_STACKS=()
        for _sn in "${_STACK_NAMES[@]}"; do PROFILE_STACKS+=("$_sn"); done
        # Rules: all .md files from all categories (both sources, deduplicated)
        PROFILE_RULES=()
        local _seen_rule_names=()
        _add_profile_rule() {
            local _n="$1"
            for _sn in "${_seen_rule_names[@]}"; do
                [ "$_sn" = "$_n" ] && return
            done
            _seen_rule_names+=("$_n")
            PROFILE_RULES+=("$_n")
        }
        # Scan engine defaults
        if [ "$KT_DEFAULTS_RULES" = true ]; then
            for _si in "${!_STACK_KEYS[@]}"; do
                local _rd="${_STACK_RULES_DIRS[$_si]}"
                [ -z "$_rd" ] && _rd="${_STACK_KEYS[$_si]}"
                for _f in "$ENGINE_DIR/defaults/rules/$_rd"/*.md; do
                    [ -f "$_f" ] || continue
                    _add_profile_rule "$(basename "$_f" .md)"
                done
            done
            for _cat in shared custom; do
                for _f in "$ENGINE_DIR/defaults/rules/$_cat"/*.md; do
                    [ -f "$_f" ] || continue
                    _add_profile_rule "$(basename "$_f" .md)"
                done
            done
        fi
        # Scan content repo (wrapper mode)
        if [ "$KIT_DIR" != "$ENGINE_DIR" ]; then
            for _si in "${!_STACK_KEYS[@]}"; do
                local _rd="${_STACK_RULES_DIRS[$_si]}"
                [ -z "$_rd" ] && _rd="${_STACK_KEYS[$_si]}"
                for _f in "$KIT_DIR/rules/$_rd"/*.md; do
                    [ -f "$_f" ] || continue
                    _add_profile_rule "$(basename "$_f" .md)"
                done
            done
            for _cat in shared custom; do
                for _f in "$KIT_DIR/rules/$_cat"/*.md; do
                    [ -f "$_f" ] || continue
                    _add_profile_rule "$(basename "$_f" .md)"
                done
            done
        fi
        unset _seen_rule_names
        # Skills: all discovered skills (both sources, deduplicated)
        PROFILE_SKILLS=()
        local _seen_skill_names=()
        _add_profile_skill() {
            local _n="$1"
            for _sn in "${_seen_skill_names[@]}"; do
                [ "$_sn" = "$_n" ] && return
            done
            _seen_skill_names+=("$_n")
            PROFILE_SKILLS+=("$_n")
        }
        if [ "$KT_DEFAULTS_SKILLS" = true ] && [ -d "$ENGINE_DIR/defaults/skills" ]; then
            for _sd in "$ENGINE_DIR/defaults/skills"/*/SKILL.md; do
                [ -f "$_sd" ] || continue
                _add_profile_skill "$(basename "$(dirname "$_sd")")"
            done
        fi
        if [ "$KIT_DIR" != "$ENGINE_DIR" ]; then
            for _sd in "$KIT_DIR/skills"/*/SKILL.md; do
                [ -f "$_sd" ] || continue
                _add_profile_skill "$(basename "$(dirname "$_sd")")"
            done
        fi
        unset _seen_skill_names
        # Plugins + MCPs: everything from registry
        PROFILE_PLUGINS=()
        for _p in "${_REG_PLUGIN_NAMES[@]}"; do PROFILE_PLUGINS+=("$_p"); done
        for _m in "${_REG_MCP_NAMES[@]}"; do PROFILE_PLUGINS+=("$_m"); done
        return
    fi

    # Special: Custom — nothing preselected
    if [ "$1" = "Custom" ]; then
        PROFILE_STACKS=()
        PROFILE_RULES=()
        PROFILE_SKILLS=()
        PROFILE_PLUGINS=()
        return
    fi

    # File-based profile — find matching TOML
    for _pi in "${!_PROFILE_DISPLAY_NAMES[@]}"; do
        if [ "${_PROFILE_DISPLAY_NAMES[$_pi]}" = "$1" ]; then
            _load_profile_toml "${_PROFILE_FILES[$_pi]}"
            return
        fi
    done

    # Fallback: treat as Custom
    PROFILE_NAME="Custom"
    PROFILE_STACKS=()
    PROFILE_RULES=()
    PROFILE_SKILLS=()
    PROFILE_PLUGINS=()
}

# Apply profile selections directly (skip individual steps)
apply_profile_selections() {
    # Activate stacks from profile
    for _ps in "${PROFILE_STACKS[@]}"; do
        for _si in "${!_STACK_NAMES[@]}"; do
            if [ "${_STACK_NAMES[$_si]}" = "$_ps" ]; then
                _STACK_ACTIVE[$_si]=true
            fi
        done
    done
    _sync_legacy_stacks
    unset _ps

    # Build CHOSEN_RULES with source info (dual-source aware)
    CHOSEN_RULES=("${PROFILE_RULES[@]}")
    CHOSEN_RULE_NAMES=()
    CHOSEN_RULE_SOURCES=()
    CHOSEN_RULE_PATHS=()
    for _r in "${PROFILE_RULES[@]}"; do
        CHOSEN_RULE_NAMES+=("$_r")
        if _find_rule_file "$_r"; then
            CHOSEN_RULE_SOURCES+=("$_found_rule_source")
            CHOSEN_RULE_PATHS+=("$_found_rule_path")
        else
            CHOSEN_RULE_SOURCES+=("unknown")
            CHOSEN_RULE_PATHS+=("")
        fi
    done
    unset _r

    CHOSEN_SKILLS=("${PROFILE_SKILLS[@]}")
    CHOSEN_PLUGINS=("${PROFILE_PLUGINS[@]}")
}

# Display step number (skips hidden steps for project installs)
flow_step_num() {
    if [ "$INSTALL_GLOBAL" = true ]; then
        echo $(($1 + 2))  # flow 1→3(profile), 2→4, 3→5, 4→6, 5→7, 7→9
    else
        # project: 1→2(location), profile→3, 4→4, 5→5, 7→6
        case $1 in
            1) echo 2 ;;
            4) echo 4 ;;
            5) echo 5 ;;
            7) echo 6 ;;
        esac
    fi
}

while [ "$FLOW" -le 7 ]; do
    case $FLOW in

        1)  # ─── Install Location ────────────────────────────────────────
            step_header "Install Location" 2

            single_select "Where do you want to install?" \
                "Global  → ~/$KT_CONFIG_DIR/" "Shared across all projects. Symlink to AI tools." \
                "Project → $(pwd)/" "Install into this project only."

            if [ "$SELECTED_ITEM" = "__BACK__" ]; then
                BACK_TO_ACTION=true
                break  # Break flow loop → restart action picker
            fi

            INSTALL_GLOBAL=false
            if [ "$SELECTED_INDEX" = 0 ]; then
                INSTALL_GLOBAL=true
                TARGET_DIR="$HOME/$KT_CONFIG_DIR"
            else
                TARGET_DIR="$(pwd)"
            fi

            if [ "$INSTALL_GLOBAL" = true ]; then
                # ─── Profile selection (global only) ──────────────
                while true; do
                    step_header "Profile" 3

                    echo "  ${DIM}Profiles pre-fill your selections. You can still customize each step.${RESET}"
                    echo ""

                    _profile_args=("Start from a profile:"
                        "★ Everything" "— All rules, all skills, all plugins")
                    for _pi in "${!_PROFILE_DISPLAY_NAMES[@]}"; do
                        _profile_args+=("${_PROFILE_DISPLAY_NAMES[$_pi]}" "— ${_PROFILE_DESCRIPTIONS[$_pi]}")
                    done
                    _profile_args+=("Custom" "— Pick everything yourself")
                    single_select "${_profile_args[@]}"
                    unset _profile_args

                    break
                done
                if [ "$SELECTED_ITEM" = "__BACK__" ]; then
                    FLOW=1; continue
                fi

                apply_profile "$SELECTED_ITEM"

                if [ "$PROFILE_NAME" != "Custom" ]; then
                    # Show all stacks so all rules are visible (profile defaults handle pre-selection)
                    _activate_all_stacks
                    _sync_legacy_stacks
                fi
                FLOW=2
            else
                # Project install: auto-detect stacks from _STACK_DETECT patterns
                for _si in "${!_STACK_KEYS[@]}"; do
                    _STACK_ACTIVE[$_si]=false
                    _detect="${_STACK_DETECT[$_si]}"
                    if [ -z "$_detect" ]; then
                        _STACK_ACTIVE[$_si]=true  # no detect = always active
                        continue
                    fi
                    IFS=',' read -ra _patterns <<< "$_detect"
                    for _pat in "${_patterns[@]}"; do
                        if compgen -G "$TARGET_DIR/$_pat" >/dev/null 2>&1; then
                            _STACK_ACTIVE[$_si]=true
                            break
                        fi
                    done
                done
                _sync_legacy_stacks

                # ─── Profile selection (project) ──────────────
                while true; do
                    step_header "Profile" 3

                    echo "  ${DIM}Profiles pre-fill your selections. You can still customize each step.${RESET}"
                    echo ""

                    _profile_args=("Start from a profile:"
                        "★ Everything" "— All rules, all skills, all plugins")
                    for _pi in "${!_PROFILE_DISPLAY_NAMES[@]}"; do
                        _profile_args+=("${_PROFILE_DISPLAY_NAMES[$_pi]}" "— ${_PROFILE_DESCRIPTIONS[$_pi]}")
                    done
                    _profile_args+=("Custom" "— Pick everything yourself")
                    single_select "${_profile_args[@]}"
                    unset _profile_args

                    break
                done
                if [ "$SELECTED_ITEM" = "__BACK__" ]; then
                    FLOW=1; continue
                fi

                apply_profile "$SELECTED_ITEM"

                if [ "$PROFILE_NAME" != "Custom" ]; then
                    _activate_all_stacks
                    _sync_legacy_stacks
                fi
                FLOW=4
            fi
            ;;

        2)  # ─── AI Tool Integration (global only) ──────────────────────
            step_header "AI Tool Integration" 4

            if [ "$IS_WINDOWS" = true ]; then
                echo "  The following tools can be set up with copies"
                echo "  from their config location to ${TEAL}~/$KT_CONFIG_DIR/${RESET}:"
            else
                echo "  The following tools support automatic global symlinks"
                echo "  from their config location to ${TEAL}~/$KT_CONFIG_DIR/${RESET}:"
            fi
            echo ""
            # Build tool info table dynamically from kit.toml symlinks
            _tbl_max_name=4  # minimum "Tool" header width
            _tbl_max_path=11  # minimum "Global path" header width
            _tbl_names=()
            _tbl_paths=()
            for _si in "${!_SYM_NAMES[@]}"; do
                _tn="${_SYM_NAMES[$_si]}"
                _tbl_names+=("$_tn")
                # Build summary path from first destination
                _first_dst=""
                IFS=',' read -ra _tpp <<< "${_SYM_PATHS[$_si]}"
                if [ ${#_tpp[@]} -gt 0 ]; then
                    _first_dst="${_tpp[0]##*|}"
                    _first_dst="${_first_dst/#\~/$HOME}"
                    _first_dst="${_first_dst/#$HOME/\~}"
                    if [ ${#_tpp[@]} -gt 1 ]; then
                        _first_dst="$_first_dst + more"
                    fi
                fi
                _tbl_paths+=("$_first_dst")
                [ ${#_tn} -gt $_tbl_max_name ] && _tbl_max_name=${#_tn}
                [ ${#_first_dst} -gt $_tbl_max_path ] && _tbl_max_path=${#_first_dst}
            done
            # Pad columns (add 2 for spacing)
            _tbl_max_name=$((_tbl_max_name + 2))
            _tbl_max_path=$((_tbl_max_path + 2))
            # Print table
            printf "  ${TEAL}┌%*s┬%*s┐${RESET}\n" "$_tbl_max_name" "" "$_tbl_max_path" "" | tr ' ' '─'
            printf "  ${TEAL}│${RESET} %-*s${TEAL}│${RESET} %-*s${TEAL}│${RESET}\n" "$((_tbl_max_name - 1))" "${BOLD}Tool${RESET}" "$((_tbl_max_path - 1))" "${BOLD}Global path${RESET}"
            printf "  ${TEAL}├%*s┼%*s┤${RESET}\n" "$_tbl_max_name" "" "$_tbl_max_path" "" | tr ' ' '─'
            for _ti in "${!_tbl_names[@]}"; do
                printf "  ${TEAL}│${RESET} %-*s${TEAL}│${RESET} ${DIM}%-*s${RESET}${TEAL}│${RESET}\n" "$((_tbl_max_name - 1))" "${_tbl_names[$_ti]}" "$((_tbl_max_path - 1))" "${_tbl_paths[$_ti]}"
            done
            printf "  ${TEAL}└%*s┴%*s┘${RESET}\n" "$_tbl_max_name" "" "$_tbl_max_path" "" | tr ' ' '─'
            unset _tbl_names _tbl_paths _tbl_max_name _tbl_max_path
            echo ""
            echo "  ${DIM}These tools do NOT support global filesystem config:${RESET}"
            echo "  ${DIM}Cursor (UI settings only), Copilot (VS Code setting),${RESET}"
            echo "  ${DIM}Aider (--read flag), Amazon Q (CLI context), Cline (extension settings)${RESET}"
            echo "  ${DIM}→ For these, copy files from ~/$KT_CONFIG_DIR/ into each project manually.${RESET}"
            echo ""

            _tool_names=()
            for _si in "${!_SYM_NAMES[@]}"; do
                _tool_names+=("${_SYM_NAMES[$_si]}")
            done
            checkbox_select "Which tools should we set up symlinks for?" "${_tool_names[@]}"
            unset _tool_names

            if [ "$CHECKBOX_BACK" = true ]; then
                FLOW=1; continue
            fi

            SELECTED_TOOLS=("${SELECTED[@]}")
            if [ -n "$PROFILE_NAME" ] && [ "$PROFILE_NAME" != "Custom" ]; then
                FLOW=4  # Skip stacks (all enabled), go to rules
            else
                FLOW=3
            fi
            ;;

        3)  # ─── Stack Detection (global only) ──────────────────────────
            step_header "Stack Detection" 5

            echo "  ${DIM}Select all stacks you work with. Rules load by file type.${RESET}"
            if [ -n "$PROFILE_NAME" ] && [ "$PROFILE_NAME" != "Custom" ]; then
                echo "  ${TEAL}Profile:${RESET} ${BOLD}${PROFILE_NAME}${RESET} ${DIM}— adjust if needed${RESET}"
            fi
            echo ""

            CB_TOKENS=()
            CB_INSTALLED=()
            CB_HEAVY=()
            _stack_cb=("Select your stacks:")
            for _si in "${!_STACK_KEYS[@]}"; do
                _rd="${_STACK_RULES_DIRS[$_si]}"
                [ -z "$_rd" ] && _rd="${_STACK_KEYS[$_si]}"
                CB_TOKENS+=("$(count_category_tokens "$_rd")")
                CB_INSTALLED+=(0)
                CB_HEAVY+=(0)
                _stack_cb+=("${_STACK_NAMES[$_si]}")
            done
            if [ ${#PROFILE_STACKS[@]} -gt 0 ]; then
                _stack_cb+=("--" "${PROFILE_STACKS[@]}")
            fi
            checkbox_select "${_stack_cb[@]}"
            unset _stack_cb

            CB_TOKENS=(); CB_INSTALLED=(); CB_HEAVY=()

            if [ "$CHECKBOX_BACK" = true ]; then
                FLOW=2; continue
            fi

            # Deactivate all stacks, then activate selected ones
            for _si in "${!_STACK_ACTIVE[@]}"; do _STACK_ACTIVE[$_si]=false; done
            for item in "${SELECTED[@]}"; do
                for _si in "${!_STACK_NAMES[@]}"; do
                    if [ "${_STACK_NAMES[$_si]}" = "$item" ]; then
                        _STACK_ACTIVE[$_si]=true
                    fi
                done
            done
            _sync_legacy_stacks
            FLOW=4
            ;;

        4)  # ─── Rules ──────────────────────────────────────────────────
            step_header "Rules" "$(flow_step_num 4)"

            if [ -n "$PROFILE_NAME" ] && [ "$PROFILE_NAME" != "Custom" ]; then
                echo "  ${TEAL}Profile:${RESET} ${BOLD}${PROFILE_NAME}${RESET} ${DIM}— adjust if needed${RESET}"
                echo ""
            fi

            all_rules=()
            all_rule_sources=()
            all_rule_paths=()
            CB_TOKENS=()
            CB_INSTALLED=()
            CB_HEAVY=()

            # Helper to add a rule with token info
            _add_rule() {
                local name="$1" cat="$2" path="$3"
                local real_name
                real_name="$(echo "$name" | sed 's/ (default)$//; s/ (custom)$//')"
                all_rules+=("$name")
                all_rule_sources+=("$cat")
                all_rule_paths+=("$path")
                CB_TOKENS+=("$(count_tokens "$path")")
                if [ -f "$TARGET_DIR/.claude/rules/$real_name.md" ] || [ -L "$TARGET_DIR/.claude/rules/$real_name.md" ]; then
                    CB_INSTALLED+=(1)
                else
                    CB_INSTALLED+=(0)
                fi
                CB_HEAVY+=(0)
            }

            # Build list of rule files for a category from both engine defaults and content repo
            # Sets: _cat_files (paths), _cat_names (display names)
            _build_category_files() {
                local cat="$1"
                _cat_files=()
                _cat_names=()

                local _default_dir="$ENGINE_DIR/defaults/rules/$cat"
                local _custom_dir="$KIT_DIR/rules/$cat"
                local _default_names=()

                # Standalone mode — just scan defaults
                if [ "$KIT_DIR" = "$ENGINE_DIR" ]; then
                    if [ -d "$_default_dir" ]; then
                        for _f in "$_default_dir"/*.md; do
                            [ -f "$_f" ] || continue
                            _cat_files+=("$_f")
                            _cat_names+=("$(basename "$_f" .md)")
                        done
                    fi
                    return
                fi

                # Wrapper mode — scan defaults first (if enabled), then content repo
                if [ "$KT_DEFAULTS_RULES" = true ] && [ -d "$_default_dir" ]; then
                    for _f in "$_default_dir"/*.md; do
                        [ -f "$_f" ] || continue
                        local _n
                        _n="$(basename "$_f" .md)"
                        _default_names+=("$_n")
                        if [ -f "$_custom_dir/$_n.md" ]; then
                            _cat_files+=("$_f")
                            _cat_names+=("$_n (default)")
                        else
                            _cat_files+=("$_f")
                            _cat_names+=("$_n")
                        fi
                    done
                fi

                if [ -d "$_custom_dir" ]; then
                    for _f in "$_custom_dir"/*.md; do
                        [ -f "$_f" ] || continue
                        local _n _is_collision=false
                        _n="$(basename "$_f" .md)"
                        for _dn in "${_default_names[@]}"; do
                            if [ "$_dn" = "$_n" ]; then _is_collision=true; break; fi
                        done
                        if [ "$_is_collision" = true ]; then
                            _cat_files+=("$_f")
                            _cat_names+=("$_n (custom)")
                        else
                            _cat_files+=("$_f")
                            _cat_names+=("$_n")
                        fi
                    done
                fi
            }

            # Shared rules — always shown
            _build_category_files "shared"
            if [ ${#_cat_files[@]} -gt 0 ]; then
                echo "  ${LIME}Shared${RESET} ${DIM}(always loaded)${RESET}"
                for _ci in "${!_cat_files[@]}"; do
                    _add_rule "${_cat_names[$_ci]}" "shared" "${_cat_files[$_ci]}"
                done
            fi

            # Stack-specific rules — gated on _STACK_ACTIVE
            for _si in "${!_STACK_KEYS[@]}"; do
                if [ "${_STACK_ACTIVE[$_si]}" = true ]; then
                    _rd="${_STACK_RULES_DIRS[$_si]}"
                    [ -z "$_rd" ] && _rd="${_STACK_KEYS[$_si]}"
                    _build_category_files "$_rd"
                    if [ ${#_cat_files[@]} -gt 0 ]; then
                        _cat_tk=0
                        for _cf in "${_cat_files[@]}"; do
                            _cat_tk=$((_cat_tk + $(count_tokens "$_cf")))
                        done
                        echo "  ${LIME}${_STACK_NAMES[$_si]}${RESET} ${DIM}(up to ~${_cat_tk} tk)${RESET}"
                        for _ci in "${!_cat_files[@]}"; do
                            _add_rule "${_cat_names[$_ci]}" "$_rd" "${_cat_files[$_ci]}"
                        done
                    fi
                fi
            done

            # Custom rules (rules/custom/*.md — user-created, survives git pull)
            _build_category_files "custom"
            if [ ${#_cat_files[@]} -gt 0 ]; then
                echo "  ${LIME}Custom${RESET} ${DIM}(your team rules — rules/custom/)${RESET}"
                for _ci in "${!_cat_files[@]}"; do
                    _add_rule "${_cat_names[$_ci]}" "custom" "${_cat_files[$_ci]}"
                done
            fi

            echo ""
            echo "  ${DIM}Rules are loaded into context when editing matching files.${RESET}"
            echo ""

            _rules_cb=("Select rules to install:" "${all_rules[@]}")
            if [ ${#PROFILE_RULES[@]} -gt 0 ]; then
                _rules_cb+=("--" "${PROFILE_RULES[@]}")
            fi
            checkbox_select "${_rules_cb[@]}"
            unset _rules_cb

            CB_TOKENS=(); CB_INSTALLED=(); CB_HEAVY=()

            if [ "$CHECKBOX_BACK" = true ]; then
                if [ "$INSTALL_GLOBAL" = true ]; then
                    FLOW=3
                else
                    FLOW=1
                fi
                continue
            fi

            CHOSEN_RULES=("${SELECTED[@]}")
            CHOSEN_RULE_NAMES=("${all_rules[@]}")
            CHOSEN_RULE_SOURCES=("${all_rule_sources[@]}")
            CHOSEN_RULE_PATHS=("${all_rule_paths[@]}")
            FLOW=5
            ;;

        5)  # ─── Skills & Plugins ──────────────────────────────────────
            step_header "Skills & Plugins" "$(flow_step_num 5)"

            echo "  ${LIME}Skills${RESET} ${DIM}(0 tokens — loaded only when invoked)${RESET}"
            all_skills=()
            _seen_skill_names=()

            # Scan skills from a directory, skipping duplicates
            _scan_skills_dir() {
                local _dir="$1"
                for _sd in "$_dir"/*/SKILL.md; do
                    [ -f "$_sd" ] || continue
                    local _sk_name
                    _sk_name="$(basename "$(dirname "$_sd")")"
                    # Skip if already seen
                    local _already=false
                    for _sn in "${_seen_skill_names[@]}"; do
                        if [ "$_sn" = "$_sk_name" ]; then _already=true; break; fi
                    done
                    [ "$_already" = true ] && continue
                    # Check stack gating from frontmatter
                    local _sk_stack
                    _sk_stack="$(grep -m1 '^stack:' "$_sd" | sed 's/^stack:[[:space:]]*//')"
                    case "$_sk_stack" in
                        react)  [ "$HAS_REACT" = true ] || continue ;;
                        dotnet) [ "$HAS_DOTNET" = true ] || continue ;;
                    esac
                    all_skills+=("$_sk_name")
                    _seen_skill_names+=("$_sk_name")
                done
            }

            # Engine defaults first (standalone or wrapper with defaults enabled)
            if [ "$KT_DEFAULTS_SKILLS" = true ] && [ -d "$ENGINE_DIR/defaults/skills" ]; then
                _scan_skills_dir "$ENGINE_DIR/defaults/skills"
            fi
            # Content repo skills (wrapper mode only)
            if [ "$KIT_DIR" != "$ENGINE_DIR" ] && [ -d "$KIT_DIR/skills" ]; then
                _scan_skills_dir "$KIT_DIR/skills"
            fi
            unset _seen_skill_names

            echo "  ${LIME}Plugins${RESET} ${DIM}(external tools)${RESET}"
            echo "  ${WARN}⚡${RESET} ${DIM}= large skill, loaded on invoke (highly recommended)${RESET}"
            echo ""
            echo "  ${DIM}context7 = live docs  │  atlassian = Jira/Confluence  │  coderabbit = AI review${RESET}"
            echo "  ${DIM}commit-commands = git shortcuts  │  superpowers = TDD/debug/planning${RESET}"
            echo "  ${DIM}ui-ux-pro-max = design system + UX guidelines${RESET}"
            echo ""

            all_plugins=()
            for _pi in "${!_REG_PLUGIN_NAMES[@]}"; do
                _p_name="${_REG_PLUGIN_NAMES[$_pi]}"
                _p_stack="${_REG_PLUGIN_STACKS[$_pi]}"
                case "$_p_stack" in
                    react)  [ "$HAS_REACT" = true ] || continue ;;
                    dotnet) [ "$HAS_DOTNET" = true ] || continue ;;
                esac
                all_plugins+=("$_p_name")
            done

            all_mcps=("${_REG_MCP_NAMES[@]}")

            # Build combined list: skills first, then plugins
            _combined=()
            CB_TOKENS=()
            CB_INSTALLED=()
            CB_HEAVY=()

            for sk in "${all_skills[@]}"; do
                _combined+=("skill: $sk")
                CB_TOKENS+=(0)
                if [ -f "$TARGET_DIR/.claude/skills/$sk/SKILL.md" ] || [ -L "$TARGET_DIR/.claude/skills/$sk/SKILL.md" ]; then
                    CB_INSTALLED+=(1)
                else
                    CB_INSTALLED+=(0)
                fi
                CB_HEAVY+=(0)
            done

            for pl in "${all_plugins[@]}"; do
                _combined+=("plugin: $pl")
                _pl_tokens=0; _pl_heavy=0
                for _ri in "${!_REG_PLUGIN_NAMES[@]}"; do
                    if [ "${_REG_PLUGIN_NAMES[$_ri]}" = "$pl" ]; then
                        _pl_tokens="${_REG_PLUGIN_TOKENS[$_ri]}"
                        _pl_heavy="${_REG_PLUGIN_HEAVY[$_ri]}"
                        break
                    fi
                done
                CB_TOKENS+=("$_pl_tokens")
                CB_HEAVY+=("$_pl_heavy")
                CB_INSTALLED+=(0)
            done

            for mc in "${all_mcps[@]}"; do
                _combined+=("plugin: $mc")
                CB_TOKENS+=(0)
                CB_HEAVY+=(0)
                CB_INSTALLED+=(0)
            done

            # Build defaults from profile
            _sp_defaults=()
            for sk in "${PROFILE_SKILLS[@]}"; do _sp_defaults+=("skill: $sk"); done
            for pl in "${PROFILE_PLUGINS[@]}"; do _sp_defaults+=("plugin: $pl"); done

            _sp_cb=("Select skills and plugins:" "${_combined[@]}")
            if [ ${#_sp_defaults[@]} -gt 0 ]; then
                _sp_cb+=("--" "${_sp_defaults[@]}")
            fi
            checkbox_select "${_sp_cb[@]}"
            unset _sp_cb _combined _sp_defaults

            CB_TOKENS=(); CB_INSTALLED=(); CB_HEAVY=()

            if [ "$CHECKBOX_BACK" = true ]; then
                FLOW=4; continue
            fi

            # Split selections back into skills and plugins
            CHOSEN_SKILLS=()
            CHOSEN_PLUGINS=()
            for item in "${SELECTED[@]}"; do
                case "$item" in
                    "skill: "*) CHOSEN_SKILLS+=("${item#skill: }") ;;
                    "plugin: "*) CHOSEN_PLUGINS+=("${item#plugin: }") ;;
                esac
            done
            FLOW=7
            ;;

        7)  # ─── Confirmation ─────────────────────────────────────────────
            step_header "Confirm" "$(flow_step_num 7)"

            # Calculate token totals
            _conf_rule_tk=0
            for i in "${!CHOSEN_RULE_NAMES[@]}"; do
                for r in "${CHOSEN_RULES[@]}"; do
                    if [ "$r" = "${CHOSEN_RULE_NAMES[$i]}" ]; then
                        if [ -n "${CHOSEN_RULE_PATHS[$i]:-}" ]; then
                            _conf_rule_tk=$((_conf_rule_tk + $(count_tokens "${CHOSEN_RULE_PATHS[$i]}")))
                        else
                            _conf_rule_tk=$((_conf_rule_tk + $(count_tokens "$KIT_DIR/rules/${CHOSEN_RULE_SOURCES[$i]}/${CHOSEN_RULE_NAMES[$i]}.md")))
                        fi
                        break
                    fi
                done
            done

            _conf_plugin_tk=0
            for p in "${CHOSEN_PLUGINS[@]}"; do
                for _ri in "${!_REG_PLUGIN_NAMES[@]}"; do
                    if [ "${_REG_PLUGIN_NAMES[$_ri]}" = "$p" ]; then
                        _conf_plugin_tk=$((_conf_plugin_tk + ${_REG_PLUGIN_TOKENS[$_ri]}))
                        break
                    fi
                done
            done

            _conf_total=$((_conf_rule_tk + _conf_plugin_tk))

            # Build stack summary from active stacks
            _conf_stacks=""
            for _si in "${!_STACK_KEYS[@]}"; do
                if [ "${_STACK_ACTIVE[$_si]}" = true ]; then
                    [ -n "$_conf_stacks" ] && _conf_stacks="${_conf_stacks}, "
                    _conf_stacks="${_conf_stacks}${_STACK_NAMES[$_si]}"
                fi
            done
            [ -z "$_conf_stacks" ] && _conf_stacks="None"

            # Location label
            if [ "$INSTALL_GLOBAL" = true ]; then
                _conf_loc="~/$KT_CONFIG_DIR/ (global)"
            else
                _conf_loc="$(pwd)/ (project)"
            fi

            echo "  ${BOLD}${WHITE}Ready to install${RESET}"
            echo ""
            bar
            echo ""
            echo "  ${DIM}Location:${RESET}  ${_conf_loc}"
            echo "  ${DIM}Stacks:${RESET}    ${_conf_stacks}"
            echo "  ${DIM}Rules:${RESET}     ${#CHOSEN_RULES[@]} selected     ${DIM}~${_conf_rule_tk} tk${RESET}"
            echo "  ${DIM}Skills:${RESET}    ${#CHOSEN_SKILLS[@]} selected     ${DIM}0 tk${RESET}"
            echo "  ${DIM}Plugins:${RESET}   ${#CHOSEN_PLUGINS[@]} selected     ${DIM}~${_conf_plugin_tk} tk${RESET}"
            if [ "$INSTALL_GLOBAL" = true ]; then
                echo "  ${DIM}Tools:${RESET}     ${#SELECTED_TOOLS[@]} configured"
            fi
            echo ""
            bar
            echo ""
            echo "  ${BOLD}Total context impact: ~${_conf_total} tokens${RESET}"
            echo ""

            unset _conf_rule_tk _conf_plugin_tk _conf_total _conf_stacks _conf_loc

            single_select "What would you like to do?" \
                "Confirm & install" "— Apply selections now" \
                "Go back and adjust" "— Return to previous steps" \
                "Save as .${KT_WATERMARK}-config" "— Export selections to file"

            if [ "$SELECTED_ITEM" = "__BACK__" ]; then
                if [ "$USE_TEAM_CONFIG" = true ]; then
                    USE_TEAM_CONFIG=false
                    PROFILE_NAME="Team Config"
                    PROFILE_RULES=("${CHOSEN_RULES[@]}")
                    PROFILE_SKILLS=("${CHOSEN_SKILLS[@]}")
                    PROFILE_PLUGINS=("${CHOSEN_PLUGINS[@]}")
                    FLOW=4; continue
                fi
                FLOW=5; continue
            fi

            case "$SELECTED_ITEM" in
                "Confirm & install")
                    FLOW=8  # exit loop
                    ;;
                "Go back and adjust")
                    if [ "$USE_TEAM_CONFIG" = true ]; then
                        # Convert team config into profile defaults for manual flow
                        USE_TEAM_CONFIG=false
                        PROFILE_NAME="Team Config"
                        PROFILE_RULES=("${CHOSEN_RULES[@]}")
                        PROFILE_SKILLS=("${CHOSEN_SKILLS[@]}")
                        PROFILE_PLUGINS=("${CHOSEN_PLUGINS[@]}")
                        FLOW=4; continue  # Start from rules step
                    fi
                    FLOW=5; continue
                    ;;
                "Save as .${KT_WATERMARK}-config")
                    # Write config file
                    _cfg_file="$(pwd)/.${KT_WATERMARK}-config"
                    {
                        printf '# %s project config\n' "$KT_NAME"
                        printf '# Generated by install.sh v%s\n\n' "$KIT_VERSION"
                        printf '[stacks]\n'
                        printf 'items = ['
                        _first=true
                        if [ "$HAS_REACT" = true ]; then printf '"React"'; _first=false; fi
                        if [ "$HAS_DOTNET" = true ]; then [ "$_first" = false ] && printf ', '; printf '".NET"'; _first=false; fi
                        if [ "$HAS_INTEGRATIONS" = true ]; then [ "$_first" = false ] && printf ', '; printf '"Integrations"'; fi
                        printf ']\n\n'
                        printf '[rules]\nitems = ['
                        _first=true
                        for r in "${CHOSEN_RULES[@]}"; do
                            [ "$_first" = false ] && printf ', '
                            printf '"%s"' "$r"
                            _first=false
                        done
                        printf ']\n\n'
                        printf '[skills]\nitems = ['
                        _first=true
                        for s in "${CHOSEN_SKILLS[@]}"; do
                            [ "$_first" = false ] && printf ', '
                            printf '"%s"' "$s"
                            _first=false
                        done
                        printf ']\n\n'
                        printf '[plugins]\nitems = ['
                        _first=true
                        for p in "${CHOSEN_PLUGINS[@]}"; do
                            [ "$_first" = false ] && printf ', '
                            printf '"%s"' "$p"
                            _first=false
                        done
                        printf ']\n'
                    } > "$_cfg_file"
                    echo ""
                    echo "  ${GREEN}✓${RESET} Saved to ${BOLD}$_cfg_file${RESET}"
                    echo "  ${DIM}Commit this file so teammates can use it.${RESET}"
                    echo ""
                    unset _cfg_file _first
                    # Re-show confirmation
                    continue
                    ;;
            esac
            ;;
    esac
done

# If back was pressed on step 2, restart from action picker
if [ "$BACK_TO_ACTION" = true ]; then continue; fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  Apply selections
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

do_mkdir "$TARGET_DIR/.claude/rules"
do_mkdir "$TARGET_DIR/.claude/skills"

# Copy AGENT.md
if [ ! -f "$TARGET_DIR/AGENT.md" ] || [ "$MODE" = "update" ]; then
    do_cp "$KIT_DIR/AGENT.md" "$TARGET_DIR/AGENT.md"
fi

# Install rules
INSTALLED_RULES=0
for item in "${CHOSEN_RULES[@]}"; do
    for i in "${!CHOSEN_RULE_NAMES[@]}"; do
        if [ "${CHOSEN_RULE_NAMES[$i]}" = "$item" ]; then
            # Strip " (default)" or " (custom)" suffix for the installed filename
            _real_name="$(echo "$item" | sed 's/ (default)$//; s/ (custom)$//')"
            if [ -n "${CHOSEN_RULE_PATHS[$i]:-}" ]; then
                do_cp "${CHOSEN_RULE_PATHS[$i]}" "$TARGET_DIR/.claude/rules/$_real_name.md"
            else
                do_cp "$KIT_DIR/rules/${CHOSEN_RULE_SOURCES[$i]}/$_real_name.md" "$TARGET_DIR/.claude/rules/$_real_name.md"
            fi
            INSTALLED_RULES=$((INSTALLED_RULES + 1))
            break
        fi
    done
done

# Install skills
INSTALLED_SKILLS=0
for item in "${CHOSEN_SKILLS[@]}"; do
    do_mkdir "$TARGET_DIR/.claude/skills/$item"
    # Check content repo first, then engine defaults
    if [ "$KIT_DIR" != "$ENGINE_DIR" ] && [ -f "$KIT_DIR/skills/$item/SKILL.md" ]; then
        do_cp "$KIT_DIR/skills/$item/SKILL.md" "$TARGET_DIR/.claude/skills/$item/"
    elif [ -f "$ENGINE_DIR/defaults/skills/$item/SKILL.md" ]; then
        do_cp "$ENGINE_DIR/defaults/skills/$item/SKILL.md" "$TARGET_DIR/.claude/skills/$item/"
    elif [ -f "$KIT_DIR/skills/$item/SKILL.md" ]; then
        do_cp "$KIT_DIR/skills/$item/SKILL.md" "$TARGET_DIR/.claude/skills/$item/"
    fi
    INSTALLED_SKILLS=$((INSTALLED_SKILLS + 1))
done

# Install plugins
if [ ${#CHOSEN_PLUGINS[@]} -gt 0 ]; then
    if [ "$DRY_RUN" = true ]; then
        for item in "${CHOSEN_PLUGINS[@]}"; do
            echo "  ${DIM}would install plugin: $item${RESET}"
        done
        echo ""
    elif ! command -v claude >/dev/null 2>&1; then
        echo "  ${WARN}⚠${RESET} Claude Code CLI not found."
        echo "  ${DIM}Install from: https://docs.anthropic.com/en/docs/claude-code${RESET}"
        echo "  ${DIM}Then run: claude plugin install <name>${RESET}"
        echo ""
    else
        for item in "${CHOSEN_PLUGINS[@]}"; do
            echo -n "  Installing ${WHITE}$item${RESET}... "
            if claude plugin install "$item" >/dev/null 2>&1; then
                echo "${GREEN}✓${RESET}"
            else
                echo "${RED}✗ (failed)${RESET}"
            fi
        done
        echo ""
    fi
fi

# ─── Set up symlinks (global only) ──────────────────────────────────────────

if [ "$INSTALL_GLOBAL" = true ] && [ ${#SELECTED_TOOLS[@]} -gt 0 ]; then
    safe_link() {
        local src="$1"
        local dst="$2"

        if [ "$DRY_RUN" = true ]; then
            echo "    ${DIM}would link: $(basename "$src") → $dst${RESET}"
            return
        fi

        local dst_dir
        dst_dir=$(dirname "$dst")
        mkdir -p "$dst_dir"

        if [ -L "$dst" ]; then
            rm "$dst"
        elif [ -f "$dst" ]; then
            mv "$dst" "${dst}.before-${KT_WATERMARK}"
            echo "    ${DIM}(backed up existing ${dst} to ${dst}.before-${KT_WATERMARK})${RESET}"
        fi

        if [ "$IS_WINDOWS" = true ]; then
            cp "$src" "$dst"
        else
            ln -s "$src" "$dst"
        fi
    }

    echo ""
    echo "  ${BOLD}${WHITE}Setting up symlinks...${RESET}"
    echo ""

    for tool in "${SELECTED_TOOLS[@]}"; do
        # Find the matching symlink config from kit.toml
        _sym_idx=-1
        for _si in "${!_SYM_NAMES[@]}"; do
            if [ "${_SYM_NAMES[$_si]}" = "$tool" ]; then
                _sym_idx=$_si
                break
            fi
        done

        if [ "$_sym_idx" -ge 0 ]; then
            echo "  ${BOLD}${WHITE}${tool}:${RESET}"

            # Parse serialized paths: "src1|dst1,src2|dst2"
            IFS=',' read -ra _path_pairs <<< "${_SYM_PATHS[$_sym_idx]}"
            for _pp in "${_path_pairs[@]}"; do
                _psrc="${_pp%%|*}"
                _pdst="${_pp##*|}"
                # Expand ~ in destination
                _pdst="${_pdst/#\~/$HOME}"

                # Handle directory sources (ending with /)
                if [[ "$_psrc" == */ ]]; then
                    _src_dir="$TARGET_DIR/$_psrc"
                    _dst_dir="$_pdst"
                    if [ -d "$_src_dir" ]; then
                        mkdir -p "$_dst_dir"
                        for _f in "$_src_dir"*; do
                            [ -f "$_f" ] || [ -d "$_f" ] || continue
                            _fname="$(basename "$_f")"
                            if [ -d "$_f" ]; then
                                mkdir -p "$_dst_dir/$_fname"
                                for _sf in "$_f"/*; do
                                    [ -f "$_sf" ] || continue
                                    safe_link "$_sf" "$_dst_dir/$_fname/$(basename "$_sf")"
                                done
                            else
                                safe_link "$_f" "$_dst_dir/$_fname"
                            fi
                        done
                        echo "    ${GREEN}✓${RESET} ${_pdst/#$HOME/\~} → ~/$KT_CONFIG_DIR/$_psrc"
                    fi
                else
                    _actual_src="$TARGET_DIR/$_psrc"
                    if [ -f "$_actual_src" ]; then
                        safe_link "$_actual_src" "$_pdst"
                        echo "    ${GREEN}✓${RESET} ${_pdst/#$HOME/\~} → ~/$KT_CONFIG_DIR/$_psrc"
                    fi
                fi
            done
            echo ""
        fi
    done
fi

# ─── Project-level AI tool files (project install only) ─────────────────────

if [ "$INSTALL_GLOBAL" = false ]; then
    local_existing=()
    for name in "${_WRAPPER_FILES[@]}"; do
        if [ -f "$TARGET_DIR/$name" ]; then
            if ! diff -q "$KIT_DIR/AGENT.md" "$TARGET_DIR/$name" >/dev/null 2>&1; then
                local_existing[${#local_existing[@]}]="$name"
            fi
        else
            do_cp "$KIT_DIR/AGENT.md" "$TARGET_DIR/$name"
        fi
    done
    echo "  ${GREEN}✓${RESET} AI tool files ready"

    if [ ${#local_existing[@]} -gt 0 ]; then
        echo ""
        echo "  ${WARN}Note:${RESET} Found existing files with custom content:"
        for f in "${local_existing[@]}"; do
            echo "    ${DIM}· $f (kept as-is — your content is preserved)${RESET}"
        done
        echo "  ${DIM}Consider merging your custom rules into .claude/rules/ files${RESET}"
        echo "  ${DIM}and replacing these with the kit's AGENT.md content.${RESET}"
    fi
    echo ""
fi

# ─── Post-install summary ─────────────────────────────────────────────────────

clear
show_logo
ELAPSED=$(( $(date +%s) - START_TIME ))

if [ "$DRY_RUN" = true ]; then
    echo "  ${BOLD}${LIME}✓ Dry run complete${RESET}"
else
    echo "  ${BOLD}${LIME}✓ ${KT_NAME} installed!${RESET}"
fi
echo ""

if [ "$INSTALL_GLOBAL" = true ]; then
    _s_loc="~/$KT_CONFIG_DIR/ (global)"
else
    _s_loc="$TARGET_DIR/.claude/"
fi

echo "  ${DIM}Version:${RESET}  v${KIT_VERSION}"
echo "  ${DIM}Location:${RESET} ${_s_loc}"
echo "  ${DIM}Time:${RESET}     ${ELAPSED}s"
echo ""
bar
echo ""

# Installed rules
if [ "${INSTALLED_RULES:-0}" -gt 0 ]; then
    echo "  ${BOLD}${WHITE}Rules (${INSTALLED_RULES})${RESET}"
    for item in "${CHOSEN_RULES[@]}"; do
        echo "    ${GREEN}✓${RESET} ${item}"
    done
else
    echo "  ${DIM}Rules:  none${RESET}"
fi

# Installed skills
if [ "${INSTALLED_SKILLS:-0}" -gt 0 ]; then
    echo "  ${BOLD}${WHITE}Skills (${INSTALLED_SKILLS})${RESET}"
    for item in "${CHOSEN_SKILLS[@]}"; do
        echo "    ${GREEN}✓${RESET} ${item}"
    done
else
    echo "  ${DIM}Skills: none${RESET}"
fi

# Installed plugins
if [ ${#CHOSEN_PLUGINS[@]} -gt 0 ]; then
    echo "  ${BOLD}${WHITE}Plugins (${#CHOSEN_PLUGINS[@]})${RESET}"
    for item in "${CHOSEN_PLUGINS[@]}"; do
        echo "    ${GREEN}✓${RESET} ${item}"
    done
else
    echo "  ${DIM}Plugins: none${RESET}"
fi

echo ""
bar
unset _s_loc
echo ""

# Next steps
echo "  ${BOLD}${WHITE}Next steps:${RESET}"
echo "    ${TEAL}→${RESET} Review AGENT.md and add project-specific context"
if [ "$INSTALL_GLOBAL" = false ]; then
    echo "    ${TEAL}→${RESET} Commit .claude/ to share rules with your team"
    if [ ! -f "$(pwd)/.${KT_WATERMARK}-config" ]; then
        echo "    ${TEAL}→${RESET} Run installer again to export an ${BOLD}.${KT_WATERMARK}-config${RESET} for teammates"
    fi
fi
if [ "$INSTALL_GLOBAL" = true ]; then
    echo ""
    echo "  ${DIM}For tools without symlink support (Cursor, Copilot, Aider,${RESET}"
    echo "  ${DIM}Amazon Q, Cline), copy files from ~/$KT_CONFIG_DIR/ into each${RESET}"
    echo "  ${DIM}project, or use a project install.${RESET}"
fi
echo ""
echo "  ${DIM}Press ${BOLD}m${RESET}${DIM} for menu or any other key to exit${RESET}"
read -rsn1 _key
if [ "$_key" = "m" ] || [ "$_key" = "M" ]; then
    BACK_TO_ACTION=true
    continue
fi

done  # end BACK_TO_ACTION loop

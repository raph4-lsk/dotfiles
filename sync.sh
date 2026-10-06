#!/bin/zsh

set -e

# ────────────────────────────────────────────────────────────
# CONFIG
# ────────────────────────────────────────────────────────────

CONFIG_DIR="$HOME/raph_config"

echo ""
echo "🔄 Syncing configs from $CONFIG_DIR..."
echo ""

# ─── ZSH ────────────────────────────────────────────────────
cp "$CONFIG_DIR/zsh/.zshrc" "$HOME/.zshrc"
echo "✅ .zshrc"

# ─── OH MY POSH ─────────────────────────────────────────────
mkdir -p "$HOME/.config/oh-my-posh"

cp "$CONFIG_DIR/zsh/zash.omp.json" \
   "$HOME/.config/oh-my-posh/zash.omp.json"

echo "✅ Oh My Posh theme"

# ─── GIT ────────────────────────────────────────────────────
cp "$CONFIG_DIR/git/.gitconfig" \
   "$HOME/.gitconfig"

cp "$CONFIG_DIR/git/.gitconfig-perso" \
   "$HOME/.gitconfig-perso"

echo "✅ Git"

# ─── LAZYGIT ────────────────────────────────────────────────
LAZYGIT_DIR="$HOME/Library/Application Support/lazygit"

mkdir -p "$LAZYGIT_DIR"

cp "$CONFIG_DIR/lazygit/config.yml" \
   "$LAZYGIT_DIR/config.yml"

echo "✅ lazygit"

# ─── DIRENV ─────────────────────────────────────────────────
mkdir -p "$HOME/.config/direnv"

cp "$CONFIG_DIR/direnv/direnv.toml" \
   "$HOME/.config/direnv/direnv.toml"

echo "✅ direnv"

# ─── WEZTERM ────────────────────────────────────────────────
cp "$CONFIG_DIR/wezterm/.wezterm.lua" \
   "$HOME/.wezterm.lua"

echo "✅ WezTerm"

# ─── NEOVIM ─────────────────────────────────────────────────
mkdir -p "$HOME/.config/nvim"

rsync -a \
   "$CONFIG_DIR/nvim/" \
   "$HOME/.config/nvim/"

echo "✅ Neovim"

# ─── ESPANSO ────────────────────────────────────────────────
if command -v espanso &>/dev/null; then

    ESPANSO_DIR="$(espanso path config)"

    mkdir -p "$ESPANSO_DIR/config"
    mkdir -p "$ESPANSO_DIR/match"

    rsync -a \
        "$CONFIG_DIR/espanso/config/" \
        "$ESPANSO_DIR/config/"

    rsync -a \
        "$CONFIG_DIR/espanso/match/" \
        "$ESPANSO_DIR/match/"

    espanso restart --unmanaged &>/dev/null \
        || espanso start --unmanaged &>/dev/null

    echo "✅ Espanso"

else

    echo "⚠️  Espanso not installed, skipped"

fi

# ─── OPENCODE ────────────────────────────────────────────────

OPENCODE_DIR="$HOME/.config/opencode"

mkdir -p "$OPENCODE_DIR"

cp "$CONFIG_DIR/opencode/opencode.jsonc" \
   "$OPENCODE_DIR/opencode.jsonc"

cp "$CONFIG_DIR/opencode/AGENTS.md" \
   "$OPENCODE_DIR/AGENTS.md"

if [ -d "$CONFIG_DIR/opencode/skills" ]; then
    mkdir -p "$OPENCODE_DIR/skills"
    rsync -a --delete \
        "$CONFIG_DIR/opencode/skills/" \
        "$OPENCODE_DIR/skills/"
fi

echo "✅ OpenCode"

# ─── CLAUDE CODE ────────────────────────────────────────────

CLAUDE_DIR="$HOME/.claude"

mkdir -p "$CLAUDE_DIR/skills"

rsync -a --delete \
    "$CONFIG_DIR/claude/skills/" \
    "$CLAUDE_DIR/skills/"

echo "✅ Claude Code skills"

# ─── CLAUDE CODE STATUSLINE ────────────────────────────────

cp "$CONFIG_DIR/claude/statusline.sh" \
   "$CLAUDE_DIR/statusline.sh"

chmod +x "$CLAUDE_DIR/statusline.sh"

echo "✅ Claude Code statusline"

# ─── KEYBOARD (QMK) ─────────────────────────────────────────
QMK_KEYMAP="$HOME/qmk_firmware/keyboards/crkbd/keymaps/arn"

if [ -d "$QMK_KEYMAP" ]; then

    cp \
        "$CONFIG_DIR/keyboard/keymap.c" \
        "$CONFIG_DIR/keyboard/config.h" \
        "$CONFIG_DIR/keyboard/rules.mk" \
        "$QMK_KEYMAP/"

    echo "✅ Keyboard (QMK keymap, compile/flash stays manual)"

else

    echo "⚠️  QMK keymap dir not found, skipped"

fi

# ─── ZOXIDE ─────────────────────────────────────────────────

if command -v zoxide &>/dev/null; then

    ZOXIDE_COUNT="$(
        zoxide query -l 2>/dev/null |
        wc -l |
        tr -d ' '
    )"

    if [ "$ZOXIDE_COUNT" -eq 0 ]; then

        find "$HOME" \
            -maxdepth 1 \
            -type d \
            ! -name ".*" \
            ! -name "Library" \
            -exec zoxide add {} \; \
            2>/dev/null

        if command -v fd &>/dev/null; then

            fd \
                -H \
                -t d \
                -d 4 \
                '^\.git$' \
                "$HOME" \
                -E Library \
                -E node_modules \
                -x dirname \
                2>/dev/null |
            while read -r repo; do
                zoxide add "$repo"
            done

        fi

        echo "✅ Zoxide (database seeded)"

    else

        echo "✅ Zoxide (database already populated)"

    fi

else

    echo "⚠️  Zoxide not installed, skipped"

fi

# ─── RELOAD ZSH ─────────────────────────────────────────────
source "$HOME/.zshrc"

echo ""
echo "🚀 All configs synced successfully!"
echo ""

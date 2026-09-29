#!/bin/zsh

echo "🔄 Syncing configs..."

# ─── ZSH ────────────────────────────────────────────────────
cp ~/raph_config/zsh/.zshrc ~/.zshrc
echo "✅ .zshrc"

# ─── OH MY POSH ─────────────────────────────────────────────
cp ~/raph_config/zsh/zash.omp.json ~/.config/oh-my-posh/zash.omp.json
echo "✅ Oh My Posh theme"

# ─── GIT ────────────────────────────────────────────────────
cp ~/raph_config/git/.gitconfig ~/.gitconfig
cp ~/raph_config/git/.gitconfig-perso ~/.gitconfig-perso
echo "✅ Git"

# ─── LAZYGIT ────────────────────────────────────────────────
mkdir -p "$HOME/Library/Application Support/lazygit"
cp ~/raph_config/lazygit/config.yml "$HOME/Library/Application Support/lazygit/config.yml"
echo "✅ lazygit"

# ─── DIRENV ─────────────────────────────────────────────────
mkdir -p ~/.config/direnv
cp ~/raph_config/direnv/direnv.toml ~/.config/direnv/direnv.toml
echo "✅ direnv"

# ─── WEZTERM ────────────────────────────────────────────────
cp ~/raph_config/wezterm/.wezterm.lua ~/.wezterm.lua
echo "✅ WezTerm"

# ─── NEOVIM ─────────────────────────────────────────────────
cp -r ~/raph_config/nvim/* ~/.config/nvim/
echo "✅ Neovim"

# ─── ESPANSO ────────────────────────────────────────────────
if command -v espanso &>/dev/null; then
    ESPANSO_DIR="$(espanso path config)"
    mkdir -p "$ESPANSO_DIR/config" "$ESPANSO_DIR/match"
    cp ~/raph_config/espanso/config/* "$ESPANSO_DIR/config/"
    cp ~/raph_config/espanso/match/* "$ESPANSO_DIR/match/"
    # launchd service is unreliable on this machine; run unmanaged
    espanso restart --unmanaged &>/dev/null || espanso start --unmanaged &>/dev/null
    echo "✅ Espanso"
else
    echo "⚠️  Espanso not installed, skipped"
fi

# ─── CLAUDE CODE ────────────────────────────────────────────
# exact mirror: a skill removed or renamed here disappears locally too
mkdir -p ~/.claude/skills
rsync -a --delete ~/raph_config/claude/skills/ ~/.claude/skills/
echo "✅ Claude Code skills"

# statusline: the "statusLine" entry in ~/.claude/settings.json is not synced
cp ~/raph_config/claude/statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
echo "✅ Claude Code statusline"

# ─── KEYBOARD (QMK) ─────────────────────────────────────────
QMK_KEYMAP="$HOME/qmk_firmware/keyboards/crkbd/keymaps/arn"
if [ -d "$QMK_KEYMAP" ]; then
    cp ~/raph_config/keyboard/keymap.c ~/raph_config/keyboard/config.h ~/raph_config/keyboard/rules.mk "$QMK_KEYMAP/"
    echo "✅ Keyboard (QMK keymap, compile/flash stays manual)"
else
    echo "⚠️  QMK keymap dir not found, skipped"
fi

# ─── ZOXIDE ─────────────────────────────────────────────────
# seed the database on a fresh machine; skipped once it has entries
if command -v zoxide &>/dev/null; then
    if [ "$(zoxide query -l 2>/dev/null | wc -l | tr -d ' ')" -eq 0 ]; then
        find ~ -maxdepth 1 -type d ! -name ".*" ! -name "Library" -exec zoxide add {} \; 2>/dev/null
        if command -v fd &>/dev/null; then
            fd -H -t d -d 4 '^\.git$' ~ -E Library -E node_modules -x dirname 2>/dev/null |
                while read -r repo; do zoxide add "$repo"; done
        fi
        echo "✅ Zoxide (database seeded)"
    else
        echo "✅ Zoxide (database already populated)"
    fi
else
    echo "⚠️  Zoxide not installed, skipped"
fi

# ─── RELOAD ZSH ─────────────────────────────────────────────
source ~/.zshrc
echo ""
echo "🚀 All configs synced successfully!"

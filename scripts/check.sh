#!/usr/bin/env bash
# Usage, from the project root:
#   scripts/check.sh               warnings and above (deprecations are reported there)
#   scripts/check.sh --level=Hint  also hints (unused locals, ...); Error/Information work as well

set -uo pipefail

root=$PWD
level=Warning
for arg in "$@"; do
  case "$arg" in
    --level=*) level=${arg#*=} ;;
    *)
      echo "check: unknown argument $arg" >&2
      exit 2
      ;;
  esac
done

nvim_bin=$(command -v nvim) || {
  echo "check: nvim not found in PATH" >&2
  exit 2
}
lua_ls=$(command -v lua-language-server 2>/dev/null || true)
[ -n "$lua_ls" ] || lua_ls="$HOME/.local/share/nvim/mason/bin/lua-language-server"
[ -x "$lua_ls" ] || {
  echo "check: lua-language-server not found (install it with :MasonInstall lua-language-server)" >&2
  exit 2
}

VIMRUNTIME=$("$nvim_bin" --clean --headless +'lua io.stdout:write(vim.env.VIMRUNTIME)' +qa 2>/dev/null)
if [ -z "$VIMRUNTIME" ]; then
  echo "check: could not determine \$VIMRUNTIME" >&2
  exit 2
fi
export VIMRUNTIME

nvim_version=$("$nvim_bin" --version | head -1)

"$lua_ls" --check "$root" --configpath "$root/.luarc.json" --checklevel="$level"

echo
runtime=$("$nvim_bin" --headless "$root/init.lua" \
  +'lua vim.cmd("checkhealth vim.deprecated")' \
  +'lua local l = vim.api.nvim_buf_get_lines(0, 0, -1, false) io.stdout:write("  " .. table.concat(l, "\n  ") .. "\n")' \
  +qa 2>&1)
grep -vE '^checkhealth: |^[[:space:]]*$' <<<"$runtime"

exit 0

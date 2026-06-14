#!/usr/bin/env sh
set -eux

TPM_DIR="$HOME/.config/keepassxc/tpm"
DB="$HOME/docs/Passwords.kdbx"
mkdir -p "$TPM_DIR" && chmod 700 "$TPM_DIR"
command -v tpm2_create >/dev/null 2>&1 || { echo "tpm2-tools not installed (sudo pacman -S tpm2-tools)" >&2; exit 1; }

set +x
printf 'KeePassXC master password (input hidden): ' >&2
stty -echo 2>/dev/null || true
IFS= read -r PW
stty echo 2>/dev/null || true
printf '\n' >&2

printf '%s' "$PW" | keepassxc-cli db-info -q "$DB" >/dev/null 2>&1 || { echo "Wrong password - nothing sealed." >&2; exit 1; }

tpm2_createprimary -Q -C o -g sha256 -G ecc -c "$TPM_DIR/primary.ctx"
printf '%s' "$PW" | tpm2_create -Q -C "$TPM_DIR/primary.ctx" -u "$TPM_DIR/seal.pub" -r "$TPM_DIR/seal.priv" -i -
chmod 600 "$TPM_DIR/seal.pub" "$TPM_DIR/seal.priv"
unset PW
echo "Sealed. Master password stored in the TPM." >&2

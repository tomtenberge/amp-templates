#!/usr/bin/env bash
# Run as the account that runs the AMP instance, with the VM stopped.
set -euo pipefail
if [[ $# -ne 2 ]]; then
    printf 'Usage: bash prepare-haos.sh /absolute/path/haos_ova-VERSION.qcow2[.xz] /absolute/path/INSTANCE/haos\n' >&2
    exit 2
fi
source_image=$1
destination=$2
[[ $source_image = /* && $destination = /* ]] || { echo 'Use absolute paths.' >&2; exit 2; }
[[ -f $source_image && -r $source_image ]] || { echo 'Source image is not readable.' >&2; exit 1; }
for tool in qemu-img xz realpath mktemp; do
    command -v "$tool" >/dev/null || { printf 'Missing command: %s\n' "$tool" >&2; exit 1; }
done
[[ -r /dev/kvm && -w /dev/kvm ]] || { echo 'This account needs read/write access to /dev/kvm.' >&2; exit 1; }
firmware_dir=/usr/share/OVMF
if [[ -f $firmware_dir/OVMF_CODE_4M.fd && -f $firmware_dir/OVMF_VARS_4M.fd ]]; then
    code_file=$firmware_dir/OVMF_CODE_4M.fd
    vars_file=$firmware_dir/OVMF_VARS_4M.fd
elif [[ -f $firmware_dir/OVMF_CODE.fd && -f $firmware_dir/OVMF_VARS.fd ]]; then
    code_file=$firmware_dir/OVMF_CODE.fd
    vars_file=$firmware_dir/OVMF_VARS.fd
else
    echo 'No matching non-secure-boot OVMF code/variables pair found. Install ovmf.' >&2
    exit 1
fi
mkdir -p -- "$destination"
destination=$(realpath -- "$destination")
# Lock initialization and refuse to overwrite an existing VM or firmware.
lock_dir=$destination/.prepare-lock
mkdir -- "$lock_dir" || { echo 'Another preparation is running, or a stale .prepare-lock exists.' >&2; exit 1; }
staging=''
cleanup() {
    if [[ -n $staging ]]; then
        rm -f -- "$staging/haos.qcow2" "$staging/OVMF_CODE.fd" "$staging/OVMF_VARS.fd"
        rmdir -- "$staging" || true
    fi
    rmdir -- "$lock_dir" || true
}
trap cleanup EXIT
for filename in haos.qcow2 OVMF_CODE.fd OVMF_VARS.fd; do
    [[ ! -e $destination/$filename && ! -L $destination/$filename ]] || {
        printf 'Refusing to overwrite %s/%s. Existing VM preserved.\n' "$destination" "$filename" >&2
        exit 1
    }
done
staging=$(mktemp -d "$destination/.prepare-XXXXXXXX")
case $source_image in
    *.qcow2.xz) xz -dc -- "$source_image" > "$staging/haos.qcow2" ;;
    *.qcow2) cp -- "$source_image" "$staging/haos.qcow2" ;;
    *) echo 'Expected the official KVM .qcow2 or .qcow2.xz image.' >&2; exit 2 ;;
esac
qemu-img info -f qcow2 "$staging/haos.qcow2"
qemu-img check -f qcow2 "$staging/haos.qcow2"
cp -- "$code_file" "$staging/OVMF_CODE.fd"
cp -- "$vars_file" "$staging/OVMF_VARS.fd"
chmod 600 "$staging/haos.qcow2" "$staging/OVMF_VARS.fd"
chmod 400 "$staging/OVMF_CODE.fd"
# Hard links fail if an unexpected existing target appeared after the checks.
# Staging is on the same filesystem; cleanup removes only the staging links.
ln -- "$staging/haos.qcow2" "$destination/haos.qcow2"
ln -- "$staging/OVMF_CODE.fd" "$destination/OVMF_CODE.fd"
ln -- "$staging/OVMF_VARS.fd" "$destination/OVMF_VARS.fd"
printf 'Prepared VM in %s. Start it from AMP.\n' "$destination"

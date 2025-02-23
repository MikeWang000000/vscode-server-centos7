#!/bin/bash
set -euo pipefail

check_el9 () {
    if [[ -z "${EL9_DIR:-}" ]]; then
        if [[ -d "$PWD/el9" ]]; then
            RPATH="$PWD/el9"
            INTERP="$PWD/el9/ld-linux-x86-64.so.2"
        else
            RPATH="/lib64/el9"
            INTERP="/lib64/el9/ld-linux-x86-64.so.2"
        fi
        if [[ ! -e "$RPATH/libc.so.6" ]] || [[ ! -e "$RPATH/libstdc++.so.6" ]] || [[ ! -e "$INTERP" ]]; then
            echo "ERROR: EL9 libraries not found" >&2
            exit 1
        fi
    else
        RPATH="$EL9_DIR"
        INTERP="$EL9_DIR/ld-linux-x86-64.so.2"
    fi
}

check_vscode () {
    ls code-* cli/servers/Stable-*/server/bin/code-server >/dev/null 2>&1 || {
        echo "ERROR: vscode binaries not found? Run this script from ~/.vscode-server" >&2
        exit 1
    }
}

check_patchelf () {
    hash -p "$PWD/bin/patchelf" patchelf
    patchelf --version >/dev/null || {
        echo "ERROR: patchelf does not work" >&2
        exit 1
    }
}

is_elf () {
    local fname
    fname=$1

    read -n4 fmagic < "$fname"
    [[ "$fmagic" = $'\x7fELF' ]]
    return $?
}

do_patch () {
    local fname needed rpath interp
    fname=$1

    interp=$(patchelf --print-interpreter "$fname" 2>/dev/null || true)
    if [[ -n "$interp" ]] && [[ "$interp" != "/lib64/ld-linux-x86-64.so.2" ]]; then
        return
    fi

    needed=$(patchelf --print-needed "$fname" 2>/dev/null || true)
    if [[ $'\n'"$needed"$'\n' != *$'\n'"libc.so.6"$'\n'* ]]; then
        return
    fi

    rpath=$(patchelf --print-rpath "$fname" 2>/dev/null || echo "<failure>")
    if [[ "$rpath" = *"<failure>" ]] || [[ ":$rpath:" = *":$RPATH:"* ]]; then
        return
    fi

    echo "Patching $fname ..."
    patchelf --set-rpath "${rpath:+$rpath:}$RPATH" "$fname"
    if [[ -n "$interp" ]]; then
        patchelf --set-interpreter "$INTERP" "$fname"
    fi
}

do_patch_recursive () {
    local dirs

    dirs="./cli"
    if [[ -e ./extensions ]]; then
        dirs="$dirs ./extensions"
    fi

    find $dirs -type f | while read fname; do
        if is_elf "$fname"; then
            do_patch "$fname" || true
        fi
    done
}

check_el9
check_vscode
check_patchelf
do_patch_recursive

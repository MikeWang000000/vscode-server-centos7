#!/bin/bash
set -euo pipefail

step () {
    local msg
    msg=$1

    echo ""
    echo "------------------------------------"
    echo "   $msg"
    echo "------------------------------------"
    echo ""
}

check_tars () {
    if [[ ! -e "el9.tar.gz" ]] || [[ ! -e "vscode-server.tar.gz" ]]; then
        echo "ERROR: tarballs not found. Run ./make.sh first." >&2
        exit 1
    fi
}

check_vscodeserver () {
    if pgrep -f ~/.vscode-server/ >/dev/null; then
        echo "ERROR: vscode server is running. Stop the server before installation." >&2
        exit 1
    fi
}

backup_vscodeserver () {
    local backup_dir i

    if [[ ! -e ~/.vscode-server ]]; then
        return 0
    fi

    backup_dir=~/.vscode-server-backup
    if [[ -e "$backup_dir" ]]; then
        for ((i=1 ;; i++)); do
            if [[ ! -e "$backup_dir.$i" ]]; then
                break
            fi
        done
        backup_dir="$backup_dir.$i"
    fi
    mkdir "$backup_dir"

    echo "Backing up vscode server files to $backup_dir ..."

    if ls ~/.vscode-server/code-* >/dev/null 2>&1; then
        mv ~/.vscode-server/code-* "$backup_dir"
    fi

    if [[ -e ~/.vscode-server/cli/servers ]]; then
        mkdir "$backup_dir/cli"
        mv ~/.vscode-server/cli/servers "$backup_dir/cli"
    fi

    echo "Backing up vscode extension files..."

    if [[ -e ~/.vscode-server/extensions ]]; then
        mkdir "$backup_dir/extensions"
        cp -a ~/.vscode-server/extensions "$backup_dir/extensions"
    fi
}

install_vscodeserver () {
    mkdir -p ~/.vscode-server/
    tar -xzf vscode-server.tar.gz -C ~/.vscode-server/ --strip-components=1
}

install_el9 () {
    if [[ "${NOROOT:-}" = "1" ]]; then
        tar -xzf el9.tar.gz -C ~/.vscode-server/
    else
        sudo tar -xzf el9.tar.gz -C /lib64/ || {
            echo "ERROR: cannot install EL9 libraries to /lib64. Run NOROOT=1 ./install.sh if you do not have root privileges." >&2
            return 1
        }
    fi
}

patch_vscodeserver () {
    (cd ~/.vscode-server/ && ./patch.sh)
}

step "Checking tarballs..."
check_tars

step "Checking vscode server..."
check_vscodeserver

step "Backing up vscode server..."
backup_vscodeserver

step "Installing vscode server..."
install_vscodeserver

step "Installing EL9 libraries..."
install_el9

step "Patching vscode server..."
patch_vscodeserver

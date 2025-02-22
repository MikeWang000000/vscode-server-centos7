#!/bin/bash
set -euo pipefail

export PATH="$PWD/tools/usr/bin${PATH:+:$PATH}"
export LD_LIBRARY_PATH="$PWD/tools/usr/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

step () {
    local msg
    msg=$1

    echo ""
    echo "------------------------------------"
    echo "   $msg"
    echo "------------------------------------"
    echo ""
}

rpm_extract () {
    local rpmfile dst compressor
    rpmfile=$1
    dst=$2

    compressor=$(rpm -qp --nosignature --queryformat "%{PAYLOADCOMPRESSOR}" "$rpmfile")
    if [[ "$compressor" = "zstd" ]]; then
        { rpm2cpio "$rpmfile" || true; } | zstd -d | (cd "$dst" && cpio -idmu --quiet)
    else
        rpm2cpio "$rpmfile" | (cd "$dst" && cpio -idmu --quiet)
    fi
}

fetch_tools () {
    mkdir -p tools

    curl -fO 'https://dl.fedoraproject.org/pub/archive/epel/7/x86_64/Packages/z/zstd-1.5.5-1.el7.x86_64.rpm'
    echo '8cdb57817effcf9d3611d5227a380429d4ad47f36ce57bd9729116319644d5f4 *zstd-1.5.5-1.el7.x86_64.rpm' | sha256sum -c
    rpm_extract 'zstd-1.5.5-1.el7.x86_64.rpm' tools
    rm 'zstd-1.5.5-1.el7.x86_64.rpm'

    curl -fO 'https://dl.fedoraproject.org/pub/archive/epel/7/x86_64/Packages/p/patchelf-0.12-1.el7.x86_64.rpm'
    echo 'c16a69647d483c4c112c1554c30ca797c9f3f9d0b8dd4a983f27bc879016b26c *patchelf-0.12-1.el7.x86_64.rpm' | sha256sum -c
    rpm_extract 'patchelf-0.12-1.el7.x86_64.rpm' tools
    rm 'patchelf-0.12-1.el7.x86_64.rpm'

    curl -fO 'https://dl.fedoraproject.org/pub/archive/epel/7/x86_64/Packages/o/oniguruma-6.8.2-2.el7.x86_64.rpm'
    echo 'f78bff1661d1aff52e4de760ef49867ae99283794fd563db76f7346cf5648fa5 *oniguruma-6.8.2-2.el7.x86_64.rpm' | sha256sum -c
    rpm_extract 'oniguruma-6.8.2-2.el7.x86_64.rpm' tools
    rm 'oniguruma-6.8.2-2.el7.x86_64.rpm'

    curl -fO 'https://dl.fedoraproject.org/pub/archive/epel/7/x86_64/Packages/j/jq-1.6-2.el7.x86_64.rpm'
    echo '080a262453c1d781c2cee543cd305b40f61c92e934eeac4005eb14364908fe9e *jq-1.6-2.el7.x86_64.rpm' | sha256sum -c
    rpm_extract 'jq-1.6-2.el7.x86_64.rpm' tools    
    rm 'jq-1.6-2.el7.x86_64.rpm'
}

fetch_el9 () {
    mkdir -p el9_root el9

    curl -fO 'https://vault.almalinux.org/9.0/BaseOS/x86_64/os/Packages/glibc-2.34-28.el9_0.2.x86_64.rpm'
    echo '226cc1dbf8a2ed17e259305eaf5ca910211f2d67ae597547a70eedcb30f9f373 *glibc-2.34-28.el9_0.2.x86_64.rpm' | sha256sum -c
    rpm_extract 'glibc-2.34-28.el9_0.2.x86_64.rpm' el9_root
    rm 'glibc-2.34-28.el9_0.2.x86_64.rpm'

    curl -fO 'https://vault.almalinux.org/9.0/BaseOS/x86_64/os/Packages/libstdc++-11.2.1-9.4.el9.alma.x86_64.rpm'
    echo '50eaa1d568eb043a26e03a08fe5c76334df78e1d9b7929183287637b058c5ead *libstdc++-11.2.1-9.4.el9.alma.x86_64.rpm' | sha256sum -c
    rpm_extract 'libstdc++-11.2.1-9.4.el9.alma.x86_64.rpm' el9_root
    rm 'libstdc++-11.2.1-9.4.el9.alma.x86_64.rpm'

    cp -a el9_root/lib64/. el9
    cp -a el9_root/usr/lib64/. el9
    rm -rf el9_root
}

fetch_vscodeserver () {
    local in_ver srv_info srv_ver srv_url srv_sha256 cli_info cli_url cli_sha256
    in_ver=$1

    if [[ "$in_ver" = "latest" ]]; then
        srv_info=$(curl -f "https://update.code.visualstudio.com/api/update/server-linux-x64/stable/latest")
        cli_info=$(curl -f "https://update.code.visualstudio.com/api/update/cli-linux-x64/stable/latest")
    elif [[ "$in_ver" =~ ^[0-9a-f]{40}$ ]]; then
        srv_info=$(curl -f "https://update.code.visualstudio.com/api/versions/commit:$version/cli-linux-x64/stable")
        cli_info=$(curl -f "https://update.code.visualstudio.com/api/versions/commit:$version/cli-linux-x64/stable")
    else
        srv_info=$(curl -f "https://update.code.visualstudio.com/api/versions/$version/cli-linux-x64/stable")
        cli_info=$(curl -f "https://update.code.visualstudio.com/api/versions/$version/cli-linux-x64/stable")
    fi

    srv_ver=$(echo "$srv_info" | jq -r .version)
    srv_url=$(echo "$srv_info" | jq -r .url)
    srv_sha256=$(echo "$srv_info" | jq -r .sha256hash)
    
    cli_ver=$(echo "$cli_info" | jq -r .version)
    cli_url=$(echo "$cli_info" | jq -r .url)
    cli_sha256=$(echo "$cli_info" | jq -r .sha256hash)

    if [[ "$srv_ver" != "$cli_ver" ]]; then
        echo "VSCode Server and CLI versions do not match." >&2
        false
    fi

    mkdir -p "vscode-server/cli/servers/Stable-$srv_ver/server"
    curl -fo "vscode-server-linux-x64.tar.gz" "$srv_url"
    echo "$srv_sha256 *vscode-server-linux-x64.tar.gz" | sha256sum -c
    tar xf "vscode-server-linux-x64.tar.gz" -C "vscode-server/cli/servers/Stable-$srv_ver/server" --strip-components=1
    rm "vscode-server-linux-x64.tar.gz"

    curl -fo "vscode_cli_linux_x64_cli.tar.gz" "$cli_url"
    echo "$cli_sha256 *vscode_cli_linux_x64_cli.tar.gz" | sha256sum -c
    tar xf "vscode_cli_linux_x64_cli.tar.gz" -C "vscode-server"
    mv "vscode-server/code" "vscode-server/code-$cli_ver"
    rm "vscode_cli_linux_x64_cli.tar.gz"
}

patch_vscodeserver () {
    mkdir -p vscode-server/bin
    cp -a tools/usr/bin/patchelf vscode-server/bin/
    cp patch.sh vscode-server/
    (cd vscode-server && EL9_DIR=/lib64/el9 ./patch.sh)
}

make_tarballs () {
    local tar_cmd

    tar_cmd="tar --owner=0 --group=0 --no-same-owner --no-same-permissions"
    $tar_cmd -czf el9.tar.gz el9
    $tar_cmd -czf vscode-server.tar.gz vscode-server
}

cleanup () {
    rm -rf tools el9 vscode-server 
}

step "Fetching tools..."
fetch_tools

step "Fetching EL9 libraries..."
fetch_el9

step "Fetching vscode server..."
fetch_vscodeserver "${1:-latest}"

step "Patching vscode server..."
patch_vscodeserver

step "Making tarballs..."
make_tarballs

step "Cleaning up..."
cleanup

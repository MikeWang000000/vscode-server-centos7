# vscode-server-centos7

The official VS Code Server will no longer work for RHEL/CentOS 7 after February 2025. This is because the dependencies are raised to libc >= 2.28 and libstdc++ >= 3.4.25.

The scripts in this repository can patch the VS Code Server binaries to link to newer versions of libc and libstdc++, allowing us to bypass this limitation and keep the VS Code Server running on RHEL/CentOS 7.


## Quick Start

If your server has Internet access and you can use the `sudo` command, type the following commands:

```bash
./make.sh
./install.sh
```

The latest patched VS Code Server will be installed at `~/.vscode-server`, and the EL9 libc and libstdc++ libraries will be installed at `/lib64/el9`.


## Patching Extensions

Remember to patch the extensions each time you install or upgrade them. Some extensions with native binaries might not work without patching.

```bash
cd ~/.vscode-server
./patch.sh
```


## Advanced Usage

### make.sh

1. Specify the VS Code version:

    ```bash
    ./make.sh 1.97.0
    ```

2. Specify the VS Code commit ID:

    ```bash
    ./make.sh 3fc5a94a3f99ebe7087e8fe79fbe1d37a251016
    ```

### install.sh

1. Install EL9 libraries without root privileges:

    ```bash
    NOROOT=1 ./install.sh
    ```

    > The EL9 libc and libstdc++ libraries will be installed at `~/.vscode-server/el9`.
    >
    > Note that with this installation method, you cannot move `.vscode-server` to another location. Otherwise, all the patched binaries will no longer work.


## FAQ

1.
    **Q:** My server does not have Internet access. How can I run `make.sh`?

    **A:** You can run this script on another computer with Internet access inside Docker. Run the following commands:

    ```bash
    docker run -it --rm centos:7 -v "$PWD:/root" /root/make.sh
    ```

    Then, copy `el9.tar.gz` and `vscode-server.tar.gz` to your server. After that, run `./install.sh` on your server.

    Alternatively, you can download `el9.tar.gz` and `vscode-server.tar.gz` directly from the GitHub release page.

2.
    **Q:** When I run `install.sh`, it says `ERROR: vscode server is running.`

    **A:** You can kill the server by executing the following command:

    ```bash
    pkill -f ~/.vscode-server/
    ```

    Make sure your files are saved before killing the server.

3.
    **Q:** What are EL9 libraries, and where does the script fetch them from?

    **A:** EL9 libraries refer to the libc and libstdc++ libraries for RHEL9-based distros. `make.sh` fetches these libraries from AlmaLinux 9 RPM packages.


## License

**This repository:**  
[MIT License](./LICENSE.txt)

Microsoft Visual Studio Code product license:  
https://code.visualstudio.com/license

Visual Studio Code - Open Source:  
https://github.com/microsoft/vscode/blob/main/LICENSE.txt

The GNU C Library:  
https://www.gnu.org/software/libc/manual/html_node/Copying.html

The GNU C++ Library:  
https://gcc.gnu.org/onlinedocs/libstdc++/manual/license.html

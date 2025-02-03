For the stable version, just copy and past the below code in Termux:

```bash
pkg install wget -y && wget -O- https://raw.githubusercontent.com/doodstecsonhere/termux/main/installxfce4_termux.sh | sh
```

For the beta version, use:

```bash
pkg install wget -y && wget -O- https://raw.githubusercontent.com/doodstecsonhere/termux/main/installxfce4_termux_beta.sh | bash
```

# Termux Dotfiles Setup Script

This script automates the setup of a Termux desktop environment and dotfiles management using Git. It is designed to help you quickly configure a functional XFCE desktop in Termux and keep your configuration files synchronized in a Git repository (e.g., on GitHub).

## Features

*   **Automated Setup:** Streamlines the process of setting up a Termux desktop environment, including installing necessary packages and configuring Git.
*   **Dotfiles Management:** Initializes a Git repository in `~/termux-dotfiles` (or a name you specify) to manage your configuration files (dotfiles).
*   **Configuration Backup and Sync:**
    *   Backs up your existing configurations to the dotfiles repository before initial sync.
    *   Synchronizes configuration files between your dotfiles repository and your Termux home directory.
    *   Automatically backs up and syncs configurations to your dotfiles repository on exit (via `.bashrc`).
*   **"Sync Everything Except Cache" Approach:** Attempts to sync all relevant configuration files while excluding common cache and temporary files (configurable exclusion patterns).
*   **XFCE Desktop Setup:** Installs and configures XFCE4 desktop environment in Termux, including desktop launchers.
*   **SSH Key Generation and Setup:** Generates an SSH key if one doesn't exist and guides you through adding it to your GitHub account for secure Git operations.
*   **Customizable:**
    *   **`CONFIG_DIRS_TO_SYNC`:**  Array to define which directories and files are synced.
    *   **`RSYNC_EXCLUDE_PATTERNS`:** Array to define patterns for excluding files and directories during sync (e.g., cache files).
    *   **`DOTFILES_REPO_DEFAULT`:** Default name for your dotfiles repository.
    *   **`PACKAGES_REQUIRED`:** Array to customize the packages installed by the script.
*   **Idempotent:** Can be run multiple times without causing issues. Checks for existing installations and configurations.
*   **User-Friendly:** Provides clear log messages and prompts for user input.

## Prerequisites

*   **Termux:** You must have Termux installed on your Android device.
*   **Internet Connection:**  An active internet connection is required to download packages and scripts from GitHub.
*   **GitHub Account (Optional but Recommended):** A GitHub account is recommended for hosting your dotfiles repository and enabling remote synchronization.

## How to Use

1.  **Install `wget` (if not already installed):**
    ```bash
    pkg install wget -y
    ```

2.  **Download and Execute the Script:**
    Paste the following command into your Termux terminal and press Enter:

    ```bash
    wget -O- https://raw.githubusercontent.com/doodstecsonhere/termux/main/installxfce4_termux_beta.sh | sh
    ```
    This command will:
    *   Download the `installxfce4_termux_beta.sh` script from your GitHub repository (`github.com/doodstecsonhere/termux/main`).
    *   Execute the script directly using `sh`.

    The script will prompt you for:
    *   Your GitHub username.
    *   Your GitHub email.
    *   The name for your dotfiles repository (defaults to `termux-dotfiles`).

    Follow the on-screen prompts. The script will guide you through the setup process.

3.  **Add SSH Key to GitHub:**
    If you don't have an existing SSH key, the script will generate one and display the public key. You will need to copy this public key and add it to your GitHub account's SSH keys settings: [https://github.com/settings/keys](https://github.com/settings/keys). The script will attempt to open this page in your browser.

4.  **Start XFCE Desktop:**
    Once the script completes successfully, you can start the XFCE desktop environment by running:
    ```bash
    ./startxfce4_termux.sh
    ```

## Customization

You can customize the script by modifying the configuration variables at the beginning of the `installxfce4_termux_beta.sh` script file directly on GitHub before downloading or after downloading and before running it.  Edit the file using a text editor and modify these variables:

*   **`DOTFILES_REPO_DEFAULT`:** Change the default name of your dotfiles repository.
*   **`CONFIG_DIRS_TO_SYNC`:**  This array defines which directories and files in your home directory will be backed up and synchronized. **Review and customize this array** to include all the configuration files you want to manage. You can add or remove entries. Entries can be directory names (e.g., `.config`) or specific file paths (e.g., `.bashrc`).
*   **`RSYNC_EXCLUDE_PATTERNS`:** This array contains patterns used by `rsync` to exclude files and directories during synchronization. **Review and customize this array** to add or remove exclusion patterns, especially to fine-tune the exclusion of cache and temporary files.  Example patterns:
    ```bash
    RSYNC_EXCLUDE_PATTERNS=(
        "*/cache*"          # Exclude directories containing "cache"
        "*.log"             # Exclude files ending in ".log"
        "specific_directory/unwanted_subdir/" # Exclude a specific subdirectory
    )
    ```
*   **`PACKAGES_REQUIRED`:**  Modify this array to add or remove packages that you want to be installed by the script.

**Important Notes and Cautions**

*   **Review Configuration:**  Before running the script and after, **carefully review the `CONFIG_DIRS_TO_SYNC` and `RSYNC_EXCLUDE_PATTERNS` arrays** to ensure they meet your needs and you are syncing the intended files and excluding unwanted data.
*   **SSH Key Security:** Be cautious when syncing the `.ssh` directory, especially if you are syncing to untrusted systems.  Consider the security implications of syncing your SSH private keys. If unsure, exclude `.ssh` from `CONFIG_DIRS_TO_SYNC`.
*   **"Sync Everything Except Cache" is an Approximation:** The script's "sync everything except cache" approach relies on pattern matching in `RSYNC_EXCLUDE_PATTERNS`. It is not foolproof. You might need to refine the exclusion patterns.
*   **Test Thoroughly:** After running the script and setting up your desktop, **test your configuration thoroughly** to ensure everything is working as expected and that no important data is missing or accidentally overwritten.
*   **GitHub Credentials:** Ensure your GitHub username and email are entered correctly when prompted.
*   **Network Connectivity:** A stable network connection is required for downloading packages and syncing with your remote Git repository.
*   **First Run and Initial Push:** The initial `git push` might fail if you haven't set up your GitHub repository yet or have network issues. The script will warn you and attempt to push again during auto-sync on exit.

## Auto-Sync on Exit

The script adds a function `sync_configs_and_backup()` to your `.bashrc` file and sets it to run automatically when you exit your Termux session (`trap sync_configs_and_backup EXIT`). This function will:

1.  Navigate to your dotfiles directory (`~/termux-dotfiles`).
2.  Backup your current configurations to the `config_backup` directory within the dotfiles repository.
3.  Stage all changes (`git add .`).
4.  Commit the changes with a timestamped commit message (`git commit ...`).
5.  Push the changes to your remote Git repository (`git push origin main`).

This ensures that your configuration changes are automatically backed up and synced whenever you close your Termux session.

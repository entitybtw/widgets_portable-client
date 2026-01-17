# widgets_portable-client

PC client for **widgets_portable**

## Versions

* **Linux** ready, available at `linux/client.sh`
* **Windows** not done
* **macOS** not done

## Installation

### Linux

1. Install the **zenity** package via your distro’s package manager

   * Arch-based: `sudo pacman -S zenity`
   * Debian-based: `sudo apt install zenity`
2. Download `client.sh` from the `linux/` folder
3. Make it executable:

   ```bash
   chmod +x client.sh
   ```
4. Run the installer:

   ```bash
   ./client.sh --install
   ```
5. Done! You can now launch the app from any app launcher (e.g., Rofi, Wofi, etc.)

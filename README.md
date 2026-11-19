# PIU

**P**orts **I**n **U**se: a tiny chick in the macOS menu bar that tells you which dev ports are busy, and lets you free them in one click.

A red badge shows how many dev servers are listening (no badge when there are none). Click the chick to see each port and the program behind it, expand a row for details (command, folder, PID, uptime, network exposure), and stop it with the red button.

macOS services and installed apps (AirPlay, Discord, editors…) are hidden by default and can be shown with **Show all**.

## Requirements

- macOS 14 (Sonoma) or later, Apple silicon or Intel

## Download

1. Download `piu-x.y.z.zip` from the [latest release](https://github.com/cmtdrt/piu/releases/latest).
2. Unzip it and move **PIU** to your Applications folder.
3. Open it. The chick appears in the menu bar.

The app is not notarized by Apple, so macOS blocks it the first time. To open it anyway, go to **System Settings → Privacy & Security** and click **Open Anyway** next to the PIU message. Or run once in a terminal:

```bash
xattr -dr com.apple.quarantine /Applications/PIU.app
```

## Build from source

Requires the Apple Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/cmtdrt/piu.git
cd piu
./scripts/build.sh --install
```

The script builds the app, copies it to `/Applications` and launches it. To update, run `git pull` then the same script.

## License

[MIT](LICENSE)

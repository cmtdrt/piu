# PIU

**P**orts **I**n **U**se: a tiny chick in the macOS menu bar that tells you which dev ports are busy, and lets you free them in one click. 

A red badge shows how many dev servers are listening (no badge when there are none).
<p align="center">
  <img width="305" height="33" alt="image" src="https://github.com/user-attachments/assets/1a7a0560-baae-49ff-b2f4-39f10dca01e0" />
</p>

Click the chick to see each port and the program behind it, stop it with the red cross, or open a port for details: command, folder, PID, uptime and network exposure.

<p align="center">
  <img width="323" alt="image" src="https://github.com/user-attachments/assets/19afa503-88e1-455e-80b5-34313c9264cd" />
</p>

<p align="center">
  <img width="323" alt="image" src="https://github.com/user-attachments/assets/58f2175e-9c1e-4722-8c18-19f763654303" />
</p>

macOS services and installed apps (AirPlay, Discord, editors…) are hidden by default and can be shown with **Show all**. The list refreshes every 10 seconds; the interval, automatic refresh and language (English or French) can be changed in the settings.

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

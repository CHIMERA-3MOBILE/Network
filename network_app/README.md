# Network App

A disguised P2P mesh communication utility application that appears as a simple file manager.

## Features

- **Disguised Interface**: Appears as a local file manager utility
- **P2P Mesh Network**: Serverless peer-to-peer communication using BLE and Wi-Fi Direct
- **Background Service**: Runs continuously in background with battery optimization bypass
- **Multi-hop Routing**: Supports mesh networking for extended range
- **Hidden Settings**: Access network settings via long-press gesture

## Installation

1. Download the latest APK from GitHub Actions
2. Install on Android device
3. Grant all requested permissions
4. Long-press on the main screen to access network settings

## Development

This project uses Flutter with GitHub Actions for automated APK builds.

### Build Instructions

```bash
flutter pub get
flutter build apk --release
```

### CI/CD

The project includes automated builds via GitHub Actions that trigger on push to main branch.

## Architecture

- **Flutter**: Cross-platform UI framework
- **nearby_connections**: P2P networking
- **flutter_background_service**: Background execution
- **Android Native**: Battery optimization bypass

## Security

This application is designed for research and educational purposes only.

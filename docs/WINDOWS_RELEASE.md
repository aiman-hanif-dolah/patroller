# Windows portable release (manual)

Flutter **cannot cross-compile** Windows apps from macOS. Build the Windows zip on a **Windows** PC, then upload it to GitHub Releases the same way as the macOS DMG (no CI required).

## Requirements (Windows)

- Windows 10/11 x64
- [Flutter](https://docs.flutter.dev/get-started/install/windows) stable (3.3+)
- [Visual Studio 2022](https://visualstudio.microsoft.com/) with **Desktop development with C++**
- Git

## Build

```powershell
git clone https://github.com/aiman-hanif-dolah/patroller.git
cd patroller
flutter config --enable-windows-desktop
flutter doctor
.\scripts\package-windows.ps1
```

Artifacts land in `dist\`:

- `Patroller-<version>-windows-x64.zip` - portable app
- `install-windows.txt` - short end-user notes
- `SHA256SUMS-<version>-windows.txt` - checksum

## Publish

1. Open https://github.com/aiman-hanif-dolah/patroller/releases  
2. Edit the current release (e.g. **v1.0.0**) or draft a new one  
3. Upload `Patroller-*-windows-x64.zip`  
4. Update **README → Installation → Windows** with the new download URL if the version string changed  

## End-user install

1. Download the zip from Releases  
2. Unzip anywhere  
3. Run `patroller.exe`  

No admin installer is required.

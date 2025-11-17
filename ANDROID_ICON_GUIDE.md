# Android App Icon Update Guide

To update the Android app icon for your Qur'an Tracker app, follow these steps:

## Option 1: Using Android Asset Studio (Recommended)

1. Visit: https://romannurik.github.io/AndroidAssetStudio/icons-launcher.html
2. Upload your icon image (1024x1024 PNG recommended)
3. Configure:
   - Background color: Choose an appropriate color (e.g., teal/green for Islamic theme)
   - Padding: 10-20%
   - Shape: Any (square with rounded corners recommended)
4. Download the generated icon set
5. Extract the ZIP file
6. Copy the mipmap folders (mipmap-hdpi, mipmap-mdpi, mipmap-xhdpi, mipmap-xxhdpi, mipmap-xxxhdpi) to:
   ```
   android/app/src/main/res/
   ```
   Replace the existing mipmap folders.

## Option 2: Manual Creation

Create icon images in the following sizes:
- mipmap-mdpi: 48x48 px
- mipmap-hdpi: 72x72 px
- mipmap-xhdpi: 96x96 px
- mipmap-xxhdpi: 144x144 px
- mipmap-xxxhdpi: 192x192 px

Place each `ic_launcher.png` in its respective folder.

## Option 3: Using Flutter Package

1. Add to `pubspec.yaml`:
   ```yaml
   dev_dependencies:
     flutter_launcher_icons: ^0.13.1
   ```

2. Configure in `pubspec.yaml`:
   ```yaml
   flutter_launcher_icons:
     android: true
     image_path: "assets/icon/app_icon.png"  # Your 1024x1024 icon
   ```

3. Run:
   ```bash
   flutter pub get
   flutter pub run flutter_launcher_icons
   ```

## Design Suggestions

- Use a book/Qur'an icon or Islamic geometric pattern
- Use teal/green color scheme
- Keep it simple and recognizable at small sizes
- Ensure good contrast for visibility

After updating, rebuild the app:
```bash
flutter clean
flutter pub get
flutter build apk
```









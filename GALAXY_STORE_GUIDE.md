# Galaxy Store Submission Guide

This guide will help you prepare and upload your app to the Samsung Galaxy Store.

## Prerequisites

1. **Samsung Developer Account**
   - Register at: https://seller.samsungapps.com/
   - Complete your developer profile
   - Pay the registration fee (one-time, if applicable)

2. **App Requirements**
   - Unique package name (already set: `com.ali.communityqurantodo`)
   - App icon (512x512px PNG)
   - Screenshots (at least 4, up to 8)
   - Feature graphic (1024x500px PNG)
   - App description and metadata

## Step 1: Create a Signing Key

First, create a keystore file for signing your app:

```bash
cd android
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Important:** 
- Save the passwords you enter (keystore password and key password)
- Keep the keystore file secure - you'll need it for all future updates
- The keystore file will be created in the `android/` directory

## Step 2: Configure Signing

1. Create `android/key.properties` file:
```bash
cd android
nano key.properties
```

2. Add your keystore information:
```
storePassword=your_keystore_password_here
keyPassword=your_key_password_here
keyAlias=upload
storeFile=../upload-keystore.jks
```

3. **IMPORTANT:** Add `key.properties` to `.gitignore` to avoid committing sensitive data:
```bash
echo "android/key.properties" >> .gitignore
echo "android/*.jks" >> .gitignore
```

## Step 3: Build Release APK or AAB

### Option A: Build APK (Simpler)
```bash
flutter build apk --release
```

The APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

### Option B: Build AAB (Recommended - smaller file size)
```bash
flutter build appbundle --release
```

The AAB will be at: `build/app/outputs/bundle/release/app-release.aab`

**Note:** Galaxy Store accepts both APK and AAB formats, but AAB is preferred.

## Step 4: Test Your Release Build

Before submitting, test the release build on a real device:

```bash
flutter install --release
# or
adb install build/app/outputs/flutter-apk/app-release.apk
```

## Step 5: Prepare App Assets

Create these assets for Galaxy Store submission:

1. **App Icon**
   - Size: 512x512px
   - Format: PNG
   - Transparent background recommended
   - Location: Use `assets/icon/logo_islamic.png`

2. **Screenshots** (Required: 4-8 screenshots)
   - Minimum: 4 screenshots
   - Maximum: 8 screenshots
   - Recommended sizes:
     - Phone: 1080x1920px or 1440x2560px
     - Tablet: 2048x1536px
   - Format: PNG or JPG

3. **Feature Graphic** (Optional but recommended)
   - Size: 1024x500px
   - Format: PNG
   - Used for promotional banners

4. **Promotional Banner** (Optional)
   - Size: 360x360px
   - Format: PNG

## Step 6: Prepare App Information

### App Details Needed:

1. **App Name**: "Community Quran Todo" (or your preferred name)
2. **Short Description**: One line description (up to 50 characters)
3. **Full Description**: Detailed description of your app
4. **Category**: Education, Lifestyle, or Productivity
5. **Tags**: Keywords for search
6. **Support Email**: Your support email address
7. **Privacy Policy URL**: (Required if app collects user data)
8. **Website URL**: (Optional)

### Example Description:

```
Community Quran Todo is a collaborative app for tracking Quran recitation assignments and progress within study groups. Features include:

• Create and manage recitation groups
• Assign recitation tasks to group members
• Track progress on Juz and Surah completion
• Share announcements and Hadith reflections
• View group statistics and member performance
• Join groups via invite codes or shareable links

Perfect for families, study circles, and Quran study communities.
```

## Step 7: Submit to Galaxy Store

1. **Log in** to Samsung Seller Portal: https://seller.samsungapps.com/

2. **Create New Application**
   - Click "Add New Application"
   - Select "Application"

3. **Fill Application Information**
   - Package Name: `com.ali.communityqurantodo`
   - App Name: Your app name
   - Category: Select appropriate category
   - Upload app icon and screenshots

4. **Upload Application File**
   - Upload the APK or AAB file you built
   - Galaxy Store will automatically scan it

5. **Set Pricing**
   - Free or Paid
   - Select countries for distribution

6. **Content Rating**
   - Complete the content rating questionnaire
   - Galaxy Store will determine the rating

7. **Privacy & Permissions**
   - Declare all permissions your app uses
   - Provide privacy policy URL if required

8. **Review & Submit**
   - Review all information
   - Submit for review

## Step 8: After Submission

- **Review Time**: Usually 2-7 business days
- **Status Updates**: Check your seller portal dashboard
- **Rejections**: Galaxy Store will provide feedback if changes are needed

## Important Notes

1. **Version Updates**: Always increment `versionCode` in `pubspec.yaml` for each update
   ```yaml
   version: 1.0.1+2  # 1.0.1 is versionName, +2 is versionCode
   ```

2. **Keystore Security**: 
   - Keep your keystore file and passwords secure
   - Backup the keystore file to a safe location
   - You'll need the same keystore for all future updates

3. **App Signing**: Galaxy Store may offer app signing by Samsung - you can choose this option for added security

4. **Testing**: Test thoroughly before submission to avoid rejections

## Troubleshooting

### Build Errors
- Ensure all dependencies are properly configured
- Run `flutter clean` then `flutter pub get`
- Check that your keystore file exists and passwords are correct

### Submission Rejections
- Review Galaxy Store policies
- Fix any security or policy violations
- Resubmit with corrections

## Resources

- Samsung Seller Portal: https://seller.samsungapps.com/
- Galaxy Store Guidelines: https://seller.samsungapps.com/help/articleDetail.as?docId=90000813250
- Flutter Release Guide: https://docs.flutter.dev/deployment/android

## Quick Command Reference

```bash
# Create keystore
keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# Build release APK
flutter build apk --release

# Build release AAB (recommended)
flutter build appbundle --release

# Test release build
flutter install --release
```

Good luck with your submission! 🚀


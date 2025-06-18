# flutter_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

### Connect Flutter Frontend to Backend + Firebase Authentication

To enable secure access to your private Cloud Run backend, we integrate Firebase Authentication into the Flutter app and send authenticated requests using Firebase ID tokens.

---

#### 🔐 Enable Firebase Authentication Manually

##### ✅ How to Manually Enable Firebase in the Console

1. **Go to the Firebase Console**
   👉 [https://console.firebase.google.com/](https://console.firebase.google.com/)

2. **Click "Add project"** (or select your existing GCP project)

3. **Click "Add Firebase to your Google Cloud project"**  
   > Use the **same GCP project** you used in your `terraform.tfvars`.

4. **Click "Continue"** and follow the setup prompts  
   > Confirm billing and API access when asked

5. **Enable Firebase Authentication**

   * In the Firebase Console navigate to **Build → Authentication**
   * Click **"Get Started"**
   * Under **Sign-in method**, enable **Google**
   * Click **Save**

---

#### 🧰 Configure `flutterfire` CLI

If you haven’t yet, install the FlutterFire CLI:

```bash
dart pub global activate flutterfire_cli
```

Then log in to Firebase:

```bash
firebase login
```

Now configure your Flutter app to use Firebase:

```bash
cd flutter_app
flutterfire configure
```

Follow the prompts:

* Select your Firebase project
* Choose your platform(s) — **android**, **ios**, **web** etc.
* Provide your app ID (e.g., `com.example.app`)

> This generates `lib/firebase_options.dart` and sets up the native platform configs.

---

#### 🔧 Update Your Flutter Code

In your `lib/main.dart`:

* Uncomment the `import 'firebase_options.dart';` & `
* Update the Firebase initialization:

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

* Replace this constant with your deployed Cloud Run URL:

```dart
static const String backendUrl = '<CLOUD_RUN_URL>';
```

---

#### 🚀 Run the App

```bash
cd flutter_app
flutter pub get
flutter run
```

Make sure:

✅ You’ve replaced `<CLOUD_RUN_URL>` with your deployed Cloud Run endpoint
✅ You’re signed in with a Google account that Firebase recognizes
✅ Firebase project has Authentication → Google Sign-In enabled

---
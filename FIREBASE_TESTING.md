# Firebase Testing Guide

## Avoiding "Unusual Activity" Blocks

During development, you should use **Firebase Test Phone Numbers** instead of real phone numbers. This prevents:
*   "We have blocked all requests from this device due to unusual activity" errors.
*   Wasting your SMS quota.
*   Waiting for real SMS messages.

### How to Set Up Test Numbers

1.  Go to the [Firebase Console](https://console.firebase.google.com/).
2.  Select your project: **swiftfuel-34ad5**.
3.  Navigate to **Authentication** > **Sign-in method**.
4.  Click on the **Phone** provider.
5.  Find the **"Phone numbers for testing"** section (you may need to scroll down).
6.  Click **"Phone numbers for testing"** to expand it.
7.  Enter a dummy phone number (e.g., `+234 999 999 9999`) and a test verification code (e.g., `123456`).
8.  Click **Add**.

### Testing in the App

1.  Open the SwiftFuel app.
2.  Enter the **test phone number** you just created.
3.  Tap "Send OTP".
4.  Enter the **test verification code** (`123456`).

You will be signed in immediately.

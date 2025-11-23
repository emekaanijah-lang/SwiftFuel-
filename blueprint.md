# SwiftFuel+ Blueprint

## Overview

SwiftFuel+ is a mobile application for on-demand petroleum product delivery. It consists of two main applications: a customer-facing app for ordering fuel and tracking deliveries, and a driver app for managing orders and navigation. The initial target market includes high-brow areas, industrial layouts, and last-mile consumers in three major Nigerian cities. The application will be built using Flutter and Firebase.

## Implemented Features

### Initial Setup
*   **Project Structure:** Set up the foundational structure of the Flutter application.
*   **Dependencies:** Added and configured `firebase_core`, `go_router`, `provider`, and `google_fonts`.
*   **Firebase Integration:** Initialized Firebase in `lib/main.dart`.
*   **Theming:**
    *   Created a custom color palette in `lib/app_colors.dart` based on the provided design.
    *   Implemented a Material 3 theme for both light and dark modes, using `ColorScheme.fromSeed` with the app's primary color.
    *   Configured custom typography with `google_fonts`.
    *   Styled the `ElevatedButton` theme for a consistent look.
*   **Navigation:** Configured declarative routing using `go_router`.
*   **UI Shell:** Created a basic home screen and a theme toggle.

### Authentication UI
*   **Dependency:** Added the `firebase_auth` package.
*   **Screens:** Created the UI for the `SignupScreen` (phone number input) and `OTPScreen` (OTP input).
*   **Routing:** Integrated the new authentication screens into the `go_router` navigation flow, accessible from the home screen.

---

## Current Task: Implement Authentication Logic

### Plan
1.  **State Management:**
    *   Create an `AuthenticationProvider` to manage the authentication state, including loading status, error messages, and the current user.
2.  **Phone Number Verification:**
    *   In `SignupScreen`, implement the logic to call `FirebaseAuth.instance.verifyPhoneNumber` when the "Send OTP" button is pressed.
    *   Handle the `verificationCompleted`, `verificationFailed`, `codeSent`, and `codeAutoRetrievalTimeout` callbacks.
3.  **Navigate and Pass Data:**
    *   On `codeSent`, navigate the user to the `OTPScreen`, passing the `verificationId` as a parameter.
4.  **OTP Verification:**
    *   In `OTPScreen`, use the passed `verificationId` and the user-entered OTP to create a `PhoneAuthCredential`.
5.  **Sign In:**
    *   Use the credential to sign the user in with `FirebaseAuth.instance.signInWithCredential`.
6.  **User State:**
    *   Upon successful sign-in, update the `AuthenticationProvider` and navigate the user to a new `DashboardScreen` (to be created).
7.  **Error Handling:**
    *   Display user-friendly error messages for scenarios like invalid phone numbers, incorrect OTPs, or network issues.

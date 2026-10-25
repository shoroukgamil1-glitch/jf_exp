# news_app

A new Flutter project.

## AI Overview setup

The sparkle button calls the `generateAiSummary` Firebase callable function. The
Gemini API key is kept in a Firebase Functions secret rather than in the app:

```powershell
firebase functions:secrets:set GEMINI_API_KEY --project just-the-facts-cb7b6
firebase deploy --only functions --project just-the-facts-cb7b6
```

When prompted for the secret value, enter a Gemini API key. The AI overview uses
the video's YouTube title, description, publish date, and link; it does not
retrieve a transcript.

## Profiles and saved videos

Users can update their profile photo and private bio from the profile tab.
Saved videos are stored under the signed-in user's Firestore document and can
only be read or changed by that user. Signed-in users can comment on videos,
and each commenter can delete their own comments. Profile photos are stored in
that user's Firebase Storage path.

Deploy the Firestore and Storage rules before using these features:

```powershell
firebase deploy --only firestore:rules,storage --project just-the-facts-cb7b6
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

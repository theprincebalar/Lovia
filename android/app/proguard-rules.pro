# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Google & Firebase Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# RevenueCat In-App Purchases
-keep class com.revenuecat.purchases.** { *; }
-dontwarn com.revenuecat.purchases.**

# Google Play In-App Review & Core
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# AndroidX & Security
-dontwarn androidx.**
-keep class androidx.preference.** { *; }
-keep class androidx.security.** { *; }

# Webview Flutter
-keep class io.flutter.plugins.webviewflutter.** { *; }
-dontwarn io.flutter.plugins.webviewflutter.**

# Audio & Speech
-dontwarn com.google.android.exoplayer2.**
-dontwarn androidx.media3.**

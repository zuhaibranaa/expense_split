# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# SLF4J - Fix for missing class org.slf4j.impl.StaticLoggerBinder
-dontwarn org.slf4j.**
-keep class org.slf4j.** { *; }

# Gson
-keep class com.google.gson.** { *; }

# General
-dontwarn javax.annotation.**
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod

# Google Play Core
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Google Sign-In
-keep class com.google.android.gms.auth.api.signin.** { *; }
-dontwarn com.google.android.gms.auth.api.signin.**

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

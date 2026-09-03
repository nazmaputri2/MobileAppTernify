## Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

## Gson (jika digunakan)
-keepattributes Signature
-keepattributes *Annotation*

## Google Sign-In
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

## Play Core (deferred components)
-dontwarn com.google.android.play.core.**


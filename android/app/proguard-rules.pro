# Flutter & plugins (reflection)
-keep class io.flutter.plugins.** { *; }
-keep class com.dexterous.** { *; }        # flutter_local_notifications

# AndroidX support used by notifications
-keep class androidx.core.app.** { *; }
-dontwarn androidx.core.**

# Kotlin – avoid stripping needed metadata
-dontwarn kotlin.**
-keep class kotlin.** { *; }
-keepclassmembers class kotlin.Metadata { *; }

# Keep annotations/signatures
-keepattributes *Annotation*
-keepattributes Signature

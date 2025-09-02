#   proguard
   # Flutter specific rules (usually already present)
   -keep class io.flutter.app.** { *; }
   -keep class io.flutter.plugin.**  { *; }
   -keep class io.flutter.util.**  { *; }
   -keep class io.flutter.view.**  { *; }
   -keep class io.flutter.embedding.**  { *; }
   -keepattributesប្បSourceFile,LineNumberTable

   # Rules for flutter_local_notifications
   -keep public class com.dexterous.flutterlocalnotifications.** { *; }
   -keep class androidx.core.app.NotificationCompat$*

   # If you use permission_handler and it has native parts for specific checks
   # (though for POST_NOTIFICATIONS it might be simpler, exact_alarm is more complex)
   # you might need rules for it too, check its documentation.
   # Example: -keep class com.baseflow.permissionhandler.** { *; }

   # Please add these rules to your existing keep rules in order to suppress warnings.
   # This is generated automatically by the Android Gradle plugin.
   -dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
   -dontwarn com.google.android.play.core.splitinstall.SplitInstallException
   -dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
   -dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
   -dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
   -dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
   -dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
   -dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
   -dontwarn com.google.android.play.core.tasks.OnFailureListener
   -dontwarn com.google.android.play.core.tasks.OnSuccessListener
   -dontwarn com.google.android.play.core.tasks.Task
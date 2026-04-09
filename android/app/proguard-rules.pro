-keep class com.antonkarpenko.ffmpegkit.** { *; }

# Release minify: R8 strips io.flutter.util.PathUtils; path_provider_android loads it at
# runtime → ClassNotFoundException when creating app storage paths (recording, etc.).
-keep class io.flutter.util.** { *; }
-keep class io.flutter.embedding.** { *; }

# Flutter embedding references Play Core (deferred components) optionally; those classes are
# not on the classpath. R8 otherwise fails the release build.
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

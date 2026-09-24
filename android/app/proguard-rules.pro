# Flutter and its plugins ship their own consumer rules; these keep the audio
# plugins' platform-channel classes safe under R8 as a belt-and-braces measure.
-keep class com.llfbandit.record.** { *; }
-keep class com.ryanheise.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }
-keep class dev.fluttercommunity.plus.wakelock.** { *; }
-dontwarn com.google.android.play.core.**

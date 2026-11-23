# Preserve annotations, generic signatures, and inner classes used by JSON/Flutter plugins
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# flutter_local_notifications (scheduled alarms, boot receivers, Gson models)
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepclassmembers class com.dexterous.flutterlocalnotifications.** { *; }

# Firebase Core, Messaging, Installers & GMS
-keep class com.google.firebase.** { *; }
-keepclassmembers class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**

# Gson serialized notification payload classes
-keep class com.google.gson.** { *; }
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# AndroidX NotificationCompat & core components
-keep class androidx.core.app.** { *; }
-keep class androidx.media.** { *; }

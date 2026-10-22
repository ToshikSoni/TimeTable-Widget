# Picked up automatically by the Flutter Gradle plugin for minified release builds.

# flutter_local_notifications stores scheduled notifications as JSON via Gson. Recent Gson
# versions ship their own consumer rules; these keep older/edge cases from losing generic types.
-keepattributes Signature
-keepattributes *Annotation*
-keep class * extends com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
-keep class com.dexterous.** { *; }

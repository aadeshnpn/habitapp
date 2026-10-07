# flutter_local_notifications uses Gson TypeToken to persist schedules.
# R8 full mode strips generic signatures and breaks zonedSchedule in release:
# "TypeToken must be created with a type argument"

-keep class com.dexterous.** { *; }

-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

-keepattributes Signature
-keepattributes *Annotation*

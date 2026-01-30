# ================================
# ProGuard Rules for Twain
# ================================

# ================================
# Google Play Services & Core
# ================================
-keep class com.google.android.gms.** { *; }
-keep interface com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Google Play Core (Split APKs, Dynamic Delivery, In-App Updates)
-keep class com.google.android.play.core.** { *; }
-keep interface com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication

# ================================
# Google Sign-In (Critical)
# ================================
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.auth.api.credentials.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.common.api.** { *; }
-keep interface com.google.android.gms.common.api.** { *; }

# Credential Manager (newer Google Sign-In flow)
-keep class com.google.android.libraries.identity.googleid.** { *; }
-keep class androidx.credentials.** { *; }
-keep interface androidx.credentials.** { *; }
-dontwarn androidx.credentials.**

# ================================
# Firebase
# ================================
-keep class com.google.firebase.** { *; }
-keep interface com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Firebase Auth
-keep class com.google.firebase.auth.** { *; }

# Firebase Messaging
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.iid.** { *; }

# ================================
# Google API Client
# ================================
-keep class com.google.api.** { *; }
-keep class com.google.api.client.** { *; }
-dontwarn com.google.api.**

# ================================
# Flutter
# ================================
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Flutter Google Sign-In Plugin
-keep class io.flutter.plugins.googlesignin.** { *; }

# ================================
# Supabase / GoTrue
# ================================
-keep class io.supabase.** { *; }
-keep class com.supabase.** { *; }
-dontwarn io.supabase.**
-dontwarn com.supabase.**

# ================================
# Kotlin
# ================================
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.**

# Kotlin serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt

-keepclassmembers class kotlinx.serialization.json.** {
    *** Companion;
}
-keepclasseswithmembers class kotlinx.serialization.json.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# ================================
# OkHttp / Retrofit (if used)
# ================================
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# ================================
# General Java Rules
# ================================
# Keep attributes for reflection
-keepattributes Signature
-keepattributes Exceptions
-keepattributes SourceFile,LineNumberTable
-keepattributes *Annotation*
-keepattributes AnnotationDefault
-keepattributes RuntimeVisibleAnnotations
-keepattributes RuntimeVisibleParameterAnnotations
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelables
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# Keep Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ================================
# AndroidX
# ================================
-keep class androidx.** { *; }
-keep interface androidx.** { *; }
-dontwarn androidx.**

# AndroidX Browser (Custom Tabs)
-keep class androidx.browser.** { *; }

# ================================
# Suppress warnings for missing classes
# ================================
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**
-dontwarn sun.misc.Unsafe

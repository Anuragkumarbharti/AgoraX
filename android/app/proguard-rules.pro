# Flutter & Engine Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class io.flutter.enum.** { *; }
-dontwarn io.flutter.embedding.**

# Keep All Application Models & DTOs
-keep class com.example.creania.** { *; }
-keep class **.models.** { *; }
-keep class **.services.** { *; }
-keep class **.core.** { *; }

# Isar Database Proguard Rules
-keep class io.isar.** { *; }
-dontwarn io.isar.**
-keep class * extends io.isar.IsarCollection { *; }
-keep class * extends io.isar.IsarEmbedded { *; }
-keep class **.Isar* { *; }
-keepclassmembers class * {
    @io.isar.annotation.* <fields>;
    @io.isar.annotation.* <methods>;
}

# Supabase & Realtime & Postgrest Rules
-keep class com.supabase.** { *; }
-keep class io.supabase.** { *; }
-keep class realtime.** { *; }
-keep class postgrest.** { *; }
-keep class gotrue.** { *; }
-dontwarn com.supabase.**

# Encryption / Crypto / PointyCastle / Key Generators
-keep class com.encrypt.** { *; }
-keep class org.bouncycastle.** { *; }
-keep class com.pointycastle.** { *; }
-dontwarn org.bouncycastle.**
-dontwarn com.pointycastle.**

# Zego & Razorpay
-keep class com.razorpay.** {*;}
-dontwarn com.razorpay.**
-keep class **.zego.** { *; }
-dontwarn **.zego.**

# Gson & Jackson & Json Serialization
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keep class com.google.gson.** { *; }

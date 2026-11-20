# WorkManager (pulled in by the Google Mobile Ads SDK) builds its Room database by reflection.
# Without these, R8 strips the generated *_Impl classes and the app crashes on launch with
# "Failed to create an instance of androidx.work.impl.WorkDatabase".
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.room.** { *; }
-dontwarn androidx.room.paging.**

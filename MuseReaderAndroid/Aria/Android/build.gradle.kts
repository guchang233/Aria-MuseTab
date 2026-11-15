// Share the Android plugin classpath with the app and install-time asset pack.
plugins {
    id("com.chaquo.python") version "17.2.0" apply false
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.library) apply false
}

# Regras ProGuard/R8 para o build release.
# O Flutter ja injeta as regras essenciais do engine; aqui mantemos apenas o
# que e acessado por reflexao/plataforma e poderia ser removido por engano.

# Flutter embedding e plugins registrados via reflexao.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# Plugin nativo de envio de e-mail (referenciado por nome no MainActivity).
-keep class com.controlevalidades.controle_validades.** { *; }

# Mantem nomes de classes nativas Android (evita avisos de R8 com bibliotecas).
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses,EnclosingMethod

# Suprime avisos de classes opcionais de dependencias (ex.: Play Core/Tink).
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**

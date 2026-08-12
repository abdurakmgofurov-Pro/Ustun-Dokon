# google_mlkit_text_recognition faqat lotin (Latin) skriptini ishlatadi.
# Xitoy/yapon/koreys/devanagari uchun ixtiyoriy classlar loyihaga
# qo'shilmagan — R8 ularni "compileOnly" havolalar sifatida topolmay
# ogohlantiradi, lekin bu runtime'da muammo emas.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

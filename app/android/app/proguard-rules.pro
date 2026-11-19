# Reconocimiento de texto (google_mlkit_text_recognition): la app usa solo el
# alfabeto latino. El plugin menciona los reconocedores de chino, devanagari,
# japonés y coreano, que no se incluyen; sin estas reglas R8 se detiene en la
# compilación de lanzamiento por clases "faltantes" que nunca se llaman.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

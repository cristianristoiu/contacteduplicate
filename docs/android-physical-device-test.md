# Testare Android pe device fizic

## Cerinte locale

- Flutter SDK instalat si disponibil in PATH.
- Android Studio sau Android SDK instalat.
- Device Android cu Developer options si USB debugging activate.
- Repository sincronizat cu `main`.

## Pregatire

```powershell
flutter doctor
flutter pub get
```

Daca folderul Android local nu are fisierele de Gradle wrapper generate de Flutter, ruleaza o singura data:

```powershell
flutter create --platforms=android .
```

Dupa aceasta comanda se verifica manual ca fisierele proiectului existente nu au fost suprascrise nedorit.

## Rulare pe device fizic

```powershell
flutter devices
flutter run -d <DEVICE_ID>
```

## Build APK debug

```powershell
flutter build apk --debug
```

## Verificari minime

- Aplicatia porneste fara crash.
- Splash screen-ul se incarca.
- Dashboard-ul se deschide.
- Tema light/dark nu produce erori vizuale majore.
- Nu se face nicio modificare de contacte fara flux explicit de permisiune, backup si confirmare.

# Contacte Duplicate - plan tehnic Android si iOS

## Scop tehnic

Aplicatia gaseste si uneste contactele duplicate din agenda telefonului si din conturile sincronizate in aplicatia nativa de contacte, in limitele permise de Android si iOS.

Principiu critic: contactele nu se incarca in cloud. Scanarea, scorul, backup-ul si merge-ul ruleaza local pe dispozitiv.

## Platforme tinta

- Android: telefoane si tablete moderne, target SDK curent la momentul publicarii.
- iOS: iPhone, cu suport pentru versiunea minima stabilita la startul implementarii.
- UI: Flutter 3.x.
- Cod nativ: Kotlin pentru Android, Swift pentru iOS.

## Arhitectura recomandata

```text
lib/
  app/
    app.dart
    router.dart
    theme/
  core/
    errors/
    permissions/
    privacy/
    storage/
    utils/
  features/
    onboarding/
    dashboard/
    contacts_scan/
    duplicates/
    merge/
    backup/
    history/
    settings/
  domain/
    entities/
    repositories/
    use_cases/
  data/
    local/
    repositories/
    mappers/
  platform/
    contacts_channel.dart
    contacts_platform_models.dart
android/
  app/src/main/kotlin/.../contacts/
ios/
  Runner/Contacts/
```

## Tehnologie

### Flutter

- UI cross-platform.
- State management: Riverpod sau Bloc. Se alege una si se pastreaza consecvent.
- Navigatie: GoRouter sau Navigator 2.0.
- Persistenta locala: SQLite/Drift sau Isar. Pentru MVP, Drift este suficient si predictibil.

### Android

- Limbaj: Kotlin.
- API: Contacts Provider / ContactsContract.
- Permisiuni:
  - `READ_CONTACTS` pentru scanare.
  - `WRITE_CONTACTS` doar pentru operatii de unire/modificare.
- `READ_CONTACTS` si `WRITE_CONTACTS` sunt permisiuni cu protection level `dangerous`, deci necesita cerere runtime si explicatie clara.

### iOS

- Limbaj: Swift.
- API: Contacts framework / CNContactStore.
- Permisiune in `Info.plist`: `NSContactsUsageDescription`.
- Citirea si procesarea trebuie facute in background, fara blocarea UI.
- Separarea contactelor pe surse Google/iCloud poate fi limitata de API; nu se promite in UI daca nu poate fi determinata corect.

## Permisiuni si explicatii

### AndroidManifest.xml

Permisiuni permise in MVP:

```xml
<uses-permission android:name="android.permission.READ_CONTACTS" />
<uses-permission android:name="android.permission.WRITE_CONTACTS" />
```

Regula UX:

- `READ_CONTACTS` se cere cand utilizatorul porneste scanarea sau apasa `Permite accesul la contacte`.
- `WRITE_CONTACTS` se cere doar inainte de prima modificare reala.
- Cererea runtime trebuie precedata de un ecran in-app cu explicatie clara.

Text recomandat:

```text
Aplicatia are nevoie de acces la contacte pentru a gasi duplicatele. Datele raman pe dispozitiv si nu sunt incarcate in cloud.
```

### iOS Info.plist

```xml
<key>NSContactsUsageDescription</key>
<string>Aplicatia foloseste contactele pentru a gasi si uni duplicatele direct pe dispozitiv. Datele nu sunt incarcate in cloud.</string>
```

## Model de date

### ContactEntity

- id
- nativeId
- rawContactId
- sourceId
- sourceName
- displayName
- givenName
- familyName
- phones
- emails
- addresses
- company
- jobTitle
- birthday
- notesAvailable
- photoAvailable
- isFavorite
- isReadOnly
- updatedAt

### DuplicateGroup

- id
- contacts
- proposedPrimaryContactId
- matchReasons
- confidenceScore
- confidenceLabel
- requiresManualReview
- canBeMerged

### MergePlan

- groupId
- primaryContactId
- selectedFields
- mergedPhones
- mergedEmails
- conflicts
- skippedFields
- backupId

### BackupRecord

- id
- type
- filePath
- contactsCount
- createdAt
- reason
- canRestore

### OperationHistory

- id
- type
- affectedContacts
- result
- backupId
- createdAt
- errorMessage

## Algoritm duplicate

1. Citeste contactele permise.
2. Normalizeaza numele, telefoanele si emailurile.
3. Creeaza indexuri dupa telefon, email, nume si companie.
4. Genereaza grupuri candidate.
5. Calculeaza scorul de incredere.
6. Elimina false positive evidente.
7. Marcheaza grupurile nesigure pentru verificare manuala.
8. Afiseaza lista de grupuri.
9. Creeaza MergePlan dupa alegerea utilizatorului.
10. Creeaza backup.
11. Cere confirmare finala.
12. Executa merge-ul.
13. Salveaza istoric si rezultat.

## Scor de incredere

| Scor | Eticheta | Regula |
| --- | --- | --- |
| 95-100 | Sigur | telefon sau email identic/normalizat |
| 80-94 | Probabil | nume identic + camp compatibil |
| 60-79 | Verifica manual | nume similar + semnale slabe |
| sub 60 | Ignorat implicit | risc mare de false positive |

Regula obligatorie: nu se face auto-selectie sub 95.

## Backup si restaurare

Inainte de orice modificare:

- se creeaza backup local
- se salveaza raportul operatiei
- se afiseaza utilizatorului ca backup-ul a fost creat

Format recomandat pentru export:

- VCF pentru compatibilitate cu agenda telefonului.
- JSON intern pentru istoricul exact al merge-ului, daca este necesar pentru undo.

## Contacte read-only

Aplicatia nu trebuie sa presupuna ca toate contactele pot fi modificate.

Comportament:

- daca sursa/contactul este read-only, contactul este afisat ca limitat
- nu se incearca scriere fortata
- utilizatorul primeste mesaj clar

Text recomandat:

```text
Acest contact nu poate fi modificat din aplicatie. Sursa lui este read-only sau restrictionata de sistem.
```

## Privacy si store compliance

Contactele si phonebook-ul sunt date personale si sensibile. Aplicatia trebuie sa fie transparenta, sa limiteze accesul la functionalitatea principala si sa foloseasca cereri runtime de permisiuni.

Reguli:

- fara upload in cloud
- fara reclame in MVP
- fara analytics care colecteaza contacte
- fara crash reports care includ date de contact
- fara loguri cu nume, telefon sau email
- politica de confidentialitate publica, accesibila in aplicatie si in store listing
- Data Safety / App Privacy completate conform comportamentului real

## Publicare

### Google Play

- Build Android App Bundle (`.aab`).
- Semnare cu Play App Signing.
- Privacy Policy URL public, non-PDF.
- Data Safety completat corect.
- Permisiunile de contacte justificate prin functionalitatea principala.

### Apple App Store

- Build prin Xcode / Codemagic / GitHub Actions macOS.
- Privacy Policy URL in App Store Connect si in aplicatie.
- App Privacy completat corect.
- `NSContactsUsageDescription` clar si specific.
- Se folosesc doar API-uri publice.

## Referinte oficiale

- Android Contacts Provider: https://developer.android.com/identity/providers/contacts-provider
- Android Manifest permissions: https://developer.android.com/reference/android/Manifest.permission
- Google Play User Data policy: https://support.google.com/googleplay/android-developer/answer/10144311
- Apple App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Apple Contacts framework: https://developer.apple.com/documentation/contacts

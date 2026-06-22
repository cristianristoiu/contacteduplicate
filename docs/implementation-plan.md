# Contacte Duplicate - plan de implementare detaliat (1000 commit-uri)

## Obiectiv

Construirea unei aplicații mobile Android și iOS care găsește, verifică și unește contactele duplicate local pe dispozitiv, fără upload în cloud și cu flux complet de backup și confirmare.

## Reguli obligatorii pentru dezvoltare

1. **Numerotare**: Toate commit-urile folosesc formatul `<WORK_CODE><NUMAR> - <DESCRIERE>`.
2. **Granularitate**: Fiecare commit trebuie să fie atomic. Nu se amestecă refactorizarea cu funcționalități noi.
3. **Paralelizare**: Se folosesc interfețe (`abstract class`) pentru servicii pentru a permite mock-uirea și lucrul în paralel.
4. **Testare**: Fiecare funcționalitate critică (algoritmi, servicii de date) are un commit dedicat pentru teste.
5. **Fără PII**: Nu se loghează date personale (nume, telefoane, email-uri).

---

## FAZA 0: Infrastructură, Configurare și Design System (Commit-uri 0001 - 0150)

### Infrastructură Proiect (0001 - 0030)
- ~~<WORK_CODE>0001 - Inițializare repository și adăugare documentație proiect.~~ COMPLETAT (JNI0001)
- ~~<WORK_CODE>0002 - Adăugare materiale vizuale pentru design.~~ COMPLETAT (CHT0002)
- ~~<WORK_CODE>0003 - Adăugare mockup overview pentru design.~~ COMPLETAT (CHT0003)
- ~~<WORK_CODE>0004 - Adăugare ecran dashboard pentru design.~~ COMPLETAT (CHT0004)
- ~~<WORK_CODE>0005 - Refacere logo-ul după direcția inițială.~~ COMPLETAT (CHT0005)
- ~~<WORK_CODE>0006 - Încărcare preview app.~~ COMPLETAT (CRS00006)
- ~~<WORK_CODE>0007 - Actualizare logo-ul pentru aplicație.~~ COMPLETAT (CHT0007)
- ~~<WORK_CODE>0008 - Adăugare ghidul temei vizuale.~~ COMPLETAT (CHT0008)
- ~~<WORK_CODE>0009 - Adăugare planul tehnic Android și iOS.~~ COMPLETAT (CHT0009)
- ~~<WORK_CODE>0010 - Adăugare planul de implementare.~~ COMPLETAT (CHT0010)
- ~~<WORK_CODE>0011 - Adăugare checklist pentru publicare în store.~~ COMPLETAT (CHT0011)
- ~~<WORK_CODE>0012 - Actualizare planul proiectului.~~ COMPLETAT (CHT0012)
- ~~<WORK_CODE>0013 - Adăugare foreground pentru icon adaptiv.~~ COMPLETAT (CHT0013)
- ~~<WORK_CODE>0014 - Adăugare background pentru icon adaptiv.~~ COMPLETAT (CHT0014)
- ~~<WORK_CODE>0015 - Refacere logo.svg conform preview-logo.png.~~ COMPLETAT (JNI0015)
- ~~<WORK_CODE>0016 - Actualizare logo (fără fundal) și creare variante iconițe Android/iOS.~~ COMPLETAT (JNI0016)
- ~~<WORK_CODE>0017 - Extindere plan implementare la 1000 commit-uri și structurare pentru lucru în paralel.~~ COMPLETAT (JNI0017)
- ~~<WORK_CODE>0018 - Inițializare proiect Flutter brut.~~ COMPLETAT (CHT0018)
- ~~<WORK_CODE>0019 - Configurare gitignore pentru Flutter și mobil.~~ COMPLETAT (CHT0019)
- ~~<WORK_CODE>0020 - Configurare regulile de analiză Dart.~~ COMPLETAT (CHT0020)
- ~~<WORK_CODE>0021 - Adăugare logo-ul aplicației în assets.~~ COMPLETAT (CHT0021)
- ~~<WORK_CODE>0022 - Crearea punctului de intrare Flutter.~~ COMPLETAT (CHT0022)
- ~~<WORK_CODE>0023 - Configurare aplicație principală Flutter.~~ COMPLETAT (CHT0023)
- ~~<WORK_CODE>0024 - Implementare paletă de culori.~~ COMPLETAT (CHT0024)
- ~~<WORK_CODE>0025 - Adăugare stiluri de text globale.~~ COMPLETAT (CHT0025)
- ~~<WORK_CODE>0026 - Configurare teme light și dark.~~ COMPLETAT (CHT0026)
- ~~<WORK_CODE>0027 - Implementare provider pentru temă.~~ COMPLETAT (CHT0027)
- ~~<WORK_CODE>0028 - Configurare localizare de bază.~~ COMPLETAT (CHT0028)
- ~~<WORK_CODE>0029 - Adăugare logger fără PII.~~ COMPLETAT (CHT0029)
- ~~<WORK_CODE>0030 - Configurare rute principale.~~ COMPLETAT (CHT0030)

### UI Components & Layout (0031 - 0100)
- ~~<WORK_CODE>0031 - Adăugare buton primar reutilizabil.~~ COMPLETAT (CHT0031)
- ~~<WORK_CODE>0032 - Adăugare buton secundar reutilizabil.~~ COMPLETAT (CHT0032)
- ~~<WORK_CODE>0033 - Adăugare card UI reutilizabil.~~ COMPLETAT (CHT0033)
- ~~<WORK_CODE>0034 - Implementare layout principal brut.~~ COMPLETAT (CHT0034)
- ~~<WORK_CODE>0035 - Adăugare splash screen brut.~~ COMPLETAT (CHT0035)
- ~~<WORK_CODE>0036 - Adăugare dashboard brut.~~ COMPLETAT (CHT0036)
- ~~<WORK_CODE>0037 - Adăugare ecran brut de setări.~~ COMPLETAT (CHT0037)
- ~~<WORK_CODE>0038 - Adăugare structură Android de bază.~~ COMPLETAT (CHT0038)
- ~~<WORK_CODE>0039 - Configurare build Android rădăcină.~~ COMPLETAT (CHT0039)
- ~~<WORK_CODE>0040 - Configurare modul Android app.~~ COMPLETAT (CHT0040)
- ~~<WORK_CODE>0041 - Adăugare manifest Android cu permisiuni contacte.~~ COMPLETAT (CHT0041)
- ~~<WORK_CODE>0042 - Adăugare MainActivity Android.~~ COMPLETAT (CHT0042)
- ~~<WORK_CODE>0043 - Adăugare stil de lansare Android.~~ COMPLETAT (CHT0043)
- ~~<WORK_CODE>0044 - Adăugare Info plist pentru iOS.~~ COMPLETAT (CHT0044)
- ~~<WORK_CODE>0045 - Adăugare AppDelegate pentru iOS.~~ COMPLETAT (CHT0045)
- ~~<WORK_CODE>0046 - Marcare taskuri brute finalizate în plan.~~ COMPLETAT (CHT0046)
- ~~<WORK_CODE>0047 - Clarificare numerotare reală în plan.~~ COMPLETAT (CHT0047)
- ~~<WORK_CODE>0048 - Restaurare format work code în plan.~~ COMPLETAT (CHT0048)
- ~~<WORK_CODE>0049 - Renumerotare plan implementare.~~ COMPLETAT (CHT0049)
- ~~<WORK_CODE>0050 - Refacere plan de implementare detaliat (1000 commit-uri) și mapare istoric.~~ COMPLETAT (JNI0050)
- ~~<WORK_CODE>0051 - Creare widget `AppLogo` cu suport pentru diferite dimensiuni.~~ COMPLETAT (JNI0051)
- ~~<WORK_CODE>0052 - Implement argument `StatusBadge` pentru scorul de încredere.~~ COMPLETAT (JNI0052)
- ~~<WORK_CODE>0053 - Creare widget `ContactAvatar`: definire structură de bază și suport pentru imagine circulară.~~ COMPLETAT (JNI0053)
- ~~<WORK_CODE>0054 - Creare widget `ContactAvatar`: implementare fallback pentru inițiale (extragere prima literă din nume).~~ COMPLETAT (JNI0054)
- ~~<WORK_CODE>0055 - Creare widget `ContactAvatar`: aplicare paletă de culori pentru fundalul avatarului bazat pe hash-ul numelui.~~ COMPLETAT (JNI0055)
- ~~<WORK_CODE>0056 - Creare widget `ContactAvatar`: adăugare suport pentru bordură și umbră conform `theme-guide.md`.~~ COMPLETAT (JNI0056)
- ~~<WORK_CODE>0057 - Implementare `AppDivider`: creare widget personalizat care folosește `AppColors.lightBorder` și `AppColors.darkBorder`.~~ COMPLETAT (JNI0057)
- ~~<WORK_CODE>0058 - Implementare `AppDivider`: adăugare parametri pentru grosime, indentare și orientare (vertical/orizontal).~~ COMPLETAT (JNI0058)
- ~~<WORK_CODE>0059 - Creare widget `AppLoadingIndicator`: implementare animație de rotație folosind `brandBlue500` și `brandViolet500`.~~ COMPLETAT (JNI0059)
- ~~<WORK_CODE>0060 - Creare widget `AppLoadingIndicator`: adăugare suport pentru dimensiuni variabile (mic, mediu, mare).~~ COMPLETAT (JNI0060)
- <WORK_CODE>0061 - Implementare `AppEmptyState`: creare layout de bază cu iconiță centrală (48dp), titlu (H2) și descriere (Body2).
- <WORK_CODE>0062 - Implementare `AppEmptyState`: adăugare suport pentru ilustrații SVG din `AppAssets` folosind `flutter_svg`.
- <WORK_CODE>0063 - Implementare `AppEmptyState`: integrare buton de acțiune opțional de tip `PrimaryButton` (ex: "Scanează acum").
- <WORK_CODE>0064 - Creare `AppErrorState`: implementare widget pentru afișarea erorilor cu iconiță `Icons.error_outline` (culoare `AppColors.error`).
- <WORK_CODE>0065 - Creare `AppErrorState`: adăugare buton de "Retry" cu callback configurabil, stilizat ca `SecondaryButton`.
- <WORK_CODE>0066 - Implementare `AppBottomBar`: definire structură `BottomNavigationBar` custom cu 4 itemi (Acasă, Duplicate, Backup, Setări).
- <WORK_CODE>0067 - Implementare `AppBottomBar`: aplicare stiluri vizuale (blur fundal 10px, selecție cu gradient `brandGradient`, înălțime 64dp).
- <WORK_CODE>0068 - Rafinare `PrimaryButton`: adăugare stare de loading, înlocuind textul cu `AppLoadingIndicator.small()` alb.
- <WORK_CODE>0069 - Rafinare `PrimaryButton`: implementare stare de `disabled` (opacitate 0.5, `pointerEvents: none`).
- <WORK_CODE>0070 - Rafinare `PrimaryButton`: adăugare suport pentru `icon` (Widget opțional) poziționat la 8dp de text.
- <WORK_CODE>0071 - Creare `IconButton` personalizat: suport pentru forme `circle` și `roundedRect` (radius 12dp), dimensiune default 40dp.
- <WORK_CODE>0072 - Creare `IconButton` personalizat: implementare efect de "splash" folosind `InkWell` cu culoarea `AppColors.blue500.withOpacity(0.1)`.
- <WORK_CODE>0073 - Implementare widget `SectionHeader`: layout `Row` cu titlu (H3) și buton text "Vezi tot" (Label style, `AppColors.blue500`).
- <WORK_CODE>0074 - Implementare widget `SectionHeader`: adăugare padding orizontal standard de 16dp și vertical de 8dp.
- <WORK_CODE>0075 - Creare widget `SettingsTile`: implementare rând (înălțime minimă 56dp) cu iconiță, titlu, subtitlu opțional.
- <WORK_CODE>0076 - Creare widget `SettingsTile`: adăugare suport pentru `trailing` widget (Switch, Chevron, sau Text informativ).
- <WORK_CODE>0077 - Adăugare `AppSwitch`: personalizare `Switch.adaptive` pentru a folosi `AppColors.blue500` (active) și `surfaceMuted` (inactive).
- <WORK_CODE>0078 - Implementare widget `AppTextField`: creare input cu `borderRadius` 12dp, `contentPadding` 16dp, iconiță de căutare prefix.
- <WORK_CODE>0079 - Implementare widget `AppTextField`: adăugare logică pentru buton "Clear" (suffix icon) care apare doar când există text.
- <WORK_CODE>0080 - Creare `BadgeCount`: widget circular (20dp) cu fundal `AppColors.error` și text alb (Caption, bold).
- <WORK_CODE>0081 - Implementare `AnimatedCard`: integrare `AnimatedOpacity` și `SlideTransition` pentru intrare lină în listă (300ms).
- <WORK_CODE>0082 - Creare widget `ProgressRing`: implementare cerc de progres (80dp, stroke 8dp) folosind `CustomPainter`.
- <WORK_CODE>0083 - Creare widget `ProgressRing`: adăugare animație `Tween` pentru umplere și text central cu procent (H2 style).
- <WORK_CODE>0084 - Adăugare suport pentru gradienți în `AppCard`: proprietate `gradient` care suprascrie `color` (folosind `BoxDecoration`).
- <WORK_CODE>0085 - Implementare sistem de umbre: definire `AppBoxShadows.soft` (blur 8, spread 0, opacity 0.05).
- <WORK_CODE>0086 - Creare widget `InfoBox`: layout tip "callout" cu fundal albastru pal, iconiță de info și padding 12dp.
- <WORK_CODE>0087 - Rafinare Splash Screen: animație secvențială (Logo fade-in 500ms -> Title slide-up 500ms).
- <WORK_CODE>0088 - Implementare `AppDialog`: fundal `Colors.black54`, container cu blur `BackdropFilter` și padding 24dp.
- <WORK_CODE>0089 - Creare `ConfirmationDialog`: dialog predefinit cu titlu, mesaj, buton "Anulează" (secundar) și "Confirmă" (danger style).
- <WORK_CODE>0090 - Implementare `AppBottomSheet`: folosire `showModalBottomSheet` cu margini rotunjite sus (20dp) și handle bar central.
- <WORK_CODE>0091 - Creare `SelectionListTile`: rând cu `Checkbox` personalizat și text care ocupă tot spațiul rămas.
- <WORK_CODE>0092 - Adăugare suport pentru "Haptic Feedback": apelare `HapticFeedback.mediumImpact()` în `onPressed` al butoanelor.
- <WORK_CODE>0093 - Creare widget `MergeFieldRow`: afișare două valori comparate cu highlight roșu pe diferențe (folosind `TextSpan`).
- <WORK_CODE>0094 - Implementare `SearchEmptyState`: specializare a `AppEmptyState` cu iconiță `Icons.search_off` și text specific.
- <WORK_CODE>0095 - Creare widget `SummaryCard`: card mic (100x100) cu iconiță top-left și cifră mare centrală (H1).
- <WORK_CODE>0096 - Implementare `AppSkeletonLoader`: efect de pulse (opacitate 0.3 -> 0.7) pentru placeholder-e dreptunghiulare.
- <WORK_CODE>0097 - Creare `SkeletonLoader` pentru Listă: rând cu cerc placeholder (avatar) și două linii gri (nume/tel).
- <WORK_CODE>0098 - Adăugare `AppBlur`: widget utilitar ce aplică `ImageFiltered` sau `BackdropFilter` cu `sigmaX: 5, sigmaY: 5`.
- <WORK_CODE>0099 - Implementare widget `LanguageSelector`: listă tip `RadioListTile` într-un dialog pentru RO și EN.
- <WORK_CODE>0100 - Creare `ThemeSelector`: toggle switch între Soare/Lună sau listă cu opțiunile: Light, Dark, System.
- <WORK_CODE>0101 - Audit UI: verificare aliniere la grid-ul de 8dp și consistența culorilor folosind un Debug Tooling intern.

### Localization & Asset Management (0102 - 0150)
- <WORK_CODE>0102 - Configurare `Intl` pentru suport plural: reguli gramaticale RO (1, puține, multe) vs EN.
- <WORK_CODE>0103 - Adăugare traduceri RO: fișier `app_ro.arb` cu texte pentru Onboarding (titluri, descrieri).
- <WORK_CODE>0104 - Adăugare traduceri EN: fișier `app_en.arb` cu texte pentru Onboarding.
- <WORK_CODE>0105 - Adăugare traduceri RO: texte Dashboard (scor, butoane acțiune, statistici).
- <WORK_CODE>0106 - Adăugare traduceri EN: texte Dashboard.
- <WORK_CODE>0107 - Adăugare traduceri RO: Listă Duplicate (header, filter chips, sort options).
- <WORK_CODE>0108 - Adăugare traduceri EN: Listă Duplicate.
- <WORK_CODE>0109 - Adăugare traduceri RO: Detalii Merge (nume câmpuri, avertismente, success message).
- <WORK_CODE>0110 - Adăugare traduceri EN: Detalii Merge.
- <WORK_CODE>0111 - Adăugare traduceri RO: Backup & Restaurare (vCard export, import history).
- <WORK_CODE>0112 - Adăugare traduceri EN: Backup & Restaurare.
- <WORK_CODE>0113 - Adăugare traduceri RO: Setări (temă, limbă, despre, reset).
- <WORK_CODE>0114 - Adăugare traduceri EN: Setări.
- <WORK_CODE>0115 - Adăugare mesaje eroare RO/EN: lipsă permisiuni, eroare citire, disc plin, merge failed.
- <WORK_CODE>0116 - Implementare `AppLanguageService`: utilizare `shared_preferences` pentru salvarea preferinței de limbă.
- <WORK_CODE>0117 - Adăugare asset-uri SVG: `merge.svg`, `scan.svg`, `delete.svg` în `assets/icons/actions/`.
- <WORK_CODE>0118 - Adăugare asset-uri SVG: `work.svg`, `home.svg`, `phone.svg`, `email.svg` în `assets/icons/contact/`.
- <WORK_CODE>0119 - Optimizare SVG: rulare `svgo` pe toate iconițele pentru a elimina metadata inutilă.
- <WORK_CODE>0120 - Script CI (Dart): verificare automată dacă toate cheile din `app_ro.arb` există și în `app_en.arb`.
- <WORK_CODE>0121 - Asset-uri audio: `success.mp3`, `click.wav` (low latency, sub 100ms).
- <WORK_CODE>0122 - Configurare Fonts: adăugare `Inter-Regular.ttf`, `Inter-Bold.ttf` în `pubspec.yaml`.
- <WORK_CODE>0123 - Implementare `AppAssets`: clasă cu rute statice (`static const String logo = 'assets/brand/logo.svg'`).
- <WORK_CODE>0124 - Placeholder contact: generare SVG programatic sau asset cu profil generic (gri neutru).
- <WORK_CODE>0125 - Ilustrații Empty State: `no_duplicates.svg`, `all_clean.svg` (stil minimalist, culori brand).
- <WORK_CODE>0126 - Ilustrații Onboarding: `local_privacy.svg`, `secure_backup.svg` (dimensiune optimă 200x200).
- <WORK_CODE>0127 - Configurare `l10n.yaml`: `output-dir: lib/core/l10n`, `template-arb-file: app_en.arb`.
- <WORK_CODE>0128 - Unit Test: `AppLanguageService` - verificare schimbare locale și persistență.
- <WORK_CODE>0129 - Audit UI Localizare: verificare overflow text pentru limba RO (care e de obicei mai lungă cu 20%).
- <WORK_CODE>0130 - Normalizare Căutare: funcție de eliminare diacritice (ș->s, ț->t) folosind tabele de mapping.
- <WORK_CODE>0131 - Audit Cod: scanare recursivă pentru string-uri între ghilimele neînregistrate în ARB.
- <WORK_CODE>0132-0150 - Pregătire Faza 1: Verificare compatibilitate asset-uri pe ecrane cu densitate mare (Retina/High-res).

---

## FAZA 1: Onboarding, Permisiuni și Securitate (Commit-uri 0151 - 0300)

### Onboarding Flow (0151 - 0200)
- <WORK_CODE>0151 - Creare `OnboardingModel`: definire titlu, descriere, assetPath și backgroundGradient (din `AppColors`).
- <WORK_CODE>0152 - Implementare `OnboardingController`: folosire `StateNotifier` sau `Cubit` pentru gestionarea indexului curent (0-2).
- <WORK_CODE>0153 - Creare `OnboardingScreen`: structură cu `Stack` (fundal gradient), `PageView` central și butoane jos.
- <WORK_CODE>0154 - Implementare `OnboardingStep1`: text "Privacy First", ilustrație `local_privacy.svg`, animație `FadeIn`.
- <WORK_CODE>0155 - Implementare `OnboardingStep2`: text "Safe Backup", ilustrație `secure_backup.svg`, listă cu bullet points.
- <WORK_CODE>0156 - Implementare `OnboardingStep3`: text "Get Started", buton mare `PrimaryButton` care declanșează fluxul de permisiuni.
- <WORK_CODE>0157 - Tranziție Onboarding: folosire `CurvedAnimation` (Curves.easeInOut) pentru glisarea între pagini.
- <WORK_CODE>0158 - Buton "Skip": poziționare top-right (24dp padding), vizibil doar pe primele două pagini.
- <WORK_CODE>0159 - Creare `OnboardingProgressDots`: 3 cercuri mici, cel activ fiind extins (16dp lățime) cu culoarea albă.
- <WORK_CODE>0160 - Persistență Onboarding: salvare `has_seen_onboarding: true` în `SharedPreferences` la finalizare.
- <WORK_CODE>0161 - Creare `PrivacyPolicyScreen`: `Scaffold` cu `AppBar` și un `SingleChildScrollView` pentru textul legal.
- <WORK_CODE>0162 - Widget `PrivacyAcceptance`: `CheckboxListTile` cu link text ("Accept termenii și condițiile") folosind `RichText`.
- <WORK_CODE>0163 - Link-uri externe: implementare `url_launcher` pentru a deschide link-ul către site-ul oficial de privacy.
- <WORK_CODE>0164 - Logică Redirecționare: în `main.dart`, verificare flag `has_seen_onboarding` pentru a decide ruta inițială.
- <WORK_CODE>0165 - Widget Test: `OnboardingScreen` - verificare dacă swipe-ul schimbă corect textele.
- <WORK_CODE>0166 - Unit Test: `OnboardingController` - verificare dacă metoda `nextPage()` nu depășește indexul maxim.
- <WORK_CODE>0167 - Re-onboarding: adăugare buton în `SettingsScreen` care resetează flag-ul și trimite utilizatorul la onboarding.
- <WORK_CODE>0168 - Rafinare Design: adăugare efect de "Parallax" ușor pentru ilustrațiile din onboarding în timpul scroll-ului.
- <WORK_CODE>0169 - Feedback Vizual: schimbarea subtilă a culorii fundalului (gradient) în funcție de pagina curentă.
- <WORK_CODE>0170 - Analytics (Anonim): logare eveniment `onboarding_completed` fără a colecta ID-ul dispozitivului.
- <WORK_CODE>0171-0200 - Buffer: tratare ecrane cu aspect ratio mic (se asigură că butoanele nu ies din ecran).

### Permissions Management (0201 - 0250)
- <WORK_CODE>0201 - Enum `AppPermissionStatus`: definire stări (initial, granted, denied, permanentlyDenied).
- <WORK_CODE>0202 - Interfață `IPermissionService`: metode abstracte `requestContactsPermission()` și `checkStatus()`.
- <WORK_CODE>0203 - Implementare `ContactsPermissionService`: utilizare pachet `permission_handler`.
- <WORK_CODE>0204 - Android Logic: gestionare `READ_CONTACTS` și `WRITE_CONTACTS` în `AndroidManifest.xml`.
- <WORK_CODE>0205 - iOS Logic: adăugare `NSContactsUsageDescription` în `Info.plist` cu text explicativ clar.
- <WORK_CODE>0206 - Permanently Denied: implementare dialog care explică de ce e nevoie de permisiune și buton spre "Open App Settings".
- <WORK_CODE>0207 - Permisiune Scriere: cerere separată doar în momentul în care utilizatorul apasă pe "Merge".
- <WORK_CODE>0208 - Verificare Startup: serviciu care la fiecare boot verifică dacă permisiunile sunt încă valide.
- <WORK_CODE>0209 - `PermissionExplanationDialog`: UI custom cu iconiță de contacte și listă de beneficii (ex: "Găsim duplicate").
- <WORK_CODE>0210 - Widget `PermissionGuard`: wrapper care afișează un ecran de "Access Required" dacă permisiunea lipsește.
- <WORK_CODE>0211 - External Storage: adăugare permisiune pt Android < 10 pentru salvarea fișierelor vCard.
- <WORK_CODE>0212 - Error Handling: tratare cazuri în care sistemul refuză să mai afișeze prompt-ul de permisiune.
- <WORK_CODE>0213 - Settings Opener: funcție utilitară care apelează API-ul nativ pentru deschiderea paginii de setări a aplicației.
- <WORK_CODE>0214 - Unit Test: `PermissionService` folosind un `MockPermissionHandler` pentru a simula diverse răspunsuri ale OS-ului.
- <WORK_CODE>0215 - Dashboard Integration: afișare un "Warning Banner" în Dashboard dacă permisiunile au fost revocate manual din setări.
- <WORK_CODE>0216 - Privacy Log: salvare în logger-ul intern a momentului acordării permisiunii (fără date GPS sau user ID).
- <WORK_CODE>0217-0250 - Buffer: suport pentru "Limited Access" pe iOS 14+ (permisiune doar pe anumite contacte).

### Data Privacy & Security (0251 - 0300)
- <WORK_CODE>0251 - `SecurityService`: metodă de verificare a semnăturii pachetului (Android) pentru a preveni repachetarea.
- <WORK_CODE>0252 - Detectare Root/Jailbreak: folosire `flutter_jailbreak_detection` și afișare mesaj de avertizare la startup.
- <WORK_CODE>0253 - `DataEncryptionService`: implementare criptare `AES-256` folosind `flutter_rust_bridge` sau `encrypt` package.
- <WORK_CODE>0254 - `SecureStorage`: folosire `flutter_secure_storage` pentru a salva cheia de criptare a bazei de date.
- <WORK_CODE>0255 - Auto-backup Exclusion: configurare `allowBackup="false"` în `AndroidManifest` pentru datele sensibile.
- <WORK_CODE>0256 - Audit Cod: script pentru identificarea și eliminarea oricărui `print()` sau `debugPrint()` care conține variabile dinamice.
- <WORK_CODE>0257 - Obfuscation Build: configurare `shrinkResources true` și `minifyEnabled true` în `build.gradle` (Android).
- <WORK_CODE>0258 - Security Rules Backup: setare permisiuni fișier vCard exportat pentru a fi citit doar de aplicația de contacte a sistemului.
- <WORK_CODE>0259 - `PrivacyManager`: serviciu care permite utilizatorului să vadă ce metadate sunt salvate local (ex: timestamp scanare).
- <WORK_CODE>0260 - Local Wipe: funcție care șterge folderul `applicationDocumentsDirectory` și golește `SecureStorage`.
- <WORK_CODE>0261 - GDPR Compliance: adăugare ecran "Drepturile tale" care explică stocarea 100% locală.
- <WORK_CODE>0262 - Unit Test: `DataEncryptionService` - testare criptare/decriptare cu cheie greșită.
- <WORK_CODE>0263 - Screenshot Block: folosire `flutter_windowmanager` pentru a seta `FLAG_SECURE` pe Android în ecranele de preview merge.
- <WORK_CODE>0264 - Unencrypted Warning: dialog de confirmare înainte de a partaja (share) un backup vCard prin email/mesaje.
- <WORK_CODE>0265 - Access Audit: limitare strictă a permisiunilor de fișiere la nivel de OS folosind `File.setLastModified`.
- <WORK_CODE>0266-0300 - Audit Securitate: verificare manuală a dependențelor din `pubspec.lock` pentru vulnerabilități cunoscute.

---

## FAZA 2: Modele de Date, Servicii Native și Baza de Date (Commit-uri 0301 - 0450)

### Data Models & Entities (0301 - 0350)
- <WORK_CODE>0301 - `ContactEntity`: definire id (UUID), displayName, initials, și lists de phones/emails.
- <WORK_CODE>0302 - `PhoneEntity`: value (string normalizat), label (Home, Work, Mobile), și originalValue.
- <WORK_CODE>0303 - `EmailEntity`: value, label, și isValid flag (regex validation).
- <WORK_CODE>0304 - `AddressEntity`: street, city, state, postalCode, country (suport multi-linie).
- <WORK_CODE>0305 - `PhotoEntity`: uint8list bytes (pentru cache rapid) și localPath către folderul de cache al aplicației.
- <WORK_CODE>0306 - `GroupEntity`: id unic, listă de `ContactEntity` (membri), și `score` de similaritate mediu.
- <WORK_CODE>0307 - `ContactMapper`: implementare `fromNativeJson` (conversie din map-ul primit prin MethodChannel).
- <WORK_CODE>0308 - `ContactMapper`: implementare `toNativeJson` (formatul cerut de API-ul de scriere Android/iOS).
- <WORK_CODE>0309 - `isReadOnly`: adăugare flag calculat (ex: contacte din WhatsApp sau LinkedIn care nu pot fi șterse pe Android).
- <WORK_CODE>0310 - `accountType`: detectare sursă (Google: 'com.google', iCloud: 'com.apple.contacts').
- <WORK_CODE>0311 - `DuplicateReason`: enum cu valori (exactPhone, fuzzyName, sameEmail, sharedAddress).
- <WORK_CODE>0312 - `MatchResult`: model care conține `confidenceScore` (0-100) și lista de motive `reasons`.
- <WORK_CODE>0313 - `copyWith`: generare automată a metodelor `copyWith` pentru toate clasele folosind `freezed` sau manual.
- <WORK_CODE>0314 - Validări Entity: asigurat că un contact nu poate fi creat fără `id` sau fără cel puțin un `displayName`.
- <WORK_CODE>0315 - `ContactComparison`: utilitar care returnează un `Map<String, dynamic>` cu diferențele între două versiuni de contact.
- <WORK_CODE>0316 - Unit Test: `ContactMapper` - testare cu date malformate (ex: telefoane care sunt null).
- <WORK_CODE>0317 - Unit Test: `ContactEntity` - verificare egalitate (`operator ==`) între două obiecte cu aceleași date.
- <WORK_CODE>0318-0350 - Buffer: suport pentru câmpuri sociale (Twitter, Facebook ID) și note (notes).

### Native Services (Android & iOS) (0351 - 0400)
- <WORK_CODE>0351 - MethodChannel: definire channel name `ro.contacteduplicate.app/contacts` și metode: `fetch`, `update`, `delete`.
- <WORK_CODE>0352 - `INativeContactsService`: definire contract asincron care returnează `Future<List<Map>>`.
- <WORK_CODE>0353 - `NativeContactsService`: implementare wrapper Flutter care apelează `invokeMethod` și tratează `PlatformException`.
- <WORK_CODE>0354 - Android Kotlin: creare `ContactsRepository` care folosește `ContentResolver`.
- <WORK_CODE>0355 - Android Batch: citire contacte în loturi de 500 folosind `ContactsContract.Data.CONTENT_URI`.
- <WORK_CODE>0356 - Android Photo: implementare `openContactPhotoInputStream` pentru a obține thumbnail-ul eficient.
- <WORK_CODE>0357 - Android Read-Only: detectare coloană `IS_READ_ONLY` pentru a marca contactele din surse externe imuabile.
- <WORK_CODE>0358 - iOS Swift: utilizare `CNContactStore` cu `CNContactFetchRequest`.
- <WORK_CODE>0359 - iOS Fetch: selectare chei minime (givenName, familyName, phoneNumbers, emailAddresses) pentru viteză.
- <WORK_CODE>0360 - iOS Photo: obținere `imageData` sau `thumbnailImageData` dacă există.
- <WORK_CODE>0361 - iOS Mapping: conversie obiecte `CNContact` într-un `Dictionary` compatibil cu formatul JSON intern.
- <WORK_CODE>0362 - Pagination Logic: implementare `offset` și `limit` în MethodChannel pentru a nu bloca UI thread-ul nativ.
- <WORK_CODE>0363 - Native Timeout: implementare mecanism de cancelation în Kotlin/Swift dacă procesul durează peste 30 secunde.
- <WORK_CODE>0364 - Android MimeType: interogare specifică pentru `StructuredName.CONTENT_ITEM_TYPE` și `Phone.CONTENT_ITEM_TYPE`.
- <WORK_CODE>0365 - iOS Containers: identificare dacă contactul aparține de `CNContainerTypeLocal` sau `CNContainerTypeExchange`.
- <WORK_CODE>0366 - Group Fetch: adăugare parametru opțional pentru a citi contactele dintr-un anumit `GroupId` (Android).
- <WORK_CODE>0367 - Native Diff: (Opțional) implementare `ChangeCursor` pe Android pentru a citi doar ce s-a schimbat de la ultima scanare.
- <WORK_CODE>0368 - Unit Test: `NativeContactsService` - simulare răspunsuri native folosind `setMockMethodCallHandler`.
- <WORK_CODE>0369 - Benchmark Simulator: logare timp execuție pentru 1000 contacte simulate.
- <WORK_CODE>0370 - Benchmark Real Device: testare pe iPhone/Android real pentru a măsura latența bridge-ului Flutter.
- <WORK_CODE>0371-0400 - Buffer: tratare excepții de tip `SecurityException` pe versiuni vechi de Android.

### Local Database (0401 - 0450)
- <WORK_CODE>0401 - Drift Setup: adăugare dependențe `drift`, `sqlite3_flutter_libs`, și `drift_dev`.
- <WORK_CODE>0402 - Schema `ContactsCache`: definire coloane (id, raw_json, last_scanned_at, version).
- <WORK_CODE>0403 - Schema `DuplicateGroups`: definire coloane (id, member_ids, score, ignored_at).
- <WORK_CODE>0404 - Schema `BackupHistory`: definire coloane (id, file_path, contact_count, created_at).
- <WORK_CODE>0405 - Schema `AppSettings`: tabel de tip key-value pentru setări (limbă, temă, auto-scan).
- <WORK_CODE>0406 - `DatabaseService`: implementare clasă de acces (Database class) cu deschidere `LazyDatabase`.
- <WORK_CODE>0407 - `ContactDao`: metode `insertAll`, `deleteAll`, și `watchAllContacts` (Stream).
- <WORK_CODE>0408 - `GroupDao`: metode `markAsIgnored` și `findGroupsWithScoreAbove(int score)`.
- <WORK_CODE>0409 - `BackupDao`: metodă `getLatestBackup` și `deleteOldBackups(int limit)`.
- <WORK_CODE>0410 - Schema Migration: implementare `MigrationStrategy` cu funcție `onUpgrade` pentru versiuni viitoare.
- <WORK_CODE>0411 - Wipe Service: metodă asincronă care șterge toate tabelele și resetează secvențele primare.
- <WORK_CODE>0412 - SQL Indexes: adăugare `CREATE INDEX` pe coloana `displayName` (normalizat) în tabelul cache.
- <WORK_CODE>0413 - Transactions: folosire `transaction(() async { ... })` pentru salvarea grupului de duplicate.
- <WORK_CODE>0414 - Unit Test: `ContactDao` - testare inserare și recuperare prin Stream.
- <WORK_CODE>0415 - Integration Test: Verificare migrare de la versiunea 1 la 2 fără pierdere de date.
- <WORK_CODE>0416 - DB Stress Test: inserare 10.000 rânduri și măsurare timp de query (sub 100ms recomandat).
- <WORK_CODE>0417 - Auto-backup DB: (Opțional) copiere fișier `.sqlite` într-un folder securizat la fiecare 7 zile.
- <WORK_CODE>0418-0450 - Buffer: optimizare query-uri de tip `JOIN` pentru statistici complexe pe dashboard.

---

## FAZA 3: Algoritmi de Normalizare și Detecție Duplicate (Commit-uri 0451 - 0600)

### Normalization Service (0451 - 0500)
- <WORK_CODE>0451 - `NormalizationService`: interfață cu metode pentru `phone`, `email`, `name`.
- <WORK_CODE>0452 - Phone Normalization: regex `r'[^0-9+]'` pentru eliminarea parantezelor, spațiilor și cratimelor.
- <WORK_CODE>0453 - RO Prefix (+40): asigurarea că numerele care încep cu `07` sunt convertite intern în `+407`.
- <WORK_CODE>0454 - RO Prefix (0040): conversie automată a prefixului `00` în `+` pentru consistență.
- <WORK_CODE>0455 - Short Numbers: logică de a nu adăuga prefix internațional numerelor cu mai puțin de 5 cifre (ex: 112).
- <WORK_CODE>0456 - Email Normalization: `toLowerCase().trim()` și eliminare puncte opționale (pentru gmail).
- <WORK_CODE>0457 - Name Normalization: folosire regex `r'\s+'` pentru a înlocui multiple spații cu unul singur.
- <WORK_CODE>0458 - Case Insensitive Name: transformare în `toLowerCase()` înainte de orice comparație.
- <WORK_CODE>0459 - Diacritics Removal: folosire `String.replaceAllMapped` cu un dicționar pentru (ă, î, ș, ț, â).
- <WORK_CODE>0460 - Swap Detection: logică pentru a detecta dacă "Popescu Ion" este același cu "Ion Popescu".
- <WORK_CODE>0461 - Special Chars: eliminare simboluri precum `*`, `&`, `_` din câmpurile de nume.
- <WORK_CODE>0462 - Soundex RO: implementare algoritm fonetic simplificat pentru a potrivi nume pronunțate similar.
- <WORK_CODE>0463 - Unit Test Phone: matrice de test cu 50 de variante de numere scrise greșit.
- <WORK_CODE>0464 - Unit Test Email: verificare cazuri cu caractere speciale și domenii multiple.
- <WORK_CODE>0465 - Unit Test Name: testare cu diacritice și nume compuse (ex: "Popa-Anghel").
- <WORK_CODE>0466 - Performance Loop: normalizare a 10.000 de intrări și asigurarea unui timp de execuție sub 200ms.
- <WORK_CODE>0467 - Prefix Mapping: tabel de mapare pentru prefixe internaționale comune (HU, BG, RS).
- <WORK_CODE>0468 - Smart Trim: eliminare titluri (Dr., Ing., Prof.) din începutul numelui pentru un match mai bun.
- <WORK_CODE>0469-0500 - Buffer: tratare nume în formatul "LastName, FirstName".

### Duplicate Detection Logic (0501 - 0550)
- <WORK_CODE>0501 - `DuplicateDetectorService`: serviciu principal care orchestrarează toți algoritmii de match.
- <WORK_CODE>0502 - Exact Match Phone: scor 100 dacă telefoanele normalizate sunt identice.
- <WORK_CODE>0503 - Exact Match Email: scor 100 dacă email-urile normalizate sunt identice.
- <WORK_CODE>0504 - Exact Match Name: scor 90 dacă numele normalizate sunt identice (fără alte metadate).
- <WORK_CODE>0505 - Levenshtein Distance: calcularea distanței de editare între nume; scor variabil (ex: 1 char diff la 10 chars = scor 80).
- <WORK_CODE>0506 - Multi-factor Match: scor +10 dacă au aceeași companie, +5 dacă au aceeași adresă.
- <WORK_CODE>0507 - Partial Phone: scor 70 dacă ultimele 9 cifre ale telefonului coincid (ignorând prefixul).
- <WORK_CODE>0508 - Weight Configuration: posibilitatea de a ajusta ponderile din setările aplicației (avansat).
- <WORK_CODE>0509 - Confidence Levels: mapare scoruri (95+ -> `Safe`, 80-94 -> `Probable`, 60-79 -> `Manual`).
- <WORK_CODE>0510 - Transitive Logic: dacă A e duplicat cu B și B cu C, adăugarea tuturor în același grup.
- <WORK_CODE>0511 - Memory Indexing: folosire `HashMap` pentru a găsi instant contacte cu același telefon.
- <WORK_CODE>0512 - False Positive Filter: listă de cuvinte de ignorat (ex: "Pizza", "Taxi", "Mama") care nu ar trebui unite automat.
- <WORK_CODE>0513 - Whitelist Service: persistență pentru contactele pe care utilizatorul a ales explicit să le "Ignore" anterior.
- <WORK_CODE>0514 - Match Reason Generator: returnare string localizat (ex: "Telefoane identice", "Nume foarte similare").
- <WORK_CODE>0515 - Algorithm Matrix Test: verificare cu un set de date pre-definit de 100 de perechi de contacte.
- <WORK_CODE>0516 - Confidence Test: asigurat că scorul nu depășește niciodată 100 și nu scade sub 0.
- <WORK_CODE>0517 - Complexity O(n log n): optimizarea algoritmului pentru a evita O(n^2) pe agende mari.
- <WORK_CODE>0518 - Large Set Benchmark: testare cu 5000 de contacte simulate.
- <WORK_CODE>0519 - Chunk Processing: împărțirea listei în bucăți de 100 pentru a nu bloca memoria isolate-ului.
- <WORK_CODE>0520 - Photo Hash Match: (Opțional) calculare `perceptual hash` pe poze pentru a găsi duplicate vizuale.
- <WORK_CODE>0521-0550 - Buffer: eliminarea duplicatelor interne din interiorul aceluiași contact (ex: același telefon salvat de 2 ori).

### Background Processing (0551 - 0600)
- <WORK_CODE>0551 - Configurare `Isolate`: folosire `compute()` sau `Isolate.spawn` pentru a rula `DuplicateDetectorService` fără a bloca UI.
- <WORK_CODE>0552 - `ScanController`: gestionare stări (idle, scanning, paused, completed) și variabilă `progress` (0.0 - 1.0).
- <WORK_CODE>0553 - Port Communication: utilizare `ReceivePort` și `SendPort` pentru a trimite rezultate parțiale (grupuri găsite) către UI.
- <WORK_CODE>0554 - Pause/Resume Logic: implementare flag de control în interiorul buclei de scanare din Isolate.
- <WORK_CODE>0555 - Android WorkManager: programare scanare periodică la 24h (doar dacă dispozitivul e la încărcat și pe WiFi).
- <WORK_CODE>0556 - iOS Background Fetch: înregistrare `BGTaskScheduler` pentru a rula o scanare rapidă în background.
- <WORK_CODE>0557 - `LocalNotificationService`: afișare notificare (ID unic 1001) cu textul "Am găsit [x] duplicate noi!".
- <WORK_CODE>0558 - Battery Check: folosire `battery_plus` pentru a opri automat scanarea dacă bateria scade sub 15%.
- <WORK_CODE>0559 - Unit Test: `ScanController` - verificare dacă progresul ajunge la 1.0 la finalul unei liste de mock contacte.
- <WORK_CODE>0560 - Dashboard Integration: widget circular mic în Dashboard care pulsează când scanarea este activă.
- <WORK_CODE>0561-0600 - Buffer: gestionarea scenariului în care utilizatorul închide aplicația în timpul scanării (persistență stare parțială).

---

## FAZA 4: Interfață Utilizator - Dashboard și Liste (Commit-uri 0601 - 0800)

### Dashboard Screen (0601 - 0650)
- <WORK_CODE>0601 - `DashboardController`: folosire `Riverpod` (StateNotifierProvider) pentru a aggrega date din `ContactDao` și `GroupDao`.
- <WORK_CODE>0602 - UI Header: `SliverAppBar` cu înălțime extinsă (120dp), titlu mare și avatar utilizator în colț.
- <WORK_CODE>0603 - Stats Widget 1: card cu număr total contacte citite din cache-ul local.
- <WORK_CODE>0604 - Stats Widget 2: card cu număr grupuri de duplicate (folosire `AppColors.error` pentru textul cifrei).
- <WORK_CODE>0605 - Scan Button: buton central mare, tip `PrimaryButton` cu iconiță `Icons.search` și text "Începe Scanarea".
- <WORK_CODE>0606 - Recent Groups: `ListView.horizontal` (înălțime 150dp) care arată ultimele 5 grupuri găsite ca `AnimatedCard`.
- <WORK_CODE>0607 - Savings Card: widget care estimează spațiul eliberat (ex: 2.4 MB) și timpul economisit.
- <WORK_CODE>0608 - Backup Status: card cu gradient (verde dacă există backup recent < 7 zile, portocaliu altfel).
- <WORK_CODE>0609 - Shimmer Dashboard: implementare `AppSkeletonLoader` care imită structura cardurilor de statistici.
- <WORK_CODE>0610 - Pull to Refresh: folosire `RefreshIndicator` care declanșează o citire proaspătă din Native.
- <WORK_CODE>0611 - Widget Test: `DashboardScreen` - asigurat că cifrele se actualizează când datele din provider se schimbă.
- <WORK_CODE>0612 - Dashboard Gestures: implementare `InkWell` pe fiecare card statistic pentru a naviga la ecranele corespunzătoare.
- <WORK_CODE>0613 - Spotlight Tutorial: folosire `showcaseview` package pentru a evidenția butonul de scanare la prima rulare.
- <WORK_CODE>0614-0650 - Buffer: adaptare layout pentru tablete (folosire `GridView` în loc de `Column`).

### Duplicate List & Filters (0651 - 0700)
- <WORK_CODE>0651 - `DuplicateListController`: filtrare și sortare în memorie a grupurilor primite din DB.
- <WORK_CODE>0652 - Duplicate List UI: `ListView.separated` cu `itemCount` din provider; separator `AppDivider`.
- <WORK_CODE>0653 - Filter Tabs: `TabBar` personalizat cu 3 opțiuni (Sigur - scor >95, Probabil - scor 80-94, Manual - sub 80).
- <WORK_CODE>0654 - Real-time Search: `AppTextField` legat de un `Debouncer` (300ms) pentru filtrare după nume în listă.
- <WORK_CODE>0655 - Score Slider: (Opțional) filtru tip slider pentru a seta manual scorul minim de afișare.
- <WORK_CODE>0656 - Type Chips: `FilterChip` pentru filtrare rapidă după "Doar Telefon" sau "Doar Email".
- <WORK_CODE>0657 - Bulk Mode: activare prin long-press; afișare `Checkbox` pe fiecare card și bară de acțiuni jos (Merge/Ignore).
- <WORK_CODE>0658 - Group Card: layout cu 2-3 mini-avatare suprapuse și text "3 contacte identificate prin telefon".
- <WORK_CODE>0659 - Quick Actions: butoane iconiță mici în colțul cardului pentru "Ignore" (ștergere din listă) și "Merge" (auto-merge).
- <WORK_CODE>0660 - Item Animation: folosire `AnimatedList` pentru eliminarea grupurilor cu un efect de glisare la stânga.
- <WORK_CODE>0661 - Empty Search: afișare `SearchEmptyState` cu buton de "Clear Search".
- <WORK_CODE>0662 - Widget Test: `DuplicateListScreen` - verificare dacă tab-ul "Sigur" arată doar elementele cu scor mare.
- <WORK_CODE>0663 - Performance Test: scroll infinit cu 1000 de grupuri și asigurat 60 FPS.
- <WORK_CODE>0664-0700 - Buffer: implementare "Sticky Headers" pentru data scanării grupurilor.

### Merge Detail Screen (0701 - 0750)
- <WORK_CODE>0701 - `MergeDetailController`: gestionare stării de "Preview" a contactului final.
- <WORK_CODE>0702 - Side-by-Side UI: afișare contacte sub formă de coloane (sau `PageView` pe ecrane mici) pentru comparare.
- <WORK_CODE>0703 - Master Selection: evidențierea cardului selectat ca sursă principală folosind o bordură groasă `AppColors.blue500`.
- <WORK_CODE>0704 - Field Selection: fiecare rând (telefon/email) are un `Radio` button pentru a alege care valoare merge în final.
- <WORK_CODE>0705 - Conflict Highlighting: colorare cu `AppColors.warning` a rândurilor unde valorile diferă (ex: "Ion" vs "Ioan").
- <WORK_CODE>0706 - Final Name Edit: `AppTextField` în partea de sus care permite editarea numelui final rezultat.
- <WORK_CODE>0707 - Live Preview: secțiune jos (floating) care arată cum va arăta `ContactAvatar` și numele după merge.
- <WORK_CODE>0708 - Merge Button: buton tip `PrimaryButton` cu textul "Confirmă îmbinarea celor [x] contacte".
- <WORK_CODE>0709 - Validation Logic: dezactivare buton merge dacă există câmpuri obligatorii neselectate (conflict nerezolvat).
- <WORK_CODE>0710 - Widget Test: `MergeDetailScreen` - verificare dacă selectarea unui radio button actualizează preview-ul.
- <WORK_CODE>0711-0750 - Buffer: suport pentru îmbinarea a mai mult de 2 contacte (scroll orizontal).

### Settings & Profile (0751 - 0800)
- <WORK_CODE>0751 - `SettingsController`: persistarea setărilor folosind `AppSettingsDao` și `ThemeProvider`.
- <WORK_CODE>0752 - Theme Toggle: widget `SettingsTile` cu `AppSwitch` pentru Dark Mode.
- <WORK_CODE>0753 - Language Picker: widget `SettingsTile` care deschide `LanguageSelector` dialog.
- <WORK_CODE>0754 - Sensitivity Settings: `Slider` (60-100) care definește pragul de scor pentru tab-ul "Sigur".
- <WORK_CODE>0755 - Whitelist Management: ecran secundar care listează contactele ignorate cu opțiune de "Remove".
- <WORK_CODE>0756 - Auto-backup Toggle: setare pentru a efectua un backup automat înainte de orice operațiune de merge.
- <WORK_CODE>0757 - About Section: `ListTile` care afișează versiunea din `pubspec.yaml` și link către licențe Open Source.
- <WORK_CODE>0758 - Clear History: buton de "Danger" care șterge istoricul de merge dar păstrează backup-urile.
- <WORK_CODE>0759 - Feedback Flow: integrare `share_plus` pentru a trimite log-uri (fără PII) către suport.
- <WORK_CODE>0760 - Widget Test: `SettingsScreen` - asigurat că schimbarea temei apelează `ThemeProvider`.
- <WORK_CODE>0761-0800 - Buffer: adăugare secțiune de "Întrebări frecvente" (FAQ) în format text localizat.

---

## FAZA 5: Merge Engine, Backup și Istoric (Commit-uri 0801 - 0920)

### Backup Service (0801 - 0840)
- <WORK_CODE>0801 - `BackupService`: interfață cu metode `createBackup()`, `restoreBackup(String path)`, `listBackups()`.
- <WORK_CODE>0802 - vCard Export: implementare generator `vCard 3.0` (standard compatibil iOS/Android).
- <WORK_CODE>0803 - JSON Export: salvare stare completă a contactului (inclusiv metadate interne) pentru restaurare 1:1.
- <WORK_CODE>0804 - Naming Convention: funcție care returnează `backup_20240622_2305.vcf`.
- <WORK_CODE>0805 - Storage Management: utilizarea `path_provider` pentru a salva fișierele în `getApplicationDocumentsDirectory()/backups`.
- <WORK_CODE>0806 - `BackupMetadata`: model care stochează `checksum` (SHA-256) pentru a verifica integritatea fișierului.
- <WORK_CODE>0807 - Auto-cleanup: logică de a păstra doar ultimele 10 backup-uri (ștergere automată cele mai vechi).
- <WORK_CODE>0808 - Space Check: verificare `StorageDetails` înainte de pornire (necesar minim 50MB liberi).
- <WORK_CODE>0809 - Backup UI List: ecran cu `ListView` ce afișează data (format RO) și dimensiunea (KB/MB).
- <WORK_CODE>0810 - Share Integration: folosire `share_plus` pentru a trimite fișierul VCF către alte aplicații.
- <WORK_CODE>0811 - Restore Logic: citire fișier VCF/JSON și apelare servicii native de scriere în agendă.
- <WORK_CODE>0812 - Integrity Check: validare structură fișier (header/footer) înainte de a începe procesul de restaurare.
- <WORK_CODE>0813 - Unit Test: `BackupService` - verificare dacă fișierul generat are formatul vCard valid.
- <WORK_CODE>0814 - Benchmark: măsurare timp salvare pentru 5000 contacte (țintă sub 5 secunde).
- <WORK_CODE>0815-0840 - Buffer: suport pentru export imagini contact (Base64 în vCard) - opțional din setări.

### Merge Engine (0841 - 0880)
- <WORK_CODE>0841 - `MergeEngineService`: coordonatorul care execută backup -> scriere contact nou -> ștergere contacte vechi.
- <WORK_CODE>0842 - Safe Guard: blocare funcție `executeMerge` dacă nu s-a generat un backup în ultimele 5 minute.
- <WORK_CODE>0843 - Android Batch Write: folosire `ArrayList<ContentProviderOperation>` pentru a asigura atomicitatea scrierii.
- <WORK_CODE>0844 - Android Delete: adăugare operațiune de tip `newDelete` în batch-ul de ContentProvider.
- <WORK_CODE>0845 - iOS Batch: folosire `CNSaveRequest` pentru a grupa operațiunile de adăugare și ștergere.
- <WORK_CODE>0846 - iOS Delete: apelare `saveRequest.deleteContact()` pe obiectele `CNMutableContact`.
- <WORK_CODE>0847 - Transactionality: implementare rollback logic (dacă scrierea eșuează, nu se șterg contactele vechi).
- <WORK_CODE>0848 - Exception Mapping: conversie erori native (ex: `AccessDeniedException`) în mesaje localizate pentru utilizator.
- <WORK_CODE>0849 - Conflict Resolver: regulă automată de a păstra valoarea cea mai lungă (ex: "Ion Popescu" vs "Ion").
- <WORK_CODE>0850 - Merge Report: generare model `MergeReport` care conține lista ID-urilor șterse și ID-ul nou creat.
- <WORK_CODE>0851 - Merge Progress UI: dialog cu indicator de progres liniar și text "Se scrie contactul [x]...".
- <WORK_CODE>0852 - Photo Merger: logică de a alege poza cu rezoluția cea mai mare dintre duplicatele selectate.
- <WORK_CODE>0853 - Post-Merge Verify: re-scanare automată a contactului nou creat pentru a asigura că nu mai are duplicate.
- <WORK_CODE>0854 - Unit Test: `MergeEngine` folosind Mockito pentru a simula succes/eșec în serviciul nativ.
- <WORK_CODE>0855 - Integration Test: execuție merge pe Emulator cu 50 contacte și verificare finală a numărului total.
- <WORK_CODE>0856-0880 - Buffer pentru stabilitate engine scriere.

### History & Activity Log (0881 - 0920)
- <WORK_CODE>0881 - `HistoryService`: interfață pentru salvarea și recuperarea jurnalului de activități din DB.
- <WORK_CODE>0882 - `HistoryEntry`: model cu `type` (merge/backup/scan), `status` (success/failed), și `summary`.
- <WORK_CODE>0883 - Auto-logging: integrare apeluri `historyService.add()` în toate serviciile principale.
- <WORK_CODE>0884 - History UI: `ListView` cronologic cu iconițe specifice fiecărei acțiuni și dată relativă (ex: "Acum 5 min").
- <WORK_CODE>0885 - History Detail: ecran ce arată exact ce contacte au fost implicate (nume înainte și după).
- <WORK_CODE>0886 - Undo Action: buton "Undo" care inversează ultimul merge folosind datele din backup-ul asociat.
- <WORK_CODE>0887 - Incomplete Status: marcare intrări în jurnal dacă aplicația s-a închis brusc (folosire `lastSeenAt` timestamp).
- <WORK_CODE>0888 - Widget Test: `HistoryEntry` - asigurat că lista se sortează cu cea mai recentă acțiune sus.
- <WORK_CODE>0889-0920 - Buffer: funcție de export istoric în format CSV (pentru power users).

---

## FAZA 6: Testare Finală, Optimizare și Store (Commit-uri 0921 - 1000)

### Testing & Bug Fixing (0921 - 0960)
- <WORK_CODE>0921 - Regression Android: testare flow complet pe Device-uri reale (Samsung S23, Pixel 7, Huawei).
- <WORK_CODE>0922 - Regression iOS: testare pe iPhone 13, 15 Pro și iPad (multi-tasking check).
- <WORK_CODE>0923 - Stress Test 10k: generare script de populare agendă cu 10.000 contacte și scanare.
- <WORK_CODE>0924 - Interrupt Test: forțarea închiderii aplicației (Kill process) în timpul scrierii și verificare integritate DB.
- <WORK_CODE>0925 - Offline Test: rulare scanare în mod avion pentru a confirma că nicio dată nu părăsește dispozitivul.
- <WORK_CODE>0926 - UI Polish: verificare margini, padding-uri și contrast conform WCAG 2.1 (AA).
- <WORK_CODE>0927 - Bundle Optimization: rulare `flutter build appbundle --obfuscate` și analiză dimensiune (țintă sub 25MB).
- <WORK_CODE>0928 - Memory Leak Audit: folosire `DevTools` Memory tab pentru a identifica stream-uri neînchise.
- <WORK_CODE>0929 - Multi-Source Test: verificare merge între un contact Google și unul de pe cartela SIM.
- <WORK_CODE>0930-0960 - Bug-Fixing: rezolvarea tichetelor deschise în timpul fazei de testare beta.

### Final Prep & Store Compliance (0961 - 1000)
- <WORK_CODE>0961 - Play Store Assets: generare imagini 1024x500 (Feature Graphic) și 512x512 (App Icon).
- <WORK_CODE>0962 - App Store Assets: generare screenshot-uri pentru 6.5" și 5.5" iPhone display.
- <WORK_CODE>0963 - Store Metadata: redactare titlu (max 50 chars) și descriere (cu keywords contacte, duplicate, backup).
- <WORK_CODE>0964 - Apple Privacy: completare chestionar (Data not collected, Data not linked).
- <WORK_CODE>0965 - Google Data Safety: declarare permisiuni `READ_CONTACTS` și motivul utilizării acestora.
- <WORK_CODE>0966 - Log Audit: scanare finală a întregului cod pentru a elimina orice `AppLogger.info` ce ar putea conține nume.
- <WORK_CODE>0967 - Compliance Check: asigurat că link-ul de "Delete Account/Data" din setări funcționează corect.
- <WORK_CODE>0968 - Release Notes: creare fișier `CHANGELOG.md` cu versiunea 1.0.0 "Initial Release".
- <WORK_CODE>0969 - Versioning: actualizare `pubspec.yaml` și `build.gradle` la `version: 1.0.0+1`.
- <WORK_CODE>0970 - Production Build: generare `.aab` (Android) și `.ipa` (iOS) semnate oficial.
- <WORK_CODE>0971-1000 - Submission: încărcare în Console și monitorizare status review (re-build în caz de reject).

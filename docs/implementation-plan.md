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
- <WORK_CODE>0061 - Implementare `AppEmptyState`: creare layout de bază cu iconiță centrală, titlu și descriere.
- <WORK_CODE>0062 - Implementare `AppEmptyState`: adăugare suport pentru ilustrații SVG din `AppAssets`.
- <WORK_CODE>0063 - Implementare `AppEmptyState`: integrare buton de acțiune opțional (ex: "Scanează acum").
- <WORK_CODE>0064 - Creare `AppErrorState`: implementare widget pentru afișarea erorilor cu iconiță de avertizare (`status.error`).
- <WORK_CODE>0065 - Creare `AppErrorState`: adăugare buton de "Retry" cu callback configurabil.
- <WORK_CODE>0066 - Implementare `AppBottomBar`: definire structură `BottomNavigationBar` custom cu 4 itemi (Acasă, Duplicate, Backup, Setări).
- <WORK_CODE>0067 - Implementare `AppBottomBar`: aplicare stiluri vizuale (blur fundal, selecție cu gradient) conform mockup-ului.
- <WORK_CODE>0068 - Rafinare `PrimaryButton`: adăugare stare de loading (înlocuire text cu `AppLoadingIndicator` mic).
- <WORK_CODE>0069 - Rafinare `PrimaryButton`: implementare stare de `disabled` (opacitate redusă, ignorare tap).
- <WORK_CODE>0070 - Rafinare `PrimaryButton`: adăugare suport pentru iconiță în stânga sau dreapta textului.
- <WORK_CODE>0071 - Creare `IconButton` personalizat: suport pentru diferite forme (circular, pătrat rotunjit) și dimensiuni.
- <WORK_CODE>0072 - Creare `IconButton` personalizat: implementare efect de "splash" controlat conform temei.
- <WORK_CODE>0073 - Implementare widget `SectionHeader`: layout pentru titlu de secțiune cu opțiune de "Vezi tot".
- <WORK_CODE>0074 - Implementare widget `SectionHeader`: stilizare text conform `app_text_styles.dart` (Label/H2).
- <WORK_CODE>0075 - Creare widget `SettingsTile`: implementare rând pentru setări cu iconiță, titlu, subtitlu și widget de tip "trailing".
- <WORK_CODE>0076 - Creare widget `SettingsTile`: adăugare suport pentru diferite tipuri de trailing (Switch, Arrow, Text).
- <WORK_CODE>0077 - Adăugare `AppSwitch`: personalizare `Switch` nativ pentru a folosi culorile brandului în ambele teme.
- <WORK_CODE>0078 - Implementare widget `AppTextField`: creare input text cu border rotunjit, suport pentru iconiță de căutare și buton de ștergere.
- <WORK_CODE>0079 - Implementare widget `AppTextField`: adăugare validări vizuale (error border, hint style).
- <WORK_CODE>0080 - Creare `BadgeCount`: widget circular mic pentru afișarea numărului de duplicate găsite pe iconițele din menu.
- <WORK_CODE>0081 - Implementare `AnimatedCard`: adăugare animație de tip "scale" sau "slide" la apariția în listă a cardului de contact.
- <WORK_CODE>0082 - Creare widget `ProgressRing`: implementare cerc de progres pentru Dashboard folosind `CustomPainter`.
- <WORK_CODE>0083 - Creare widget `ProgressRing`: adăugare animație de umplere progresivă și text central (procent).
- <WORK_CODE>0084 - Adăugare suport pentru gradienți în `AppCard`: implementare proprietate `gradientBackground`.
- <WORK_CODE>0085 - Implementare sistem de umbre (`AppBoxShadows`): definire set de umbre (soft, medium, hard) ca extensie la `ThemeData`.
- <WORK_CODE>0086 - Creare widget `InfoBox`: layout pentru mesaje informative cu fundal `light.surfaceMuted` și iconiță de info.
- <WORK_CODE>0087 - Rafinare Splash Screen: implementare animație complexă de apariție logo și titlu (secvențial).
- <WORK_CODE>0088 - Implementare `AppDialog`: creare widget de bază pentru dialoguri cu fundal blurat și margini rotunjite (`radius.lg`).
- <WORK_CODE>0089 - Creare `ConfirmationDialog`: implementare dialog specific cu două butoane și mesaj de confirmare.
- <WORK_CODE>0090 - Implementare `AppBottomSheet`: creare widget de bază pentru ecrane glisante de jos în sus.
- <WORK_CODE>0091 - Creare `SelectionListTile`: implementare rând cu checkbox/radio pentru selectarea câmpurilor în Merge Detail.
- <WORK_CODE>0092 - Adăugare suport pentru "Haptic Feedback": integrare `HapticFeedback.lightImpact()` la interacțiunea cu butoanele.
- <WORK_CODE>0093 - Creare widget `MergeFieldRow`: layout pentru compararea a două valori (Stânga vs Dreapta) cu evidențierea diferențelor.
- <WORK_CODE>0094 - Implementare `SearchEmptyState`: variantă de empty state specifică pentru rezultate de căutare vide.
- <WORK_CODE>0095 - Creare widget `SummaryCard`: card compact pentru statistici (ex: "340 MB eliberați").
- <WORK_CODE>0096 - Implementare `AppSkeletonLoader`: creare efect de "shimmer" pentru dashboard (placeholder cerc și linii).
- <WORK_CODE>0097 - Creare `SkeletonLoader` pentru lista de contacte: rânduri placeholder cu avatar și text simulat.
- <WORK_CODE>0098 - Adăugare `AppBlur`: widget utilitar pentru aplicarea efectului de `BackdropFilter` (Glassmorphism).
- <WORK_CODE>0099 - Implementare widget `LanguageSelector`: dialog cu steaguri și nume limbi pentru schimbarea localizării.
- <WORK_CODE>0100 - Creare `ThemeSelector`: widget tip toggle sau listă pentru alegerea Light/Dark/System.
- <WORK_CODE>0101 - Audit UI: verificare manuală a tuturor widget-urilor create față de `theme-guide.md` și corectare discrepanțe.

### Localization & Asset Management (0102 - 0150)
- <WORK_CODE>0102 - Configurare `Intl` pentru suport plural (ex: "1 contact", "5 contacte").
- <WORK_CODE>0103 - Adăugare traduceri RO pentru ecranul Onboarding.
- <WORK_CODE>0104 - Adăugare traduceri EN pentru ecranul Onboarding.
- <WORK_CODE>0105 - Adăugare traduceri RO pentru Dashboard.
- <WORK_CODE>0106 - Adăugare traduceri EN pentru Dashboard.
- <WORK_CODE>0107 - Adăugare traduceri RO pentru Listă Duplicate.
- <WORK_CODE>0108 - Adăugare traduceri EN pentru Listă Duplicate.
- <WORK_CODE>0109 - Adăugare traduceri RO pentru Detalii Merge.
- <WORK_CODE>0110 - Adăugare traduceri EN pentru Detalii Merge.
- <WORK_CODE>0111 - Adăugare traduceri RO pentru Backup & Restaurare.
- <WORK_CODE>0112 - Adăugare traduceri EN pentru Backup & Restaurare.
- <WORK_CODE>0113 - Adăugare traduceri RO pentru Setări.
- <WORK_CODE>0114 - Adăugare traduceri EN pentru Setări.
- <WORK_CODE>0115 - Adăugare mesaje de eroare localizate (RO/EN).
- <WORK_CODE>0116 - Implementare serviciu `AppLanguageService` pentru schimbare dinamică.
- <WORK_CODE>0117 - Adăugare iconițe vectoriale (SVG) pentru acțiuni (merge, scan, delete).
- <WORK_CODE>0118 - Adăugare iconițe vectoriale (SVG) pentru categorii contacte (work, home).
- <WORK_CODE>0119 - Optimizare asset-uri SVG pentru dimensiune minimă.
- <WORK_CODE>0120 - Implementare script de verificare prezență traduceri în ambele limbi.
- <WORK_CODE>0121 - Adăugare sunete discrete pentru feedback acțiuni (opțional/configurabil).
- <WORK_CODE>0122 - Configurare fonturi de sistem (Inter/Roboto/San Francisco).
- <WORK_CODE>0123 - Implementare `AppAssets` constant class pentru acces tipizat.
- <WORK_CODE>0124 - Adăugare imagini placeholder pentru contacte fără foto.
- <WORK_CODE>0125 - Creare asset-uri pentru empty states (ilustrații SVG).
- <WORK_CODE>0126 - Adăugare ilustrații pentru onboarding (vizualizare, siguranță).
- <WORK_CODE>0127 - Configurare `l10n.yaml` pentru generare cod automată.
- <WORK_CODE>0128 - Implementare unit test pentru `AppLanguageService`.
- <WORK_CODE>0129 - Verificare contrast culori pentru localizare (texte lungi).
- <WORK_CODE>0130 - Adăugare suport pentru diacritice în căutare (normalizare string).
- <WORK_CODE>0131 - Audit localizare: eliminare hardcoded strings rămase.
- <WORK_CODE>0132-0150 - Rafinament infrastructură și pregătire pentru Faza 1.

---

## FAZA 1: Onboarding, Permisiuni și Securitate (Commit-uri 0151 - 0300)

### Onboarding Flow (0151 - 0200)
- <WORK_CODE>0151 - Creare `OnboardingModel` entity.
- <WORK_CODE>0152 - Implementare `OnboardingController` (Riverpod/Bloc).
- <WORK_CODE>0153 - Creare `OnboardingScreen` (Base PageView).
- <WORK_CODE>0154 - Implementare `OnboardingStep1`: Explicație Scanare Locală.
- <WORK_CODE>0155 - Implementare `OnboardingStep2`: Explicație Backup & Siguranță.
- <WORK_CODE>0156 - Implementare `OnboardingStep3`: Cerere Permisiuni (Pre-prompt).
- <WORK_CODE>0157 - Adăugare animație de tranziție între pașii de onboarding.
- <WORK_CODE>0158 - Implementare buton "Skip" (unde este permis/logic).
- <WORK_CODE>0159 - Creare `OnboardingProgressDots` widget.
- <WORK_CODE>0160 - Implementare persistență status onboarding (SharedPrefs).
- <WORK_CODE>0161 - Creare `PrivacyPolicyScreen`.
- <WORK_CODE>0162 - Implementare widget `PrivacyAcceptance` (checkbox).
- <WORK_CODE>0163 - Adăugare link-uri externe către politica de confidențialitate.
- <WORK_CODE>0164 - Implementare logică de redirecționare automată (Onboarding vs Dashboard).
- <WORK_CODE>0165 - Widget test pentru `OnboardingScreen`.
- <WORK_CODE>0166 - Unit test pentru `OnboardingController`.
- <WORK_CODE>0167 - Adăugare suport pentru reluare onboarding (din Setări).
- <WORK_CODE>0168 - Rafinare design pagini onboarding conform theme-guide.
- <WORK_CODE>0169 - Adăugare feedback vizual la swipe în onboarding.
- <WORK_CODE>0170 - Integrare Analytics (anonim, doar pași onboarding) - dacă e permis.
- <WORK_CODE>0171-0200 - Buffer pentru rafinament flow utilizator.

### Permissions Management (0201 - 0250)
- <WORK_CODE>0201 - Definire `PermissionStatus` enum personalizat.
- <WORK_CODE>0202 - Creare interfață `IPermissionService`.
- <WORK_CODE>0203 - Implementare `ContactsPermissionService` (base).
- <WORK_CODE>0204 - Implementare logică Android: cerere permisiune citire.
- <WORK_CODE>0205 - Implementare logică iOS: cerere permisiune contacte.
- <WORK_CODE>0206 - Tratare caz "Permanently Denied": dialog către setări sistem.
- <WORK_CODE>0207 - Implementare logică Android: cerere permisiune scriere (când e nevoie).
- <WORK_CODE>0208 - Implementare verificare status permisiuni la pornirea aplicației.
- <WORK_CODE>0209 - Creare `PermissionExplanationDialog` (pre-prompt UI).
- <WORK_CODE>0210 - Implementare `PermissionGuard` widget (blocare acces UI).
- <WORK_CODE>0211 - Adăugare suport pentru `READ_EXTERNAL_STORAGE` (dacă e nevoie pt backup vechi).
- <WORK_CODE>0212 - Tratare erori specifice de sistem la cererea permisiunii.
- <WORK_CODE>0213 - Implementare serviciu de deschidere setări aplicație (App Settings).
- <WORK_CODE>0214 - Unit test pentru `PermissionService` (mock status).
- <WORK_CODE>0215 - Integrare status permisiuni în Dashboard Controller.
- <WORK_CODE>0216 - Adăugare logging (fără PII) pentru schimbările de permisiuni.
- <WORK_CODE>0217-0250 - Buffer pentru cazuri particulare (ex: tablete, moduri restricționate).

### Data Privacy & Security (0251 - 0300)
- <WORK_CODE>0251 - Creare `SecurityService` (verificare integritate aplicație).
- <WORK_CODE>0252 - Implementare logică de detectare Root/Jailbreak (opțional - avertisment).
- <WORK_CODE>0253 - Implementare `DataEncryptionService` pentru cache local.
- <WORK_CODE>0254 - Configurare `SecureStorage` pentru token-uri/flag-uri critice.
- <WORK_CODE>0255 - Implementare serviciu de curățare date la dezinstalare (Android auto-backup exclusion).
- <WORK_CODE>0256 - Audit cod: verificare utilizare `print` (înlocuire cu logger).
- <WORK_CODE>0257 - Implementare `Obfuscation` în build-ul de producție.
- <WORK_CODE>0258 - Configurare reguli de securitate pentru fișierele de backup local.
- <WORK_CODE>0259 - Creare `PrivacyManager` pentru controlul datelor stocate.
- <WORK_CODE>0260 - Implementare buton "Șterge toate datele aplicației" (Local Wipe).
- <WORK_CODE>0261 - Verificare conformitate GDPR (dreptul de a fi uitat - date locale).
- <WORK_CODE>0262 - Unit test pentru `DataEncryptionService`.
- <WORK_CODE>0263 - Implementare logică de blocare screenshots în ecrane sensibile (opțional).
- <WORK_CODE>0264 - Adăugare avertisment la export backup necriptat.
- <WORK_CODE>0265 - Audit acces fișiere: limitare la `applicationDocumentsDirectory`.
- <WORK_CODE>0266-0300 - Rafinament securitate și audit final Faza 1.

---

## FAZA 2: Modele de Date, Servicii Native și Baza de Date (Commit-uri 0301 - 0450)

### Data Models & Entities (0301 - 0350)
- <WORK_CODE>0301 - Creare `ContactEntity` (clasa principală).
- <WORK_CODE>0302 - Definire `PhoneEntity` (label, value, type).
- <WORK_CODE>0303 - Definire `EmailEntity` (label, value, type).
- <WORK_CODE>0304 - Definire `AddressEntity` (full address, street, city, etc.).
- <WORK_CODE>0305 - Adăugare suport pentru `PhotoEntity` (URI local/Bytes).
- <WORK_CODE>0306 - Creare `GroupEntity` (pentru contacte grupate/duplicate).
- <WORK_CODE>0307 - Implementare `ContactMapper`: mapare de la JSON la Entity.
- <WORK_CODE>0308 - Implementare `ContactMapper`: mapare de la Entity la JSON.
- <WORK_CODE>0309 - Adăugare câmp `isReadOnly` în `ContactEntity`.
- <WORK_CODE>0310 - Adăugare câmp `accountType` (Google, iCloud, SIM, Local).
- <WORK_CODE>0311 - Definire `DuplicateReason` enum (Phone, Email, Name, etc.).
- <WORK_CODE>0312 - Creare `MatchResult` model (score, reasons).
- <WORK_CODE>0313 - Implementare `copyWith` pentru toate entitățile (immutability).
- <WORK_CODE>0314 - Adăugare validări de bază în constructorii entităților.
- <WORK_CODE>0315 - Creare `ContactComparison` utilitar pentru detecție schimbări.
- <WORK_CODE>0316 - Unit test pentru `ContactMapper`.
- <WORK_CODE>0317 - Unit test pentru validări în `ContactEntity`.
- <WORK_CODE>0318-0350 - Buffer pentru extensii modele (ex: Job Title, Birthday).

### Native Services (Android & iOS) (0351 - 0400)
- <WORK_CODE>0351 - Definire `MethodChannel` pentru comunicare nativă.
- <WORK_CODE>0352 - Creare interfață `INativeContactsService`.
- <WORK_CODE>0353 - Implementare `NativeContactsService` (Flutter side).
- <WORK_CODE>0354 - Android: Creare `ContactsProvider` helper (Kotlin).
- <WORK_CODE>0355 - Android: Implementare metodă `fetchContacts` (batch reading).
- <WORK_CODE>0356 - Android: Implementare metodă `fetchContactPhoto` (on demand).
- <WORK_CODE>0357 - Android: Implementare detecție contacte Read-Only.
- <WORK_CODE>0358 - iOS: Creare `ContactsHelper` (Swift).
- <WORK_CODE>0359 - iOS: Implementare metodă `fetchContacts` (CNContactStore).
- <WORK_CODE>0360 - iOS: Implementare metodă `fetchContactPhoto`.
- <WORK_CODE>0361 - iOS: Mapare `CNContact` la formatul intern JSON.
- <WORK_CODE>0362 - Implementare logică de "Pagination" la citirea contactelor.
- <WORK_CODE>0363 - Tratare Timeout la citirea unor agende foarte mari.
- <WORK_CODE>0364 - Android: Implementare interogare după `MIMETYPE`.
- <WORK_CODE>0365 - iOS: Implementare filtrare după `containerId`.
- <WORK_CODE>0366 - Adăugare suport pentru citire contacte din grupuri specifice.
- <WORK_CODE>0367 - Implementare logică de "Diff" nativă (opțional).
- <WORK_CODE>0368 - Unit test pentru `NativeContactsService` (Mock MethodChannel).
- <WORK_CODE>0369 - Verificare performanță: citire 5000 contacte în Simulator.
- <WORK_CODE>0370 - Verificare performanță: citire 5000 contacte pe Real Device.
- <WORK_CODE>0371-0400 - Rafinament cod nativ și tratare corner-cases.

### Local Database (0401 - 0450)
- <WORK_CODE>0401 - Alegere și configurare `Drift` (sau `Isar`) database.
- <WORK_CODE>0402 - Definire tabel `ContactsCache`.
- <WORK_CODE>0403 - Definire tabel `DuplicateGroups`.
- <WORK_CODE>0404 - Definire tabel `BackupHistory`.
- <WORK_CODE>0405 - Definire tabel `AppSettings` (persistente).
- <WORK_CODE>0406 - Implementare `DatabaseService` (Singleton/Provider).
- <WORK_CODE>0407 - Creare `ContactDao` pentru operații CRUD contacte.
- <WORK_CODE>0408 - Creare `GroupDao` pentru operații CRUD duplicate.
- <WORK_CODE>0409 - Creare `BackupDao` pentru istoricul salvărilor.
- <WORK_CODE>0410 - Implementare logică de migrare bază de date (V1 -> V2).
- <WORK_CODE>0411 - Implementare funcție "Clear Cache" (SQLite wipe).
- <WORK_CODE>0412 - Adăugare indexuri SQL pentru căutare rapidă după nume/telefon.
- <WORK_CODE>0413 - Implementare tranzacții SQL pentru salvări multiple.
- <WORK_CODE>0414 - Unit test pentru `ContactDao`.
- <WORK_CODE>0415 - Unit test pentru migrare bază de date.
- <WORK_CODE>0416 - Verificare dimensiune DB cu 10.000 contacte cache-uite.
- <WORK_CODE>0417 - Adăugare suport pentru auto-backup DB (opțional).
- <WORK_CODE>0418-0450 - Rafinament persistență și optimizări query-uri.

---

## FAZA 3: Algoritmi de Normalizare și Detecție Duplicate (Commit-uri 0451 - 0600)

### Normalization Service (0451 - 0500)
- <WORK_CODE>0451 - Creare `NormalizationService`.
- <WORK_CODE>0452 - Implementare normalizare telefon: eliminare caractere non-numerice.
- <WORK_CODE>0453 - Normalizare telefon: tratare prefix +40 (România).
- <WORK_CODE>0454 - Normalizare telefon: tratare prefix 0040.
- <WORK_CODE>0455 - Normalizare telefon: transformare 07xx în format internațional standard.
- <WORK_CODE>0456 - Implementare normalizare Email: lowercase + trim.
- <WORK_CODE>0457 - Implementare normalizare Nume: eliminare spații multiple.
- <WORK_CODE>0458 - Normalizare Nume: transformare în lowercase pentru comparație.
- <WORK_CODE>0459 - Normalizare Nume: eliminare opțională diacritice (pentru match).
- <WORK_CODE>0460 - Normalizare Nume: detecție inversiune Nume/Prenume.
- <WORK_CODE>0461 - Implementare serviciu de curățare caractere speciale din nume.
- <WORK_CODE>0462 - Creare `PhoneticService` (ex: Soundex adaptat pentru RO - opțional).
- <WORK_CODE>0463 - Unit test: Normalizare telefoane (RO, International).
- <WORK_CODE>0464 - Unit test: Normalizare emailuri (variante complexe).
- <WORK_CODE>0465 - Unit test: Normalizare nume (diacritice, spații).
- <WORK_CODE>0466 - Verificare performanță: normalizare 5000 string-uri.
- <WORK_CODE>0467 - Adăugare suport pentru normalizare numere scurte (short-codes).
- <WORK_CODE>0468 - Implementare logică de "Smart Trim" pentru nume foarte lungi.
- <WORK_CODE>0469-0500 - Buffer pentru reguli specifice de normalizare.

### Duplicate Detection Logic (0501 - 0550)
- <WORK_CODE>0501 - Creare `DuplicateDetectorService`.
- <WORK_CODE>0502 - Algoritm 1: Potrivire după Telefon Identic (Scor 100).
- <WORK_CODE>0503 - Algoritm 2: Potrivire după Email Identic (Scor 100).
- <WORK_CODE>0504 - Algoritm 3: Potrivire după Nume Identic (Scor 90).
- <WORK_CODE>0505 - Algoritm 4: Potrivire după Nume Similar (Levenshtein Distance).
- <WORK_CODE>0506 - Algoritm 5: Potrivire combinată (Nume Similar + Companie).
- <WORK_CODE>0507 - Algoritm 6: Potrivire după Nume + parte din Telefon.
- <WORK_CODE>0508 - Implementare sistem de ponderi (Weight System) pentru scor.
- <WORK_CODE>0509 - Logică de clasificare: Sigur (95+), Probabil (80-94), Manual (60-79).
- <WORK_CODE>0510 - Implementare "Transitive Closure" (A=B, B=C => A=B=C).
- <WORK_CODE>0511 - Optimizare detecție prin indexare prealabilă în memorie (Maps).
- <WORK_CODE>0512 - Implementare filtru pentru "False Positives" cunoscute.
- <WORK_CODE>0513 - Logică de ignorare contacte din Whitelist.
- <WORK_CODE>0514 - Creare serviciu de generare "Motive Potrivire" (Match Reasons).
- <WORK_CODE>0515 - Unit test: Matrice de testare algoritmi de potrivire.
- <WORK_CODE>0516 - Unit test: Verificare scoruri pentru diverse cazuri.
- <WORK_CODE>0517 - Verificare performanță: detecție pe 2000 contacte.
- <WORK_CODE>0518 - Verificare performanță: detecție pe 5000 contacte.
- <WORK_CODE>0519 - Implementare logică de procesare în "Chunks" (background).
- <WORK_CODE>0520 - Adăugare suport pentru detecție duplicate pe baza pozei (hash - opțional).
- <WORK_CODE>0521-0550 - Rafinare euristici și eliminare bucle infinite.

### Background Processing (0551 - 0600)
- <WORK_CODE>0551 - Configurare `Isolates` (Flutter) pentru scanare grea.
- <WORK_CODE>0552 - Implementare `ScanController` cu progres în timp real.
- <WORK_CODE>0553 - Creare serviciu de comunicare între UI și Isolate.
- <WORK_CODE>0554 - Implementare logică de pauză/repornire scanare.
- <WORK_CODE>0555 - Adăugare suport pentru Background Task (Android WorkManager).
- <WORK_CODE>0556 - Adăugare suport pentru Background Task (iOS Background Fetch).
- <WORK_CODE>0557 - Implementare notificare (Local Notification) la finalizare scanare.
- <WORK_CODE>0558 - Verificare consum baterie în timpul scanării intense.
- <WORK_CODE>0559 - Unit test pentru `ScanController` (Mock scan process).
- <WORK_CODE>0560 - Integrare status scanare în Dashboard widget.
- <WORK_CODE>0561-0600 - Rafinament procesare asincronă.

---

## FAZA 4: Interfață Utilizator - Dashboard și Liste (Commit-uri 0601 - 0800)

### Dashboard Screen (0601 - 0650)
- <WORK_CODE>0601 - Implementare `DashboardController`.
- <WORK_CODE>0602 - UI Dashboard: Header cu profil și status general.
- <WORK_CODE>0603 - UI Dashboard: Widget central cu număr total contacte.
- <WORK_CODE>0604 - UI Dashboard: Widget central cu număr duplicate găsite.
- <WORK_CODE>0605 - UI Dashboard: Buton principal "Scanează Acum".
- <WORK_CODE>0606 - UI Dashboard: Listă orizontală cu ultimele grupuri găsite.
- <WORK_CODE>0607 - UI Dashboard: Carduri statistice (economie spațiu, timp).
- <WORK_CODE>0608 - UI Dashboard: Indicator stare backup (Safe/Warning).
- <WORK_CODE>0609 - Implementare animații de încărcare date în Dashboard.
- <WORK_CODE>0610 - Adăugare suport pentru "Pull to Refresh" în Dashboard.
- <WORK_CODE>0611 - Widget test pentru `DashboardScreen`.
- <WORK_CODE>0612 - Adăugare gesturi (swipe) pentru navigare rapidă.
- <WORK_CODE>0613 - Integrare tutorial scurt la prima deschidere Dashboard.
- <WORK_CODE>0614-0650 - Rafinament UX Dashboard.

### Duplicate List & Filters (0651 - 0700)
- <WORK_CODE>0651 - Implementare `DuplicateListController`.
- <WORK_CODE>0652 - UI Listă Duplicate: Listă verticală cu Lazy Loading.
- <WORK_CODE>0653 - UI Listă Duplicate: Tab-uri (Sigur, Probabil, Toate).
- <WORK_CODE>0654 - UI Listă Duplicate: Căutare în timp real după nume.
- <WORK_CODE>0655 - UI Listă Duplicate: Filtrare după scor.
- <WORK_CODE>0656 - UI Listă Duplicate: Filtrare după tip duplicat (Telefon/Email).
- <WORK_CODE>0657 - Implementare Selectie Multiplă (Bulk Action).
- <WORK_CODE>0658 - UI Card Grup: Afișare contacte principale și motive.
- <WORK_CODE>0659 - UI Card Grup: Acțiuni rapide (Ignoră, Merge Instant).
- <WORK_CODE>0660 - Adăugare animație la ștergerea unui grup din listă.
- <WORK_CODE>0661 - Implementare "Empty Search Result" state.
- <WORK_CODE>0662 - Widget test pentru `DuplicateListScreen`.
- <WORK_CODE>0663 - Verificare performanță listă cu 500 grupuri.
- <WORK_CODE>0664-0700 - Rafinament UI listă și tranziții.

### Merge Detail Screen (0701 - 0750)
- <WORK_CODE>0701 - Implementare `MergeDetailController`.
- <WORK_CODE>0702 - UI Merge Detail: Vizualizare comparativă contacte (Side by Side).
- <WORK_CODE>0703 - UI Merge Detail: Selectie manuală contact "Master".
- <WORK_CODE>0704 - UI Merge Detail: Selectie câmpuri individuale de păstrat.
- <WORK_CODE>0705 - UI Merge Detail: Evidențiere conflicte (valori diferite).
- <WORK_CODE>0706 - UI Merge Detail: Editare rapidă nume final rezultat.
- <WORK_CODE>0707 - UI Merge Detail: Vizualizare preview contact final.
- <WORK_CODE>0708 - Adăugare buton "Confirmă & Unește".
- <WORK_CODE>0709 - Implementare logică de blocare merge dacă există erori UI.
- <WORK_CODE>0710 - Widget test pentru `MergeDetailScreen`.
- <WORK_CODE>0711-0750 - Rafinament UI detalii și logică selecție.

### Settings & Profile (0751 - 0800)
- <WORK_CODE>0751 - Implementare `SettingsController`.
- <WORK_CODE>0752 - UI Settings: Schimbare Temă (Dark/Light/System).
- <WORK_CODE>0753 - UI Settings: Schimbare Limbă.
- <WORK_CODE>0754 - UI Settings: Ajustare sensibilitate algoritm (Scor minim).
- <WORK_CODE>0755 - UI Settings: Gestionare Whitelist (Contacte Ignorate).
- <WORK_CODE>0756 - UI Settings: Secțiune Backup (Auto-backup settings).
- <WORK_CODE>0757 - UI Settings: Despre Aplicație, Versiune, Licențe.
- <WORK_CODE>0758 - UI Settings: Buton Șterge Istoric Scanare.
- <WORK_CODE>0759 - Implementare feedback către dezvoltator (Email/Formular).
- <WORK_CODE>0760 - Widget test pentru `SettingsScreen`.
- <WORK_CODE>0761-0800 - Rafinament UI setări.

---

## FAZA 5: Merge Engine, Backup și Istoric (Commit-uri 0801 - 0920)

### Backup Service (0801 - 0840)
- <WORK_CODE>0801 - Creare `BackupService`.
- <WORK_CODE>0802 - Implementare export contacte în format VCF (vCard).
- <WORK_CODE>0803 - Implementare export contacte în format JSON (pentru restaurare internă).
- <WORK_CODE>0804 - Logică de generare nume fișier backup: `backup_YYYYMMDD_HHMMSS`.
- <WORK_CODE>0805 - Implementare serviciu de stocare fișiere backup (Local Storage).
- <WORK_CODE>0806 - Creare `BackupMetadata` model.
- <WORK_CODE>0807 - Implementare logică de "Auto-cleanup" backup-uri vechi (limită număr/zile).
- <WORK_CODE>0808 - Implementare verificare spațiu liber înainte de backup.
- <WORK_CODE>0809 - UI Listă Backup-uri: afișare dată, dimensiune și nr. contacte.
- <WORK_CODE>0810 - Implementare funcție "Share Backup" (partajare fișier VCF).
- <WORK_CODE>0811 - Implementare funcție "Restaurare din Backup".
- <WORK_CODE>0812 - Logică de validare integritate fișier backup înainte de restaurare.
- <WORK_CODE>0813 - Unit test pentru `BackupService`.
- <WORK_CODE>0814 - Verificare performanță: backup 5000 contacte.
- <WORK_CODE>0815-0840 - Buffer pentru stabilitate serviciu backup.

### Merge Engine (0841 - 0880)
- <WORK_CODE>0841 - Creare `MergeEngineService`.
- <WORK_CODE>0842 - Implementare logică "Safe Merge": obligativitate backup.
- <WORK_CODE>0843 - Android: Implementare `writeContact` (ContentProvider Batch).
- <WORK_CODE>0844 - Android: Implementare `deleteContact`.
- <WORK_CODE>0845 - iOS: Implementare `writeContact` (CNContactStore).
- <WORK_CODE>0846 - iOS: Implementare `deleteContact`.
- <WORK_CODE>0847 - Implementare logică de "Atomic Merge" (all or nothing) - unde e posibil.
- <WORK_CODE>0848 - Tratare erori de scriere: Read-Only, Insufficient Permissions.
- <WORK_CODE>0849 - Implementare logică de "Conflict Resolution" la scriere.
- <WORK_CODE>0850 - Creare raport post-merge (ce s-a schimbat efectiv).
- <WORK_CODE>0851 - Implementare progres merge în UI (Step by Step).
- <WORK_CODE>0852 - Adăugare suport pentru merge poze profil.
- <WORK_CODE>0853 - Verificare consistență date după merge (re-scanare grup).
- <WORK_CODE>0854 - Unit test pentru logică `MergeEngine` (Mock native).
- <WORK_CODE>0855 - Verificare pe dispozitiv real: merge 10 grupuri simultan.
- <WORK_CODE>0856-0880 - Buffer pentru stabilitate engine scriere.

### History & Activity Log (0881 - 0920)
- <WORK_CODE>0881 - Creare `HistoryService`.
- <WORK_CODE>0882 - Definire `HistoryEntry` model.
- <WORK_CODE>0883 - Implementare salvare automată după fiecare merge.
- <WORK_CODE>0884 - UI History Screen: Listă cronologică activități.
- <WORK_CODE>0885 - UI History Detail: Detalii despre contactele unite într-o sesiune.
- <WORK_CODE>0886 - Implementare funcție "Undo Merge" (bazată pe backup JSON).
- <WORK_CODE>0887 - Logică de marcare istoric ca "Incomplet" în caz de erori.
- <WORK_CODE>0888 - Widget test pentru `HistoryScreen`.
- <WORK_CODE>0889-0920 - Rafinament istoric.

---

## FAZA 6: Testare Finală, Optimizare și Store (Commit-uri 0921 - 1000)

### Testing & Bug Fixing (0921 - 0960)
- <WORK_CODE>0921 - Testare regresie pe Android 10, 11, 12, 13, 14.
- <WORK_CODE>0922 - Testare regresie pe iOS 15, 16, 17.
- <WORK_CODE>0923 - Testare performanță agendă 10.000 contacte.
- <WORK_CODE>0924 - Testare stres: închidere aplicație în timpul merge-ului.
- <WORK_CODE>0925 - Testare lipsă internet (nu ar trebui să afecteze funcționarea).
- <WORK_CODE>0926 - Rezolvare bug-uri UI (overflow, contrast).
- <WORK_CODE>0927 - Optimizare dimensiune APK/IPA (eliminare asset-uri nefolosite).
- <WORK_CODE>0928 - Verificare scurgeri de memorie (Memory Leaks) în Isolate-uri.
- <WORK_CODE>0929 - Testare cu contacte din surse multiple (Exchange, SIM, WhatsApp).
- <WORK_CODE>0930-0960 - Sesiune intensă de bug-fixing bazată pe testele de mai sus.

### Final Prep & Store Compliance (0961 - 1000)
- <WORK_CODE>0961 - Generare Screenshot-uri pentru Google Play.
- <WORK_CODE>0962 - Generare Screenshot-uri pentru App Store.
- <WORK_CODE>0963 - Finalizare descriere aplicație și cuvinte cheie.
- <WORK_CODE>0964 - Configurare App Store Connect: App Privacy details.
- <WORK_CODE>0965 - Configurare Google Play Console: Data Safety section.
- <WORK_CODE>0966 - Audit final loguri: asigurare că nu există PII.
- <WORK_CODE>0967 - Verificare link-uri suport și privacy policy.
- <WORK_CODE>0968 - Pregătire Release Notes (RO/EN).
- <WORK_CODE>0969 - Incrementare versiune la 1.0.0.
- <WORK_CODE>0970 - Build final de producție (Release mode).
- <WORK_CODE>0971-1000 - Buffer pentru feedback de la Store Review.

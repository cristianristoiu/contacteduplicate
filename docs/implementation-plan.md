# Contacte Duplicate - plan de implementare

## Obiectiv

Construirea unei aplicatii mobile Android si iOS care gaseste, verifica si uneste contactele duplicate local pe dispozitiv, fara upload in cloud si cu flux complet de backup si confirmare.

## Reguli obligatorii

1. Nu se modifica contacte fara backup.
2. Nu se modifica contacte fara confirmare explicita.
3. Nu se cer permisiuni fara explicatie clara.
4. Nu se trimit contacte in cloud.
5. Nu se logheaza nume, telefon, email sau alte date personale.
6. Nu se promite separarea surselor daca platforma nu o permite.
7. Nu se face auto-merge sub scor 95.
8. Contactele read-only sunt tratate ca limitare normala.

## Reguli pentru Agenti Paraleli

1. Fiecare commit foloseste formatul `<WORK_CODE><NUMAR> - <DESCRIERE>`.
2. `<WORK_CODE>` este un placeholder care va fi inlocuit de prefixul specific agentului (ex: `JNI`, `CDX`, `CHT`).
3. Numerotarea reala a commiturilor continua dupa cel mai mare work code existent in istoria reala a branchului `main`, conform `docs/commit-rules.md`.
4. Planul este renumerotat de la `<WORK_CODE>0018`, deoarece in istoria reala exista deja `<WORK_CODE>0001-0017` consumate inaintea batch-ului curent.
5. `<WORK_CODE>` ramane obligatoriu in plan si nu se inlocuieste cu alt termen.
6. Agentii pot lucra pe intervale diferite (ex: Agent A pe 0118-0217, Agent B pe 0618-0767), dar trebuie sa respecte dependentele de cod.
7. Daca un interval depinde de codul din alt interval care nu este inca gata, agentul va folosi interfete/mock-uri care vor fi implementate ulterior.

## Faza 0: Infrastructura si Tema (Commit-uri 0018-0117)

- ~~<WORK_CODE>0018 - Initializare proiect Flutter gol.~~ COMPLETAT: `CHT0018`.
- ~~<WORK_CODE>0019 - Configurare .gitignore detaliat pentru Flutter/Dart.~~ COMPLETAT: `CHT0019`.
- ~~<WORK_CODE>0020 - Configurare linting reguli stricte (analysis_options.yaml).~~ COMPLETAT: `CHT0020`.
- ~~<WORK_CODE>0021 - Adaugare asset-uri logo (SVG) in proiect.~~ COMPLETAT: `CHT0021`.
- ~~<WORK_CODE>0022 - Creeaza punctul de intrare Flutter.~~ COMPLETAT: `CHT0022`.
- ~~<WORK_CODE>0023 - Configurare aplicatie principala Flutter.~~ COMPLETAT: `CHT0023`.
- ~~<WORK_CODE>0024 - Implementare sistem de culori conform theme-guide.md.~~ COMPLETAT: `CHT0024`.
- ~~<WORK_CODE>0025 - Implementare clasa de text styles conform theme-guide.md.~~ COMPLETAT: `CHT0025`.
- ~~<WORK_CODE>0026 - Configurare ThemeData pentru Light Mode si Dark Mode.~~ COMPLETAT: `CHT0026`.
- ~~<WORK_CODE>0027 - Implementare ThemeProvider pentru gestionarea temei (Light/Dark/System).~~ COMPLETAT: `CHT0027`.
- ~~<WORK_CODE>0028 - Configurare localization (suport limba romana si engleza).~~ COMPLETAT: `CHT0028`.
- ~~<WORK_CODE>0029 - Implementare sistem elementar de logging (fara PII).~~ COMPLETAT: `CHT0029`.
- ~~<WORK_CODE>0030 - Configurare rute principale (go_router sau similar).~~ COMPLETAT: `CHT0030`.
- ~~<WORK_CODE>0031 - Creare widget-uri de baza pentru butoane (PrimaryButton).~~ COMPLETAT: `CHT0031`.
- ~~<WORK_CODE>0032 - Creare widget-uri de baza pentru butoane (SecondaryButton).~~ COMPLETAT: `CHT0032`.
- ~~<WORK_CODE>0033 - Implementare card-uri UI generice cu design-ul din theme-guide.md.~~ COMPLETAT: `CHT0033`.
- ~~<WORK_CODE>0034 - Implementare Layout principal (Scaffold custom).~~ COMPLETAT: `CHT0034`.
- ~~<WORK_CODE>0035 - Implementare Splash Screen de baza.~~ COMPLETAT: `CHT0035`.
- ~~<WORK_CODE>0036 - Implementare Dashboard brut.~~ COMPLETAT: `CHT0036`.
- ~~<WORK_CODE>0037 - Implementare ecran brut de Setari.~~ COMPLETAT: `CHT0037`.
- ~~<WORK_CODE>0038 - Adaugare structura Android de baza.~~ COMPLETAT: `CHT0038`.
- ~~<WORK_CODE>0039 - Configurare build Android radacina.~~ COMPLETAT: `CHT0039`.
- ~~<WORK_CODE>0040 - Configurare modul Android app.~~ COMPLETAT: `CHT0040`.
- ~~<WORK_CODE>0041 - Adaugare manifest Android cu permisiuni contacte.~~ COMPLETAT: `CHT0041`.
- ~~<WORK_CODE>0042 - Adaugare MainActivity Android.~~ COMPLETAT: `CHT0042`.
- ~~<WORK_CODE>0043 - Adaugare stil lansare Android.~~ COMPLETAT: `CHT0043`.
- ~~<WORK_CODE>0044 - Adaugare Info.plist pentru iOS.~~ COMPLETAT: `CHT0044`.
- ~~<WORK_CODE>0045 - Adaugare AppDelegate pentru iOS.~~ COMPLETAT: `CHT0045`.
- ~~<WORK_CODE>0046 - Marcare taskuri brute finalizate in plan.~~ COMPLETAT: `CHT0046`.
- ~~<WORK_CODE>0047 - Clarificare numerotare reala in plan.~~ COMPLETAT: `CHT0047`.
- ~~<WORK_CODE>0048 - Restaurare format work code in plan.~~ COMPLETAT: `CHT0048`.
- ~~<WORK_CODE>0049 - Renumerotare plan implementare.~~ COMPLETAT: `CHT0049`.
- <WORK_CODE>0050-0117 - Rafinament UI componente, unit tests pentru core, configurari CI/CD de baza. BLOCAT PENTRU APROBARE: momentan se implementeaza doar parti brute, fara rafinari, optimizari sau elemente cheie fara confirmare explicita.

## Faza 1: Onboarding si Permisiuni (Commit-uri 0118-0217)

- <WORK_CODE>0118 - Creare model pentru paginile de onboarding.
- <WORK_CODE>0119 - Implementare PageView pentru onboarding.
- <WORK_CODE>0120 - UI pentru pagina 1 onboarding: Vizualizare si Siguranta.
- <WORK_CODE>0121 - UI pentru pagina 2 onboarding: Backup si Control.
- <WORK_CODE>0122 - UI pentru pagina 3 onboarding: Permisiuni necesare.
- <WORK_CODE>0123 - Implementare Permission Service (interfata abstracta).
- <WORK_CODE>0124 - Implementare Permission Service pentru Android (permission_handler).
- <WORK_CODE>0125 - Implementare Permission Service pentru iOS (permission_handler).
- <WORK_CODE>0126 - Ecran special pentru explicarea permisiunii de contacte (pre-prompt).
- <WORK_CODE>0127 - Logica de verificare status permisiuni la startup.
- <WORK_CODE>0128 - Tratare caz permisiune refuzata (afisare buton setari sistem).
- <WORK_CODE>0129 - Tratare caz permisiune restrictionata (iOS).
- <WORK_CODE>0130 - UI pentru ecranul "Acces Necesar" cu explicatii clare.
- <WORK_CODE>0131 - Implementare storage local pentru flag-ul "onboarding_completed" (shared_preferences).
- <WORK_CODE>0132 - Teste unitare pentru logica de onboarding.
- <WORK_CODE>0133-0217 - Tranzitii ecrane, animatii discrete, teste integrare permisiuni.

## Faza 2: Citire si Normalizare Contacte (Commit-uri 0218-0417)

- <WORK_CODE>0218 - Definire ContactModel (id, name, phones, emails, photo, rawData).
- <WORK_CODE>0219 - Definire PhoneModel (label, value, normalizedValue).
- <WORK_CODE>0220 - Definire EmailModel (label, value, normalizedValue).
- <WORK_CODE>0221 - Implementare Repository abstract pentru contacte.
- <WORK_CODE>0222 - Implementare Native Contact Service (Platform Channels) - Structura.
- <WORK_CODE>0223 - Android: Implementare citire contacte via Kotlin (ContactsContract).
- <WORK_CODE>0224 - Android: Optimizare interogare pentru viteza (projections).
- <WORK_CODE>0225 - iOS: Implementare citire contacte via Swift (CNContactStore).
- <WORK_CODE>0226 - iOS: Mapare campuri native la ContactModel.
- <WORK_CODE>0227 - Implementare serviciu de Normalizare Telefoane (reguli RO).
- <WORK_CODE>0228 - Implementare serviciu de Normalizare Emailuri.
- <WORK_CODE>0229 - Implementare serviciu de Normalizare Nume (diacritice, spatii).
- <WORK_CODE>0230 - Logica de detectare contacte Read-Only (Android account type).
- <WORK_CODE>0231 - Logica de detectare contacte Read-Only (iOS container/source).
- <WORK_CODE>0232 - Implementare incarcare contacte in batch-uri pentru a evita blocarea UI.
- <WORK_CODE>0233 - Creare Background Worker pentru procesarea contactelor.
- <WORK_CODE>0234 - Implementare cache local pentru contacte (pentru viteza scanari ulterioare).
- <WORK_CODE>0235 - Teste unitare pentru normalizare (variante de numere RO).
- <WORK_CODE>0236 - Teste unitare pentru normalizare nume complexe.
- <WORK_CODE>0237-0417 - Optimizari memorie, tratare cazuri limita (contacte fara nume, mii de numere), unit tests platform specific.

## Faza 3: Algoritmi Detectare Duplicate si Scoring (Commit-uri 0418-0617)

- <WORK_CODE>0418 - Definire DuplicateGroup model (list contacte, score, reasons).
- <WORK_CODE>0419 - Algoritm detectare duplicate dupa Telefon Identic (scor 100).
- <WORK_CODE>0420 - Algoritm detectare duplicate dupa Email Identic (scor 100).
- <WORK_CODE>0421 - Algoritm detectare duplicate dupa Nume Exact (scor 90).
- <WORK_CODE>0422 - Algoritm detectare duplicate dupa Nume Similar (Levenshtein distance).
- <WORK_CODE>0423 - Implementare sistem de ponderi pentru scoring combinat.
- <WORK_CODE>0424 - Logica de marcare "Sigur" vs "Probabil" conform proiect-plan.md.
- <WORK_CODE>0425 - Implementare sistem de "Motive" pentru potrivire (ex: "Acelasi numar de telefon").
- <WORK_CODE>0426 - Optimizare algoritm prin indexare prealabila (Map-uri de cautare rapida).
- <WORK_CODE>0427 - Tratare cazuri de "False Positives" comune.
- <WORK_CODE>0428 - Logica de grupare transitiva (A=B si B=C => A,B,C sunt duplicate).
- <WORK_CODE>0429 - Implementare filtru pentru ignorare contacte protejate.
- <WORK_CODE>0430 - Serviciu de analiza statistica a duplicatelor (total grupuri, potentiale economii).
- <WORK_CODE>0431 - Teste unitare pentru algoritmul de scoring (matrice de teste).
- <WORK_CODE>0432-0617 - Rafinare euristici, teste de performanta pe seturi mari de date, eliminare bucle infinite in grupari.

## Faza 4: Interfata Dashboard si Liste Duplicate (Commit-uri 0618-0767)

- <WORK_CODE>0618 - UI Dashboard: Cerc de progres central (animat).
- <WORK_CODE>0619 - UI Dashboard: Statistici rapide (Total contacte, Duplicate).
- <WORK_CODE>0620 - UI Dashboard: Buton principal "Incepe Scanarea".
- <WORK_CODE>0621 - UI Dashboard: Carduri pentru starea ultimei scanari.
- <WORK_CODE>0622 - UI Lista Duplicate: Categorisire pe tab-uri (Sigur, Probabil, Toate).
- <WORK_CODE>0623 - UI Card Duplicat: Afisare contacte in grup, scor si badge status.
- <WORK_CODE>0624 - Implementare Search si Filtrare in lista de duplicate.
- <WORK_CODE>0625 - Implementare Selectie Multipla pentru grupuri.
- <WORK_CODE>0626 - UI Ecran Detalii Grup: Comparatie coloana langa coloana a contactelor.
- <WORK_CODE>0627 - UI Ecran Detalii Grup: Selectie campuri de pastrat (radio buttons custom).
- <WORK_CODE>0628 - UI Ecran Detalii Grup: Identificare si marcare conflicte vizuale.
- <WORK_CODE>0629 - UI Preview Merge: Rezumatul schimbarilor (ce se sterge, ce se updateaza).
- <WORK_CODE>0630 - Implementare tranzitii intre Dashboard si Liste.
- <WORK_CODE>0631 - UI Empty States pentru dashboard si liste.
- <WORK_CODE>0632-0767 - Rafinament UX, feedback vizual la tap, skeleton loaders, teste widget.

## Faza 5: Logica de Merge si Backup (Commit-uri 0768-0917)

- <WORK_CODE>0768 - Definire BackupModel (vCard format sau JSON proprietar).
- <WORK_CODE>0769 - Serviciu de Backup: Generare fisier backup local (internal storage).
- <WORK_CODE>0770 - Serviciu de Backup: Logica de versionare si curatare backup-uri vechi.
- <WORK_CODE>0771 - UI Ecran Backup: Lista de fisiere salvate cu detalii.
- <WORK_CODE>0772 - Logica de "Safe Merge": Blocare operatiune daca backup-ul nu a fost creat cu succes.
- <WORK_CODE>0773 - Implementare Merge Engine: Creare contact nou unit.
- <WORK_CODE>0774 - Implementare Merge Engine: Stergere contacte duplicate vechi.
- <WORK_CODE>0775 - Android: Operatiuni atomice de write via ContentProvider (Batch operations).
- <WORK_CODE>0776 - iOS: Operatiuni de write via CNContactStore (CNSaveRequest).
- <WORK_CODE>0777 - Tratare erori la scriere: Rollback logic sau raportare eroare.
- <WORK_CODE>0778 - Implementare ProgressBar pentru operatiunea de merge.
- <WORK_CODE>0779 - Serviciu de Restaurare: Citire backup si rescriere in agenda.
- <WORK_CODE>0780 - UI Dialog Confirmare Critica inainte de Merge.
- <WORK_CODE>0781 - Teste unitare pentru logica de merge campuri (diverse combinatii).
- <WORK_CODE>0782-0917 - Teste pe dispozitive reale pentru scriere, verificari permisiuni de scriere, stabilitate la intreruperi.

## Faza 6: Istoric, Setari si Finalizare Store (Commit-uri 0918-1017)

- <WORK_CODE>0918 - Implementare Baza de date locala (SQLite/Sembast) pentru Istoric.
- <WORK_CODE>0919 - UI Ecran Istoric: Lista cronologica a activitatilor.
- <WORK_CODE>0920 - UI Detalii Istoric: Ce grupuri au fost unite in acea sesiune.
- <WORK_CODE>0921 - UI Ecran Setari: Switch-uri tema (Light/Dark/System).
- <WORK_CODE>0922 - UI Ecran Setari: Optiuni senzitivitate algoritm scanare.
- <WORK_CODE>0923 - UI Ecran Setari: Gestionare contacte protejate (Whitelist).
- <WORK_CODE>0924 - UI Ecran Setari: Buton "Sterge tot istoricul".
- <WORK_CODE>0925 - UI Ecran Setari: Despre aplicatie si versiune.
- <WORK_CODE>0926 - Implementare ecran Privacy Policy in-app.
- <WORK_CODE>0927 - Pregatire assets pentru store (screenshots generator).
- <WORK_CODE>0928 - Configurare Fastlane pentru deploy automat (optional).
- <WORK_CODE>0929 - Audit final de securitate: Verificare leak-uri date personale in loguri.
- <WORK_CODE>0930 - Verificare finala store compliance (Apple & Google).
- <WORK_CODE>0931 - Optimizare dimensiune bundle aplicatie.
- <WORK_CODE>0932-1017 - Bug fixing final, polish UI, pregatire release notes, tagging versiune 1.0.0.

## Ordine de Lucru Recomandata pentru Paralelizare

1. **Echipa A (0018-0117, 0618-0767)**: UI/UX, Tema, Dashboard, Liste.
2. **Echipa B (0218-0417, 0768-0917)**: Servicii Native, Citire/Scriere Contacte, Backup.
3. **Echipa C (0118-0217, 0418-0617)**: Onboarding, Algoritmi de detectie, Scoring.
4. **Echipa D (0918-1017)**: Istoric, Setari, Store compliance, Integrare Finala.

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
4. Numerotarea din acest fisier ramane structura de planificare a taskurilor. Nu se inlocuieste `<WORK_CODE>` cu termenul `Task`.
5. Daca in istoria reala exista deja `JNI0017`, urmatorul commit ChatGPT este `CHT0018`, chiar daca primul task din plan este `<WORK_CODE>0001`.
6. Agentii pot lucra pe intervale diferite (ex: Agent A pe 0100-0200, Agent B pe 0500-0600), dar trebuie sa respecte dependentele de cod.
7. Daca un interval depinde de codul din alt interval care nu este inca gata, agentul va folosi interfete/mock-uri care vor fi implementate ulterior.

## Faza 0: Infrastructura si Tema (Commit-uri 0001-0100)

- ~~<WORK_CODE>0001 - Initializare proiect Flutter gol.~~ COMPLETAT: `CHT0018`, `CHT0038-CHT0045`.
- ~~<WORK_CODE>0002 - Configurare .gitignore detaliat pentru Flutter/Dart.~~ COMPLETAT: `CHT0019`.
- ~~<WORK_CODE>0003 - Adaugare dependente de baza in pubspec.yaml (provider, flutter_svg, path_provider).~~ COMPLETAT: `CHT0018`.
- ~~<WORK_CODE>0004 - Configurare linting reguli stricte (analysis_options.yaml).~~ COMPLETAT: `CHT0020`.
- ~~<WORK_CODE>0005 - Creare structura foldere: lib/core, lib/features, lib/shared.~~ COMPLETAT: `CHT0022-CHT0037`.
- ~~<WORK_CODE>0006 - Implementare sistem de culori conform theme-guide.md.~~ COMPLETAT: `CHT0024`.
- ~~<WORK_CODE>0007 - Implementare clasa de text styles conform theme-guide.md.~~ COMPLETAT: `CHT0025`.
- ~~<WORK_CODE>0008 - Configurare ThemeData pentru Light Mode.~~ COMPLETAT: `CHT0026`.
- ~~<WORK_CODE>0009 - Configurare ThemeData pentru Dark Mode.~~ COMPLETAT: `CHT0026`.
- ~~<WORK_CODE>0010 - Implementare ThemeProvider pentru gestionarea temei (Light/Dark/System).~~ COMPLETAT: `CHT0027`.
- ~~<WORK_CODE>0011 - Adaugare asset-uri logo (SVG) in proiect.~~ COMPLETAT: `CHT0021`.
- ~~<WORK_CODE>0012 - Implementare Splash Screen de baza.~~ COMPLETAT: `CHT0035`.
- ~~<WORK_CODE>0013 - Configurare rute principale (go_router sau similar).~~ COMPLETAT: `CHT0030`.
- ~~<WORK_CODE>0014 - Implementare Layout principal (Scaffold custom).~~ COMPLETAT: `CHT0034`.
- ~~<WORK_CODE>0015 - Creare widget-uri de baza pentru butoane (PrimaryButton).~~ COMPLETAT: `CHT0031`.
- ~~<WORK_CODE>0016 - Creare widget-uri de baza pentru butoane (SecondaryButton).~~ COMPLETAT: `CHT0032`.
- ~~<WORK_CODE>0017 - Implementare card-uri UI generice cu design-ul din theme-guide.md.~~ COMPLETAT: `CHT0033`.
- ~~<WORK_CODE>0018 - Configurare localization (suport limba romana si engleza).~~ COMPLETAT: `CHT0028`.
- ~~<WORK_CODE>0019 - Implementare sistem elementar de logging (fara PII).~~ COMPLETAT: `CHT0029`.
- <WORK_CODE>0020-0100 - Rafinament UI componente, unit tests pentru core, configurari CI/CD de baza. BLOCAT PENTRU APROBARE: momentan se implementeaza doar parti brute, fara rafinari, optimizari sau elemente cheie fara confirmare explicita.

## Faza 1: Onboarding si Permisiuni (Commit-uri 0101-0200)

- <WORK_CODE>0101 - Creare model pentru paginile de onboarding.
- <WORK_CODE>0102 - Implementare PageView pentru onboarding.
- <WORK_CODE>0103 - UI pentru pagina 1 onboarding: Vizualizare si Siguranta.
- <WORK_CODE>0104 - UI pentru pagina 2 onboarding: Backup si Control.
- <WORK_CODE>0105 - UI pentru pagina 3 onboarding: Permisiuni necesare.
- <WORK_CODE>0106 - Implementare Permission Service (interfata abstracta).
- <WORK_CODE>0107 - Implementare Permission Service pentru Android (permission_handler).
- <WORK_CODE>0108 - Implementare Permission Service pentru iOS (permission_handler).
- <WORK_CODE>0109 - Ecran special pentru explicarea permisiunii de contacte (pre-prompt).
- <WORK_CODE>0110 - Logica de verificare status permisiuni la startup.
- <WORK_CODE>0111 - Tratare caz permisiune refuzata (afisare buton setari sistem).
- <WORK_CODE>0112 - Tratare caz permisiune restrictionata (iOS).
- <WORK_CODE>0113 - UI pentru ecranul "Acces Necesar" cu explicatii clare.
- <WORK_CODE>0114 - Implementare storage local pentru flag-ul "onboarding_completed" (shared_preferences).
- <WORK_CODE>0115 - Teste unitare pentru logica de onboarding.
- <WORK_CODE>0116-0200 - Tranzitii ecrane, animatii discrete, teste integrare permisiuni.

## Faza 2: Citire si Normalizare Contacte (Commit-uri 0201-0400)

- <WORK_CODE>0201 - Definire ContactModel (id, name, phones, emails, photo, rawData).
- <WORK_CODE>0202 - Definire PhoneModel (label, value, normalizedValue).
- <WORK_CODE>0203 - Definire EmailModel (label, value, normalizedValue).
- <WORK_CODE>0204 - Implementare Repository abstract pentru contacte.
- <WORK_CODE>0205 - Implementare Native Contact Service (Platform Channels) - Structura.
- <WORK_CODE>0206 - Android: Implementare citire contacte via Kotlin (ContactsContract).
- <WORK_CODE>0207 - Android: Optimizare interogare pentru viteza (projections).
- <WORK_CODE>0208 - iOS: Implementare citire contacte via Swift (CNContactStore).
- <WORK_CODE>0209 - iOS: Mapare campuri native la ContactModel.
- <WORK_CODE>0210 - Implementare serviciu de Normalizare Telefoane (reguli RO).
- <WORK_CODE>0211 - Implementare serviciu de Normalizare Emailuri.
- <WORK_CODE>0212 - Implementare serviciu de Normalizare Nume (diacritice, spatii).
- <WORK_CODE>0213 - Logica de detectare contacte Read-Only (Android account type).
- <WORK_CODE>0214 - Logica de detectare contacte Read-Only (iOS container/source).
- <WORK_CODE>0215 - Implementare incarcare contacte in batch-uri pentru a evita blocarea UI.
- <WORK_CODE>0216 - Creare Background Worker pentru procesarea contactelor.
- <WORK_CODE>0217 - Implementare cache local pentru contacte (pentru viteza scanari ulterioare).
- <WORK_CODE>0218 - Teste unitare pentru normalizare (variante de numere RO).
- <WORK_CODE>0219 - Teste unitare pentru normalizare nume complexe.
- <WORK_CODE>0220-0400 - Optimizari memorie, tratare cazuri limita (contacte fara nume, mii de numere), unit tests platform specific.

## Faza 3: Algoritmi Detectare Duplicate si Scoring (Commit-uri 0401-0600)

- <WORK_CODE>0401 - Definire DuplicateGroup model (list contacte, score, reasons).
- <WORK_CODE>0402 - Algoritm detectare duplicate dupa Telefon Identic (scor 100).
- <WORK_CODE>0403 - Algoritm detectare duplicate dupa Email Identic (scor 100).
- <WORK_CODE>0404 - Algoritm detectare duplicate dupa Nume Exact (scor 90).
- <WORK_CODE>0405 - Algoritm detectare duplicate dupa Nume Similar (Levenshtein distance).
- <WORK_CODE>0406 - Implementare sistem de ponderi pentru scoring combinat.
- <WORK_CODE>0407 - Logica de marcare "Sigur" vs "Probabil" conform proiect-plan.md.
- <WORK_CODE>0408 - Implementare sistem de "Motive" pentru potrivire (ex: "Acelasi numar de telefon").
- <WORK_CODE>0409 - Optimizare algoritm prin indexare prealabila (Map-uri de cautare rapida).
- <WORK_CODE>0410 - Tratare cazuri de "False Positives" comune.
- <WORK_CODE>0411 - Logica de grupare transitiva (A=B si B=C => A,B,C sunt duplicate).
- <WORK_CODE>0412 - Implementare filtru pentru ignorare contacte protejate.
- <WORK_CODE>0413 - Serviciu de analiza statistica a duplicatelor (total grupuri, potentiale economii).
- <WORK_CODE>0414 - Teste unitare pentru algoritmul de scoring (matrice de teste).
- <WORK_CODE>0415-0600 - Rafinare euristici, teste de performanta pe seturi mari de date, eliminare bucle infinite in grupari.

## Faza 4: Interfata Dashboard si Liste Duplicate (Commit-uri 0601-0750)

- <WORK_CODE>0601 - UI Dashboard: Cerc de progres central (animat).
- <WORK_CODE>0602 - UI Dashboard: Statistici rapide (Total contacte, Duplicate).
- <WORK_CODE>0603 - UI Dashboard: Buton principal "Incepe Scanarea".
- <WORK_CODE>0604 - UI Dashboard: Carduri pentru starea ultimei scanari.
- <WORK_CODE>0605 - UI Lista Duplicate: Categorisire pe tab-uri (Sigur, Probabil, Toate).
- <WORK_CODE>0606 - UI Card Duplicat: Afisare contacte in grup, scor si badge status.
- <WORK_CODE>0607 - Implementare Search si Filtrare in lista de duplicate.
- <WORK_CODE>0608 - Implementare Selectie Multipla pentru grupuri.
- <WORK_CODE>0609 - UI Ecran Detalii Grup: Comparatie coloana langa coloana a contactelor.
- <WORK_CODE>0610 - UI Ecran Detalii Grup: Selectie campuri de pastrat (radio buttons custom).
- <WORK_CODE>0611 - UI Ecran Detalii Grup: Identificare si marcare conflicte vizuale.
- <WORK_CODE>0612 - UI Preview Merge: Rezumatul schimbarilor (ce se sterge, ce se updateaza).
- <WORK_CODE>0613 - Implementare tranzitii intre Dashboard si Liste.
- <WORK_CODE>0614 - UI Empty States pentru dashboard si liste.
- <WORK_CODE>0615-0750 - Rafinament UX, feedback vizual la tap, skeleton loaders, teste widget.

## Faza 5: Logica de Merge si Backup (Commit-uri 0751-0900)

- <WORK_CODE>0751 - Definire BackupModel (vCard format sau JSON proprietar).
- <WORK_CODE>0752 - Serviciu de Backup: Generare fisier backup local (internal storage).
- <WORK_CODE>0753 - Serviciu de Backup: Logica de versionare si curatare backup-uri vechi.
- <WORK_CODE>0754 - UI Ecran Backup: Lista de fisiere salvate cu detalii.
- <WORK_CODE>0755 - Logica de "Safe Merge": Blocare operatiune daca backup-ul nu a fost creat cu succes.
- <WORK_CODE>0756 - Implementare Merge Engine: Creare contact nou unit.
- <WORK_CODE>0757 - Implementare Merge Engine: Stergere contacte duplicate vechi.
- <WORK_CODE>0758 - Android: Operatiuni atomice de write via ContentProvider (Batch operations).
- <WORK_CODE>0759 - iOS: Operatiuni de write via CNContactStore (CNSaveRequest).
- <WORK_CODE>0760 - Tratare erori la scriere: Rollback logic sau raportare eroare.
- <WORK_CODE>0761 - Implementare ProgressBar pentru operatiunea de merge.
- <WORK_CODE>0762 - Serviciu de Restaurare: Citire backup si rescriere in agenda.
- <WORK_CODE>0763 - UI Dialog Confirmare Critica inainte de Merge.
- <WORK_CODE>0764 - Teste unitare pentru logica de merge campuri (diverse combinatii).
- <WORK_CODE>0765-0900 - Teste pe dispozitive reale pentru scriere, verificari permisiuni de scriere, stabilitate la intreruperi.

## Faza 6: Istoric, Setari si Finalizare Store (Commit-uri 0901-1000)

- <WORK_CODE>0901 - Implementare Baza de date locala (SQLite/Sembast) pentru Istoric.
- <WORK_CODE>0902 - UI Ecran Istoric: Lista cronologica a activitatilor.
- <WORK_CODE>0903 - UI Detalii Istoric: Ce grupuri au fost unite in acea sesiune.
- <WORK_CODE>0904 - UI Ecran Setari: Switch-uri tema (Light/Dark/System).
- <WORK_CODE>0905 - UI Ecran Setari: Optiuni senzitivitate algoritm scanare.
- <WORK_CODE>0906 - UI Ecran Setari: Gestionare contacte protejate (Whitelist).
- <WORK_CODE>0907 - UI Ecran Setari: Buton "Sterge tot istoricul".
- <WORK_CODE>0908 - UI Ecran Setari: Despre aplicatie si versiune.
- <WORK_CODE>0909 - Implementare ecran Privacy Policy in-app.
- <WORK_CODE>0910 - Pregatire assets pentru store (screenshots generator).
- <WORK_CODE>0911 - Configurare Fastlane pentru deploy automat (optional).
- <WORK_CODE>0912 - Audit final de securitate: Verificare leak-uri date personale in loguri.
- <WORK_CODE>0913 - Verificare finala store compliance (Apple & Google).
- <WORK_CODE>0914 - Optimizare dimensiune bundle aplicatie.
- <WORK_CODE>0915-1000 - Bug fixing final, polish UI, pregatire release notes, tagging versiune 1.0.0.

## Ordine de Lucru Recomandata pentru Paralelizare

1. **Echipa A (0001-0100, 0601-0750)**: UI/UX, Tema, Dashboard, Liste.
2. **Echipa B (0201-0400, 0751-0900)**: Servicii Native, Citire/Scriere Contacte, Backup.
3. **Echipa C (0101-0200, 0401-0600)**: Onboarding, Algoritmi de detectie, Scoring.
4. **Echipa D (0901-1000)**: Istoric, Setari, Store compliance, Integrare Finala.

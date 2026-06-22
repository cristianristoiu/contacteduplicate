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

## Reguli pentru agenti paraleli

1. Fiecare commit foloseste formatul real `<WORK_CODE><NUMAR> - <DESCRIERE>`.
2. `<WORK_CODE>` este prefixul specific agentului: `JNI`, `CDX`, `CHT` etc.
3. Numerotarea commiturilor reale continua dupa cel mai mare work code existent in istoria reala a branchului `main`, conform `docs/commit-rules.md`.
4. Taskurile din acest fisier folosesc intervale de planificare: 0001-1000. Acestea sunt ID-uri de plan, nu obliga commitul real sa inceapa de la 0001.
5. Daca in istoria reala exista deja `JNI0017`, urmatorul commit ChatGPT este `CHT0018`, chiar daca taskul de plan este 0001.
6. Agentii pot lucra pe intervale diferite, dar trebuie sa respecte dependentele de cod.
7. Daca un interval depinde de cod care nu este inca gata, agentul foloseste interfete sau mock-uri temporare care vor fi inlocuite ulterior.

## Faza 0: Infrastructura si Tema (Task-uri 0001-0100)

- ~~Task 0001 - Initializare proiect Flutter gol.~~ COMPLETAT: `CHT0018`, `CHT0038-CHT0045`.
- ~~Task 0002 - Configurare .gitignore detaliat pentru Flutter/Dart.~~ COMPLETAT: `CHT0019`.
- ~~Task 0003 - Adaugare dependente de baza in pubspec.yaml (provider, flutter_svg, path_provider).~~ COMPLETAT: `CHT0018`.
- ~~Task 0004 - Configurare linting reguli stricte (analysis_options.yaml).~~ COMPLETAT: `CHT0020`.
- ~~Task 0005 - Creare structura foldere: lib/core, lib/features, lib/shared.~~ COMPLETAT: `CHT0022-CHT0037`.
- ~~Task 0006 - Implementare sistem de culori conform theme-guide.md.~~ COMPLETAT: `CHT0024`.
- ~~Task 0007 - Implementare clasa de text styles conform theme-guide.md.~~ COMPLETAT: `CHT0025`.
- ~~Task 0008 - Configurare ThemeData pentru Light Mode.~~ COMPLETAT: `CHT0026`.
- ~~Task 0009 - Configurare ThemeData pentru Dark Mode.~~ COMPLETAT: `CHT0026`.
- ~~Task 0010 - Implementare ThemeProvider pentru gestionarea temei (Light/Dark/System).~~ COMPLETAT: `CHT0027`.
- ~~Task 0011 - Adaugare asset-uri logo (SVG) in proiect.~~ COMPLETAT: `CHT0021`.
- ~~Task 0012 - Implementare Splash Screen de baza.~~ COMPLETAT: `CHT0035`.
- ~~Task 0013 - Configurare rute principale (go_router sau similar).~~ COMPLETAT: `CHT0030`.
- ~~Task 0014 - Implementare Layout principal (Scaffold custom).~~ COMPLETAT: `CHT0034`.
- ~~Task 0015 - Creare widget-uri de baza pentru butoane (PrimaryButton).~~ COMPLETAT: `CHT0031`.
- ~~Task 0016 - Creare widget-uri de baza pentru butoane (SecondaryButton).~~ COMPLETAT: `CHT0032`.
- ~~Task 0017 - Implementare card-uri UI generice cu design-ul din theme-guide.md.~~ COMPLETAT: `CHT0033`.
- ~~Task 0018 - Configurare localization (suport limba romana si engleza).~~ COMPLETAT: `CHT0028`.
- ~~Task 0019 - Implementare sistem elementar de logging (fara PII).~~ COMPLETAT: `CHT0029`.
- Task 0020-0100 - Rafinament UI componente, unit tests pentru core, configurari CI/CD de baza. BLOCAT PENTRU APROBARE: momentan se implementeaza doar parti brute, fara rafinari, optimizari sau elemente cheie fara confirmare explicita.

## Faza 1: Onboarding si Permisiuni (Task-uri 0101-0200)

- Task 0101 - Creare model pentru paginile de onboarding.
- Task 0102 - Implementare PageView pentru onboarding.
- Task 0103 - UI pentru pagina 1 onboarding: Vizualizare si Siguranta.
- Task 0104 - UI pentru pagina 2 onboarding: Backup si Control.
- Task 0105 - UI pentru pagina 3 onboarding: Permisiuni necesare.
- Task 0106 - Implementare Permission Service (interfata abstracta).
- Task 0107 - Implementare Permission Service pentru Android (permission_handler).
- Task 0108 - Implementare Permission Service pentru iOS (permission_handler).
- Task 0109 - Ecran special pentru explicarea permisiunii de contacte (pre-prompt).
- Task 0110 - Logica de verificare status permisiuni la startup.
- Task 0111 - Tratare caz permisiune refuzata (afisare buton setari sistem).
- Task 0112 - Tratare caz permisiune restrictionata (iOS).
- Task 0113 - UI pentru ecranul "Acces Necesar" cu explicatii clare.
- Task 0114 - Implementare storage local pentru flag-ul "onboarding_completed" (shared_preferences).
- Task 0115 - Teste unitare pentru logica de onboarding.
- Task 0116-0200 - Tranzitii ecrane, animatii discrete, teste integrare permisiuni.

## Faza 2: Citire si Normalizare Contacte (Task-uri 0201-0400)

- Task 0201 - Definire ContactModel (id, name, phones, emails, photo, rawData).
- Task 0202 - Definire PhoneModel (label, value, normalizedValue).
- Task 0203 - Definire EmailModel (label, value, normalizedValue).
- Task 0204 - Implementare Repository abstract pentru contacte.
- Task 0205 - Implementare Native Contact Service (Platform Channels) - Structura.
- Task 0206 - Android: Implementare citire contacte via Kotlin (ContactsContract).
- Task 0207 - Android: Optimizare interogare pentru viteza (projections).
- Task 0208 - iOS: Implementare citire contacte via Swift (CNContactStore).
- Task 0209 - iOS: Mapare campuri native la ContactModel.
- Task 0210 - Implementare serviciu de Normalizare Telefoane (reguli RO).
- Task 0211 - Implementare serviciu de Normalizare Emailuri.
- Task 0212 - Implementare serviciu de Normalizare Nume (diacritice, spatii).
- Task 0213 - Logica de detectare contacte Read-Only (Android account type).
- Task 0214 - Logica de detectare contacte Read-Only (iOS container/source).
- Task 0215 - Implementare incarcare contacte in batch-uri pentru a evita blocarea UI.
- Task 0216 - Creare Background Worker pentru procesarea contactelor.
- Task 0217 - Implementare cache local pentru contacte (pentru viteza scanari ulterioare).
- Task 0218 - Teste unitare pentru normalizare (variante de numere RO).
- Task 0219 - Teste unitare pentru normalizare nume complexe.
- Task 0220-0400 - Optimizari memorie, tratare cazuri limita (contacte fara nume, mii de numere), unit tests platform specific.

## Faza 3: Algoritmi Detectare Duplicate si Scoring (Task-uri 0401-0600)

- Task 0401 - Definire DuplicateGroup model (list contacte, score, reasons).
- Task 0402 - Algoritm detectare duplicate dupa Telefon Identic (scor 100).
- Task 0403 - Algoritm detectare duplicate dupa Email Identic (scor 100).
- Task 0404 - Algoritm detectare duplicate dupa Nume Exact (scor 90).
- Task 0405 - Algoritm detectare duplicate dupa Nume Similar (Levenshtein distance).
- Task 0406 - Implementare sistem de ponderi pentru scoring combinat.
- Task 0407 - Logica de marcare "Sigur" vs "Probabil" conform proiect-plan.md.
- Task 0408 - Implementare sistem de "Motive" pentru potrivire (ex: "Acelasi numar de telefon").
- Task 0409 - Optimizare algoritm prin indexare prealabila (Map-uri de cautare rapida).
- Task 0410 - Tratare cazuri de "False Positives" comune.
- Task 0411 - Logica de grupare transitiva (A=B si B=C => A,B,C sunt duplicate).
- Task 0412 - Implementare filtru pentru ignorare contacte protejate.
- Task 0413 - Serviciu de analiza statistica a duplicatelor (total grupuri, potentiale economii).
- Task 0414 - Teste unitare pentru algoritmul de scoring (matrice de teste).
- Task 0415-0600 - Rafinare euristici, teste de performanta pe seturi mari de date, eliminare bucle infinite in grupari.

## Faza 4: Interfata Dashboard si Liste Duplicate (Task-uri 0601-0750)

- Task 0601 - UI Dashboard: Cerc de progres central (animat).
- Task 0602 - UI Dashboard: Statistici rapide (Total contacte, Duplicate).
- Task 0603 - UI Dashboard: Buton principal "Incepe Scanarea".
- Task 0604 - UI Dashboard: Carduri pentru starea ultimei scanari.
- Task 0605 - UI Lista Duplicate: Categorisire pe tab-uri (Sigur, Probabil, Toate).
- Task 0606 - UI Card Duplicat: Afisare contacte in grup, scor si badge status.
- Task 0607 - Implementare Search si Filtrare in lista de duplicate.
- Task 0608 - Implementare Selectie Multipla pentru grupuri.
- Task 0609 - UI Ecran Detalii Grup: Comparatie coloana langa coloana a contactelor.
- Task 0610 - UI Ecran Detalii Grup: Selectie campuri de pastrat (radio buttons custom).
- Task 0611 - UI Ecran Detalii Grup: Identificare si marcare conflicte vizuale.
- Task 0612 - UI Preview Merge: Rezumatul schimbarilor (ce se sterge, ce se updateaza).
- Task 0613 - Implementare tranzitii intre Dashboard si Liste.
- Task 0614 - UI Empty States pentru dashboard si liste.
- Task 0615-0750 - Rafinament UX, feedback vizual la tap, skeleton loaders, teste widget.

## Faza 5: Logica de Merge si Backup (Task-uri 0751-0900)

- Task 0751 - Definire BackupModel (vCard format sau JSON proprietar).
- Task 0752 - Serviciu de Backup: Generare fisier backup local (internal storage).
- Task 0753 - Serviciu de Backup: Logica de versionare si curatare backup-uri vechi.
- Task 0754 - UI Ecran Backup: Lista de fisiere salvate cu detalii.
- Task 0755 - Logica de "Safe Merge": Blocare operatiune daca backup-ul nu a fost creat cu succes.
- Task 0756 - Implementare Merge Engine: Creare contact nou unit.
- Task 0757 - Implementare Merge Engine: Stergere contacte duplicate vechi.
- Task 0758 - Android: Operatiuni atomice de write via ContentProvider (Batch operations).
- Task 0759 - iOS: Operatiuni de write via CNContactStore (CNSaveRequest).
- Task 0760 - Tratare erori la scriere: Rollback logic sau raportare eroare.
- Task 0761 - Implementare ProgressBar pentru operatiunea de merge.
- Task 0762 - Serviciu de Restaurare: Citire backup si rescriere in agenda.
- Task 0763 - UI Dialog Confirmare Critica inainte de Merge.
- Task 0764 - Teste unitare pentru logica de merge campuri (diverse combinatii).
- Task 0765-0900 - Teste pe dispozitive reale pentru scriere, verificari permisiuni de scriere, stabilitate la intreruperi.

## Faza 6: Istoric, Setari si Finalizare Store (Task-uri 0901-1000)

- Task 0901 - Implementare Baza de date locala (SQLite/Sembast) pentru Istoric.
- Task 0902 - UI Ecran Istoric: Lista cronologica a activitatilor.
- Task 0903 - UI Detalii Istoric: Ce grupuri au fost unite in acea sesiune.
- Task 0904 - UI Ecran Setari: Switch-uri tema (Light/Dark/System).
- Task 0905 - UI Ecran Setari: Optiuni senzitivitate algoritm scanare.
- Task 0906 - UI Ecran Setari: Gestionare contacte protejate (Whitelist).
- Task 0907 - UI Ecran Setari: Buton "Sterge tot istoricul".
- Task 0908 - UI Ecran Setari: Despre aplicatie si versiune.
- Task 0909 - Implementare ecran Privacy Policy in-app.
- Task 0910 - Pregatire assets pentru store (screenshots generator).
- Task 0911 - Configurare Fastlane pentru deploy automat (optional).
- Task 0912 - Audit final de securitate: Verificare leak-uri date personale in loguri.
- Task 0913 - Verificare finala store compliance (Apple & Google).
- Task 0914 - Optimizare dimensiune bundle aplicatie.
- Task 0915-1000 - Bug fixing final, polish UI, pregatire release notes, tagging versiune 1.0.0.

## Ordine de lucru recomandata pentru paralelizare

1. Echipa A (Task-uri 0001-0100, 0601-0750): UI/UX, Tema, Dashboard, Liste.
2. Echipa B (Task-uri 0201-0400, 0751-0900): Servicii Native, Citire/Scriere Contacte, Backup.
3. Echipa C (Task-uri 0101-0200, 0401-0600): Onboarding, Algoritmi de detectie, Scoring.
4. Echipa D (Task-uri 0901-1000): Istoric, Setari, Store compliance, Integrare Finala.

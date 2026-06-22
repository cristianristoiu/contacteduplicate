# Contacte Duplicate - checklist Google Play si Apple App Store

## Scop

Acest document defineste regulile de publicare pentru Play Store si App Store, astfel incat aplicatia sa ceara doar permisiunile necesare, sa fie transparenta si sa nu creeze blocaje la review.

## Principiu de baza

Aplicatia acceseaza contactele exclusiv pentru functionalitatea principala:

- scanare contacte duplicate
- grupare duplicate
- preview inainte de merge
- backup local
- unire contacte dupa confirmare

Datele contactelor nu sunt incarcate pe server.

## Permisiuni Android

Permisiuni admise pentru MVP:

- READ_CONTACTS: necesara pentru scanare duplicate.
- WRITE_CONTACTS: necesara doar pentru unirea/modificarea contactelor.

Reguli:

- READ_CONTACTS se cere dupa ecranul de explicatie.
- WRITE_CONTACTS se cere doar cand utilizatorul confirma prima actiune de modificare.
- Nu se cere acces la locatie, camera, microfon, SMS, call log sau fisiere externe daca nu exista functionalitate directa.
- Daca utilizatorul refuza permisiunea, aplicatia ramane functionala partial si explica limitarea.

Text recomandat inainte de READ_CONTACTS:

`Aplicatia are nevoie de acces la contacte pentru a gasi duplicatele. Datele raman pe dispozitiv si nu sunt incarcate in cloud.`

Text recomandat inainte de WRITE_CONTACTS:

`Pentru a uni contactele selectate, aplicatia are nevoie de permisiunea de a modifica agenda. Nu modificam nimic fara confirmarea ta si cream backup inainte.`

## Permisiuni iOS

Cheie necesara in Info.plist:

- NSContactsUsageDescription

Text recomandat:

`Aplicatia foloseste contactele pentru a gasi si uni duplicatele direct pe dispozitiv. Datele nu sunt incarcate in cloud.`

Reguli:

- Nu se cere acces la alte zone ale telefonului fara functionalitate directa.
- Nu se folosesc API-uri private.
- Nu se promite control complet asupra conturilor Google/iCloud daca iOS nu expune aceste informatii.

## Privacy Policy

Este obligatoriu un URL public, activ, non-PDF.

Politica de confidentialitate trebuie sa spuna clar:

- ce date sunt accesate: contacte locale si sincronizate prin aplicatia nativa de contacte
- de ce sunt accesate: detectare duplicate, backup, merge
- unde sunt procesate: local pe dispozitiv
- daca se colecteaza date in cloud: nu in MVP
- daca se vand date: nu
- daca exista analytics: nu in MVP sau explicit daca se adauga ulterior
- cum se sterge istoricul local
- cum se gestioneaza backup-urile locale

## Google Play Data Safety

Pentru MVP, daca nu se trimite nimic pe server:

- colectare date: nu, pentru contactele procesate local
- partajare date: nu
- date procesate pe dispozitiv: da
- tip date sensibile accesate local: contacts / phonebook
- scop: app functionality

Atentie: declaratia trebuie actualizata daca se adauga analytics, crash reporting, reclame, conturi, cloud sync sau servicii externe.

## Apple App Privacy

Pentru MVP, daca nu se trimite nimic pe server:

- Data Not Collected poate fi corect doar daca nu se colecteaza/transmite date in afara dispozitivului.
- Accesul local la contacte trebuie explicat in permisiune si privacy policy.
- Daca se adauga analytics sau crash reporting, App Privacy trebuie actualizat.

## App metadata

Descrierea din store trebuie sa fie clara:

- `Gaseste contacte duplicate direct pe telefon.`
- `Previzualizeaza modificarile inainte de unire.`
- `Creeaza backup inainte de modificare.`
- `Datele raman pe dispozitiv.`

Nu se folosesc formulari precum:

- `garantat fara risc`
- `sterge automat toate duplicatele`
- `curata orice cont Google/iCloud perfect`
- `100% detectie corecta`

## Capturi store

Capturile trebuie sa arate:

- onboarding permisiuni
- dashboard
- lista duplicate
- preview merge
- backup
- succes final

Capturile nu trebuie sa contina date reale: numere reale, emailuri reale sau nume reale de clienti.

## Review risks

Riscuri majore:

1. Cerere permisiuni fara explicatie clara.
2. WRITE_CONTACTS cerut prea devreme.
3. Lipsa privacy policy.
4. Declaratii gresite in Data Safety sau App Privacy.
5. Upload contacte in cloud fara disclosure.
6. Loguri sau crash reports cu date personale.
7. Promisiuni imposibile despre iCloud/Google.
8. Functie de stergere fara backup si confirmare.

## Teste inainte de publicare

- Permisiune acceptata.
- Permisiune refuzata.
- Permisiune revocata din setarile telefonului.
- Contacte read-only.
- Contacte duplicate sigure.
- Contacte similare nesigure.
- Backup reusit.
- Backup esuat.
- Merge reusit.
- Merge partial cu erori.
- Restaurare din backup.

## Go / No-Go

Aplicatia poate fi trimisa la review doar daca:

- privacy policy este publica si accesibila
- ecranul de permisiuni este clar
- Data Safety si App Privacy reflecta comportamentul real
- nu exista upload contacte
- nu exista loguri cu date personale
- backup-ul ruleaza inainte de merge
- utilizatorul confirma explicit modificarile

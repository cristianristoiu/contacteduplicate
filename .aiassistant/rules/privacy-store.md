---
apply: always
---

# Reguli privacy si store compliance

## Principiu de baza

Aplicatia proceseaza contactele local pe dispozitiv. In MVP nu se trimit contacte, numere de telefon, emailuri sau istoricul scanarilor catre servere externe.

## Date personale

- Nu loga PII.
- Nu salva PII in fisiere de debug.
- Nu include PII in erori, analytics, crash reports sau telemetrie.
- Nu folosi contacte reale in teste, mock-uri, preview-uri sau screenshot-uri.
- Nu adauga servicii externe care pot colecta date fara analiza si aprobare.

## Permisiuni Android

Permisiuni admise pentru MVP:

- `READ_CONTACTS` pentru scanare.
- `WRITE_CONTACTS` doar pentru unire/modificare contacte dupa confirmare.

Reguli:

- Explica utilizatorului de ce este ceruta permisiunea inainte de cererea sistemului.
- Nu cere `WRITE_CONTACTS` la pornirea aplicatiei.
- Daca permisiunea este refuzata, aplicatia explica limitarea si nu crapa.
- Nu cere locatie, camera, microfon, SMS, call log sau fisiere externe fara functionalitate directa.

## Permisiuni iOS

- `NSContactsUsageDescription` trebuie sa explice clar scopul accesului.
- Nu se folosesc API-uri private.
- Nu se promit functii imposibile pe iOS pentru conturi Google/iCloud sau contacte read-only.

## Merge contacte

- Nicio modificare nu se executa fara backup local.
- Nicio modificare nu se executa fara confirmare explicita.
- Preview-ul trebuie sa arate clar ce campuri se pastreaza si ce conflicte exista.
- Contactele read-only se marcheaza ca limitare, nu se modifica fortat.

## Store listing

Nu folosi formulari de marketing precum:

- `100% detectie corecta`
- `garantat fara risc`
- `sterge automat toate duplicatele`
- `curata orice cont Google/iCloud perfect`

Foloseste formulari clare:

- `Gaseste contacte duplicate direct pe telefon.`
- `Previzualizeaza modificarile inainte de unire.`
- `Creeaza backup inainte de modificare.`
- `Datele raman pe dispozitiv.`

## Go / No-Go

Nu pregati publicarea daca:

- privacy policy lipseste sau nu reflecta comportamentul real;
- Data Safety sau App Privacy nu sunt actualizate;
- exista upload contacte;
- exista loguri cu PII;
- merge-ul poate rula fara backup sau fara confirmare.

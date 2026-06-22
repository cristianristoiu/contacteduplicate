# Contacte Duplicate - plan proiect

## Viziune

Contacte Duplicate este o aplicatie mobila Android si iOS pentru gasirea, verificarea si unirea contactelor duplicate din agenda telefonului si din conturile sincronizate in aplicatia nativa de contacte.

Aplicatia trebuie sa fie simpla, sigura si transparenta. Datele raman pe dispozitiv. Nu exista upload in cloud in MVP.

## Obiectiv MVP

MVP-ul trebuie sa permita:

1. Cerere transparenta de permisiune contacte.
2. Scanare contacte locale si sincronizate, in limitele platformei.
3. Detectare duplicate dupa telefon, email, nume si combinatii relevante.
4. Scor de incredere pentru fiecare grup duplicat.
5. Previzualizare clara inainte de unire.
6. Backup local inainte de orice modificare.
7. Merge manual sau semi-automat doar dupa confirmare.
8. Istoric local al operatiunilor.
9. Restaurare/undo unde platforma permite.
10. Pregatire corecta pentru Google Play si Apple App Store.

## Diferentiator principal

Aplicatia nu trebuie sa fie doar un cleaner automat. Diferentiatorul este controlul:

- utilizatorul vede ce se modifica
- utilizatorul alege campurile pastrate
- aplicatia creeaza backup inainte
- contactele nu pleaca de pe dispozitiv

## Platforme

- Android
- iOS

Framework UI recomandat:

- Flutter 3.x

Cod nativ necesar:

- Android: Kotlin pentru ContactsContract
- iOS: Swift pentru CNContactStore

## Module principale

### 1. Onboarding si permisiuni

Rol:

- explica accesul la contacte
- cere permisiunea de citire
- cere permisiunea de scriere doar cand este necesara

### 2. Dashboard

Rol:

- arata total contacte
- arata duplicate gasite
- arata ultima scanare
- permite pornirea scanarii

### 3. Scanare contacte

Rol:

- citeste contactele disponibile
- normalizeaza datele
- creeaza indexuri
- identifica grupuri candidate

### 4. Duplicate groups

Rol:

- afiseaza grupurile de duplicate
- permite filtrare
- afiseaza scor si motiv potrivire

### 5. Merge detail

Rol:

- permite alegerea contactului principal
- permite alegerea campurilor pastrate
- marcheaza conflictele

### 6. Merge preview

Rol:

- afiseaza rezumatul final
- cere confirmare explicita
- blocheaza merge-ul daca backup-ul lipseste

### 7. Backup

Rol:

- export local inainte de merge
- lista backup-uri
- restaurare unde este posibil

### 8. Istoric

Rol:

- arata scanari si merge-uri
- arata rezultate si erori
- permite revenire prin backup

### 9. Setari

Rol:

- tema Light/Dark/Follow system
- reguli scanare
- contacte protejate
- privacy
- stergere istoric local

## Reguli detectare duplicate

Detectare dupa:

- telefon identic
- telefon normalizat
- email identic
- nume exact
- nume similar
- nume + telefon
- nume + email
- nume + companie

Normalizare telefon:

- elimina spatii, paranteze, linii, puncte
- trateaza +40, 0040 si 0 pentru Romania
- pastreaza valoarea originala pentru afisare

Normalizare email:

- trim
- lowercase

Normalizare nume:

- trim
- lowercase
- spatii multiple eliminate
- optional fara diacritice
- inversiuni evidente nume/prenume

## Scor de incredere

| Scor | Eticheta | Actiune |
| --- | --- | --- |
| 95-100 | Sigur | poate fi selectat automat, dar necesita confirmare |
| 80-94 | Probabil | verificare recomandata |
| 60-79 | Verifica manual | nu se selecteaza automat |
| sub 60 | Ignorat implicit | risc mare |

## Reguli merge

- Nu se modifica nimic fara backup.
- Nu se modifica nimic fara confirmare.
- Se pastreaza toate telefoanele unice.
- Se pastreaza toate emailurile unice.
- Campurile conflictuale necesita alegere.
- Contactele read-only nu sunt modificate fortat.
- Rezultatul se salveaza in istoric.

## Tema si branding

Tema este documentata in:

- `docs/theme/theme-guide.md`

Asset-uri relevante:

- `docs/theme/design/logo.svg`
- `docs/theme/design/preview-logo.png`
- `docs/theme/design/preview-zone.png`
- `docs/theme/design/preview-zone2.png`
- `docs/theme/design/mockup-overview.svg`
- `docs/theme/design/dashboard.svg`

Regula obligatorie:

- tema este globala
- nu exista ecran dark si ecran light amestecate artificial
- utilizatorul alege Light, Dark sau Follow system

## Store compliance

Aplicatia va fi publicata in Google Play si Apple App Store. Planul de publicare este documentat in:

- `docs/store-release-checklist.md`

Reguli principale:

- permisiuni cerute doar cand sunt necesare
- explicatie in-app inainte de permisiune
- privacy policy publica
- fara upload contacte
- declaratii corecte in Data Safety si App Privacy

## Plan implementare

Planul de executie este documentat in:

- `docs/implementation-plan.md`

## In afara MVP

- login
- cloud sync
- reclame
- abonamente
- analytics avansat
- sincronizare server
- AI pentru contacte
- auto-merge agresiv

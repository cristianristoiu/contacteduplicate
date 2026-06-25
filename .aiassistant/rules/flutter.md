---
apply: always
---

# Reguli Flutter si Dart

## Arhitectura

- Respecta structura existenta a folderelor.
- Nu introduce un nou sistem de state management fara aprobare explicita.
- Nu introduce un nou router sau framework de navigare fara aprobare explicita.
- Nu pune logica de business complexa direct in widget-uri.
- Serviciile, modelele si regulile de detectare duplicate trebuie separate de UI.
- Codul critic trebuie sa poata fi testat fara UI.

## UI

- Respecta `docs/theme/theme-guide.md`.
- Tema este globala: Light, Dark sau Follow system.
- Nu crea ecrane care amesteca artificial light si dark mode.
- Foloseste componente existente inainte sa creezi componente noi.
- Nu duplica stiluri daca exista deja tokenuri, constante sau componente comune.
- Textele UI trebuie sa fie scurte, clare si fara promisiuni absolute.
- Actiunile critice trebuie sa aiba confirmare vizibila.

## Contacte si date locale

- Detectarea duplicatelor trebuie sa pastreze valorile originale pentru afisare.
- Normalizarea se foloseste pentru comparatie, nu pentru pierderea datelor originale.
- Un merge nu poate rula fara backup local.
- Un merge nu poate rula fara confirmarea utilizatorului.
- Contactele read-only trebuie tratate ca limitare de platforma, nu fortate.

## Android

- Foloseste doar permisiuni justificate de functionalitate.
- `READ_CONTACTS` este pentru scanare.
- `WRITE_CONTACTS` este pentru modificari dupa confirmare.
- Nu cere locatie, camera, microfon, SMS, call log sau fisiere externe fara cerinta explicita.

## iOS

- Foloseste `CNContactStore` pentru contacte.
- Respecta limitarile iOS privind sursele sincronizate si contactele read-only.
- Nu folosi API-uri private.
- Textul de permisiune trebuie sa explice clar ca datele raman pe dispozitiv.

## Testare

- Pentru algoritmi, normalizare, scor si merge preview, prefera teste deterministe.
- Testele nu trebuie sa contina contacte reale.
- Testele trebuie sa verifice cazuri sigure, probabile, manuale si ignorate.
- Nu crea teste doar ca sa existe; testeaza comportament real.

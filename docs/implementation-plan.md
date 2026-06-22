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

## Faza 0 - pregatire proiect

Taskuri:

- Initializare proiect Flutter.
- Configurare Android si iOS.
- Configurare linting si format.
- Configurare structura principala a proiectului.
- Implementare tema globala Light, Dark si Follow system.
- Adaugare logo si asset-uri.

Acceptare:

- Aplicatia porneste pe Android si iOS.
- Tema globala functioneaza pe toate ecranele.
- Nu exista ecrane cu tema hardcodata.

## Faza 1 - onboarding si permisiuni

Taskuri:

- Ecran onboarding.
- Ecran explicatie acces contacte.
- Cerere acces citire contacte.
- Cerere acces scriere contacte doar inainte de modificare.
- Tratare permisiune acceptata, refuzata si restrictionata.

Acceptare:

- Utilizatorul vede clar de ce este necesar accesul la contacte.
- Aplicatia nu crapa daca permisiunea este refuzata.
- Exista instructiuni pentru deschiderea setarilor sistemului.

## Faza 2 - citire contacte

Taskuri:

- Implementare serviciu Android pentru citirea contactelor.
- Implementare serviciu iOS pentru citirea contactelor.
- Mapare date native in model intern.
- Procesare pe background.
- Detectare contacte read-only unde este posibil.

Acceptare:

- Aplicatia poate citi contacte reale pe Android.
- Aplicatia poate citi contacte reale pe iOS.
- UI-ul nu se blocheaza la agende mari.

## Faza 3 - normalizare si indexare

Taskuri:

- Normalizare telefon.
- Normalizare email.
- Normalizare nume.
- Indexuri dupa telefon, email, nume si companie.
- Suport pentru variante Romania: 07, +407 si 00407.

Acceptare:

- Variantele aceluiasi numar sunt recunoscute ca acelasi numar.
- Emailurile sunt comparate lowercase si trim.
- Numele sunt comparate fara spatii multiple.

## Faza 4 - detectare duplicate

Taskuri:

- Generare grupuri candidate.
- Calcul scor incredere.
- Motive de potrivire.
- Eliminare false positive evidente.
- Marcare grupuri nesigure.

Acceptare:

- Telefon sau email identic produce scor 95+.
- Numele similare fara dovezi suplimentare nu se unesc automat.
- Grupurile sub 95 cer verificare manuala.

## Faza 5 - UI duplicate si merge preview

Taskuri:

- Lista grupuri duplicate.
- Filtre pe telefon, email, nume si nesigure.
- Ecran detalii grup.
- Alegere contact principal.
- Alegere campuri de pastrat.
- Previzualizare inainte de merge.

Acceptare:

- Utilizatorul vede ce se pastreaza si ce se elimina.
- Campurile conflictuale necesita alegere.
- Nu exista merge fara preview.

## Faza 6 - backup local

Taskuri:

- Export backup inainte de merge.
- Salvare metadata backup.
- Lista backup-uri.
- Export backup manual.
- Tratare erori de scriere sau lipsa spatiu.

Acceptare:

- Merge-ul real este blocat daca backup-ul esueaza.
- Backup-ul este accesibil din ecranul Backup.
- Utilizatorul vede data, ora si numarul de contacte salvate.

## Faza 7 - merge controlat

Taskuri:

- Aplicare plan de merge.
- Pastrare telefoane unice.
- Pastrare emailuri unice.
- Pastrare campuri fara conflict.
- Sarire contacte read-only.
- Salvare rezultat in istoric.

Acceptare:

- Merge-ul nu sterge informatii fara confirmare.
- Contactele read-only sunt raportate.
- Operatia produce istoric clar.

## Faza 8 - istoric si restaurare

Taskuri:

- Istoric scanari.
- Istoric merge-uri.
- Detalii rezultat.
- Undo unde platforma permite.
- Restaurare din backup daca undo direct nu este posibil.

Acceptare:

- Utilizatorul poate vedea ce s-a intamplat.
- Exista cale de revenire prin backup.

## Faza 9 - store compliance

Taskuri:

- Ecran privacy in aplicatie.
- Link politica de confidentialitate.
- Texte finale pentru permisiuni.
- Completare Data Safety pentru Google Play.
- Completare App Privacy pentru Apple App Store.
- Eliminare loguri sensibile.

Acceptare:

- Permisiunile sunt explicate si justificate.
- Nu exista SDK-uri inutile care colecteaza date.
- Store listing-ul nu promite functionalitati imposibile.

## Faza 10 - testare si publicare

Testare:

- Android real device.
- iPhone real device.
- Emulatoare si simulatoare.
- Contacte fara nume.
- Contacte fara telefon.
- Contacte cu mai multe telefoane.
- Contacte read-only.
- Permisiune refuzata.
- Permisiune revocata dupa instalare.
- Agenda mare cu minim 5000 contacte.

Publicare:

- Build Android semnat si validat.
- Build iOS validat.
- Privacy Policy URL activ.
- Capturi si descriere corecte.
- TestFlight inainte de App Store review.
- Internal testing in Google Play inainte de productie.

## Ordine MVP

1. Proiect Flutter si tema.
2. Onboarding si permisiuni.
3. Citire contacte Android.
4. Citire contacte iOS.
5. Scanare si normalizare.
6. Grupare duplicate.
7. Lista duplicate.
8. Preview merge.
9. Backup.
10. Merge controlat.
11. Istoric.
12. Store compliance.

## In afara MVP

- Login.
- Cloud sync.
- Reclame.
- Abonamente.
- Analytics avansat.
- Auto-merge agresiv.
- Integrare server.

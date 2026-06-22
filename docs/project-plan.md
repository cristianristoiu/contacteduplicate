Creeaza o aplicatie mobila cross-platform pentru Android si iOS, numita provizoriu "Contacte Duplicate", care gaseste, analizeaza si uneste contactele duplicate din aplicatia nativa de contacte si din conturile sincronizate in contacte, acolo unde Android si iOS permit accesul prin API-urile native.

Aplicatia trebuie sa fie construita profesional, curat, scalabil si sigur. Datele contactelor nu trebuie trimise in cloud. Toata scanarea, analiza si unirea contactelor se fac local pe dispozitiv.

STACK RECOMANDAT

Foloseste Flutter 3.x + Dart pentru interfata cross-platform.

Pentru acces avansat la contacte, foloseste cod nativ prin platform channels:
- Android: Kotlin + Contacts Provider / ContactsContract
- iOS: Swift + Contacts framework / CNContactStore

Nu te baza doar pe un plugin generic daca acesta nu permite:
- citire completa contacte
- detectare conturi/surse unde este posibil
- scriere/modificare contacte
- backup/export
- tratare contacte read-only
- tratare erori native

ARHITECTURA

Foloseste arhitectura curata:
- presentation
- domain
- data
- platform/native

Separare clara:
- UI
- state management
- servicii contacte
- algoritm duplicate
- servicii backup
- servicii merge
- servicii permisiuni
- istoric actiuni

Codul trebuie sa fie modular, testabil si usor de extins.

REGULA CRITICA DE DESIGN

Aplicatia trebuie sa foloseasca o tema vizuala unitara in toate ecranele.

NU folosi teme diferite de la un ecran la altul.

Aplicatia are doua moduri globale:
- Light mode
- Dark mode

Utilizatorul poate alege tema din Settings:
- Light
- Dark
- Follow system

Cand aplicatia este in Light mode:
- toate ecranele folosesc tema light
- fundal alb / alb-albastrui
- carduri albe
- text inchis
- accente albastru-electric si violet
- borduri subtile
- umbre discrete

Cand aplicatia este in Dark mode:
- toate ecranele folosesc tema dark
- fundal navy / negru
- carduri inchise
- text alb / gri deschis
- accente albastru-electric si violet
- contrast clar
- borduri discrete

Este interzis:
- Home dark si restul light
- Settings light si restul dark
- ecrane cu fundaluri inconsistente
- culori hardcodate direct in widgeturi
- componente care ignora tema globala

Toate ecranele trebuie sa foloseasca tema globala activa.

Defineste design tokens:
- background
- surface
- card
- primary
- secondary
- textPrimary
- textSecondary
- textMuted
- border
- divider
- success
- warning
- error
- iconPrimary
- iconSecondary

Pastreaza directia vizuala din mockup-ul aprobat:
- interfata moderna
- carduri rotunjite
- butoane mari
- iconuri simple
- layout aerisit
- progress ring pe dashboard
- accent albastru/violet
- avataruri cu initiale
- ecrane curate si usor de inteles

OBIECTIV PRINCIPAL

Aplicatia trebuie sa:
1. ceara permisiunea de acces la contacte
2. citeasca contactele disponibile
3. identifice duplicatele
4. grupeze duplicatele pe criterii clare
5. afiseze scorul de incredere
6. permita previzualizare inainte de unire
7. creeze backup local inainte de modificare
8. permita unirea contactelor doar dupa confirmare
9. pastreze istoric local al operatiunilor
10. permita undo/restaurare unde platforma permite

CONFIDENTIALITATE

Aplicatia trebuie sa afiseze clar:
"Datele raman pe dispozitiv."

Nu implementa:
- upload contacte in cloud
- login obligatoriu
- reclame
- analytics care colecteaza contacte
- trimitere contacte catre server
- auto-merge agresiv fara confirmare
- stergere definitiva fara backup

PERMISIUNI

Android:
- cere READ_CONTACTS pentru scanare
- cere WRITE_CONTACTS doar cand utilizatorul vrea sa modifice/unifice contacte
- trateaza permisiunea refuzata
- trateaza permisiunea refuzata definitiv
- deschide setarile aplicatiei cand este necesar
- foloseste ContactsContract pentru citire si scriere
- nu presupune ca toate contactele pot fi editate
- trateaza contacte read-only
- trateaza contacte din work profile sau conturi restrictionate ca potential indisponibile

iOS:
- foloseste CNContactStore
- cere autorizare nativa pentru contacte
- ruleaza citirea si procesarea pe background thread
- nu bloca UI-ul in timpul scanarii
- trateaza acces limitat/refuzat
- trateaza contacte read-only sau unificate de sistem
- nu promite separarea perfecta pe surse Google/iCloud daca iOS nu expune complet informatia
- pentru campuri sensibile sau restrictionate, afiseaza doar ce este disponibil legal prin API

ECRANE NECESARE

1. Onboarding / Permission Screen

Tema:
- foloseste tema globala activa

Continut:
- logo aplicatie
- titlu: "Curata contactele duplicate"
- descriere scurta: "Gaseste si uneste contactele duplicate direct pe telefon."
- mesaj confidentialitate: "Datele raman pe dispozitiv. Nu incarcam contactele in cloud."
- buton principal: "Permite accesul la contacte"
- link secundar: "Afla cum functioneaza"

Daca permisiunea este refuzata:
- afiseaza mesaj clar
- buton: "Deschide setarile"

2. Home Dashboard

Tema:
- foloseste tema globala activa

Continut:
- numar total contacte
- numar duplicate gasite
- progress ring / scan ring
- status ultima scanare
- surse detectate, unde platforma permite:
    - Google
    - iCloud
    - Telefon local
    - Outlook
    - alte conturi
- daca sursele nu pot fi separate:
    - afiseaza "Contacte sincronizate"
- butoane:
    - "Scaneaza contacte"
    - "Vezi duplicate"
    - "Backup contacte"

Bottom navigation:
- Acasa
- Duplicate
- Backup
- Setari

3. Duplicate Groups

Tema:
- foloseste tema globala activa

Continut:
- lista grupurilor de duplicate
- filtre:
    - Toate
    - Telefon
    - Email
    - Nume exact
    - Nume similar
    - Companie
    - Nesigure
- fiecare card afiseaza:
    - avatar / initiala
    - nume principal propus
    - numar contacte in grup
    - motiv potrivire
    - scor incredere
    - badge: Sigur / Probabil / Verifica manual
- selectie multipla pentru grupuri sigure
- buton: "Uneste selectate"

Regula:
- grupurile cu scor sub 95 nu pot fi unite automat
- grupurile nesigure necesita verificare manuala

4. Duplicate Detail / Merge Contact Detail

Tema:
- foloseste tema globala activa

Continut:
- toate contactele din grup
- sursa fiecarui contact, daca este disponibila
- utilizatorul poate alege contactul principal
- afiseaza campurile comparativ:
    - nume
    - prenume
    - telefon
    - email
    - adresa
    - companie
    - functie
    - data nasterii
    - website
    - notite, doar daca sunt disponibile
    - poza contact
- pentru fiecare camp conflictual, utilizatorul poate alege valoarea pastrata
- evidentiaza campurile duplicate
- evidentiaza campurile care vor fi eliminate
- buton: "Previzualizeaza unirea"

5. Scan Settings

Tema:
- foloseste tema globala activa

Continut:
- surse de scanare:
    - toate contactele
    - telefon local
    - conturi sincronizate, unde pot fi detectate
- criterii de potrivire:
    - telefon identic
    - telefon normalizat
    - email identic
    - nume exact
    - nume similar
    - nume + companie
    - nume + email
    - nume + telefon
- optiuni:
    - ignora spatiile
    - ignora diacriticele
    - ignora majuscule/minuscule
    - normalizeaza numere Romania
    - normalizeaza prefixe internationale
    - exclude contacte favorite
    - exclude contacte fara nume
    - exclude contacte fara telefon si fara email
    - prima scanare doar audit
- buton: "Porneste scanarea"

6. Merge Preview

Tema:
- foloseste tema globala activa

Continut:
- rezumat clar:
    - cate contacte vor fi unite
    - care este contactul principal
    - ce informatii vor fi pastrate
    - ce informatii vor fi eliminate
    - ce conflicte exista
- afiseaza avertizare pentru scor mediu/scazut
- checkbox: "Confirm ca am verificat modificarile"
- buton principal: "Confirma unirea"
- buton secundar: "Inapoi"

Regula:
- fara confirmare explicita, nu modifica nimic

7. Success Screen

Tema:
- foloseste tema globala activa

Continut:
- mesaj: "Contactele au fost unite"
- statistici:
    - duplicate unite
    - contacte actualizate
    - contacte ramase
    - grupuri ignorate
- butoane:
    - "Vezi toate duplicatele"
    - "Deschide istoricul"
    - "Export raport"

8. Backup Screen

Tema:
- foloseste tema globala activa

Functionalitati:
- backup local inainte de merge
- export VCF
- lista backup-uri create
- data si ora backup
- numar contacte salvate
- buton: "Restaureaza"
- buton: "Exporta fisier VCF"

Regula:
- inainte de orice modificare reala, creeaza backup automat
- backup-ul trebuie sa fie disponibil local pentru restaurare/export

9. History / Undo Screen

Tema:
- foloseste tema globala activa

Continut:
- lista actiuni:
    - scanare
    - unire contacte
    - restaurare
    - export backup
- pentru fiecare actiune:
    - data
    - numar contacte afectate
    - rezultat
- buton pentru undo, unde este posibil
- daca undo nu este posibil:
    - afiseaza optiunea de restaurare din backup

10. Settings

Tema:
- foloseste tema globala activa

Sectiuni:
- Tema aplicatie:
    - Light
    - Dark
    - Follow system
- Confidentialitate:
    - datele raman local
    - stergere istoric local
- Scanare:
    - reguli duplicate
    - surse scanare
- Backup:
    - backup automat inainte de merge
    - export VCF
- Contacte protejate:
    - lista contacte excluse de la merge
- Despre:
    - versiune aplicatie
    - politica de confidentialitate
    - termenii aplicatiei

ALGORITM DETECTARE DUPLICATE

1. Incarca toate contactele permise.
2. Extrage campurile relevante.
3. Normalizeaza campurile.
4. Creeaza indexuri:
    - dupa telefon normalizat
    - dupa email normalizat
    - dupa nume normalizat
    - dupa nume + companie
5. Genereaza grupuri candidate.
6. Calculeaza scor de potrivire.
7. Elimina false positive evidente.
8. Sorteaza grupurile dupa scor.
9. Afiseaza grupurile utilizatorului.
10. Creeaza plan de merge doar dupa selectie.
11. Creeaza backup.
12. Executa modificarile.
13. Salveaza rezultat in istoric.

NORMALIZARE TELEFON

Pentru fiecare numar:
- elimina spatii
- elimina paranteze
- elimina linii
- elimina puncte
- elimina slash-uri
- pastreaza plusul initial daca exista
- normalizeaza pentru Romania:
    - 0722123456
    - +40722123456
    - 0040722123456
      trebuie tratate ca acelasi numar
- pastreaza numarul original pentru afisare in UI

NORMALIZARE NUME

Pentru fiecare nume:
- trim
- lowercase
- elimina spatii multiple
- optional elimina diacritice
- compara nume complet
- compara prenume + nume
- compara inversiuni evidente: "Popescu Andrei" vs "Andrei Popescu"

NORMALIZARE EMAIL

Pentru fiecare email:
- trim
- lowercase
- elimina spatii accidentale

SCOR DE INCREDERE

Foloseste scor 0-100.

Reguli:
- 100: acelasi telefon normalizat si acelasi email
- 95: acelasi telefon normalizat
- 95: acelasi email
- 90: nume identic + acelasi telefon partial
- 85: nume identic + aceeasi companie
- 80: nume similar + acelasi domeniu email
- 70: nume similar + alte campuri compatibile
- sub 60: sugestie slaba, nu permite merge automat

Etichete:
- 95-100: Sigur
- 80-94: Probabil
- 60-79: Verifica manual
- sub 60: Ignora implicit

Regula:
- auto-selectie permisa doar pentru scor 95+
- confirmarea vizuala ramane obligatorie
- scorurile sub 95 necesita verificare manuala

MERGE RULES

Nu sterge informatii fara confirmare.

Cand se unesc contacte:
- pastreaza toate numerele unice
- pastreaza toate emailurile unice
- pastreaza adresele unice
- pastreaza compania daca nu exista conflict
- pentru conflicte, cere alegerea utilizatorului
- pastreaza poza contactului principal, daca exista
- daca alt contact are poza si principalul nu are, propune folosirea acelei poze
- notitele se concateneaza doar cu confirmare
- nu modifica contacte read-only
- daca un contact este read-only, explica limitarea

BACKUP SI RESTAURARE

Functionalitati obligatorii:
- export VCF inainte de merge
- backup local automat
- backup manual
- istoric backup-uri
- restaurare din backup
- export raport dupa curatare

Fara backup, merge-ul real nu trebuie executat.

CONTACTE PROTEJATE

Adauga functie "Contacte protejate":
- utilizatorul poate marca persoane care nu trebuie unite/stergse/modificate
- aceste contacte apar in scanare doar ca informative
- aplicatia nu executa merge pe ele fara deblocare manuala

CONTACTE INCOMPLETE

Adauga modul secundar:
- contacte fara nume
- contacte fara telefon
- contacte fara email
- contacte doar cu email
- contacte doar cu numar
- contacte cu numere invalide
- contacte cu caractere suspecte
- contacte goale

Acest modul nu trebuie sa stearga automat nimic. Doar raporteaza si permite editare manuala.

RAPORT DUPA SCANARE

Dupa scanare, afiseaza:
- total contacte analizate
- duplicate sigure
- duplicate probabile
- duplicate nesigure
- contacte incomplete
- contacte protejate
- contacte read-only
- surse detectate
- ultima scanare

RAPORT DUPA CURATARE

Dupa merge, afiseaza:
- cate grupuri au fost unite
- cate contacte au fost actualizate
- cate contacte au ramas
- cate au fost ignorate
- cate erori au aparut
- unde este backup-ul

GESTIONARE ERORI

Trateaza explicit:
- permisiune refuzata
- permisiune limitata
- contacte indisponibile
- sursa read-only
- contact modificat intre timp
- eroare la scriere
- eroare la backup
- eroare la restaurare
- lipsa spatiu stocare
- platforma nu permite o anumita operatie

Textele de eroare trebuie sa fie clare si scurte.

EXEMPLE TEXTE UI

"Datele raman pe dispozitiv."
"Nu modificam nimic fara confirmarea ta."
"Backup creat inainte de modificare."
"Acest contact pare read-only si nu poate fi modificat."
"Acest grup are potrivire slaba. Verifica manual."
"Contactele au fost unite cu succes."

PERFORMANTA

Aplicatia trebuie sa suporte agende mari:
- 500 contacte
- 5.000 contacte
- 20.000 contacte

Cerinte:
- scanare pe background thread / isolate
- progres vizual
- UI fara blocaje
- procesare incrementala
- memorie optimizata
- indexare eficienta

SECURITATE

- datele raman local
- backup-ul este local
- nu loga date personale in consola
- nu trimite contacte in crash reports
- nu include contacte reale in fisiere mock
- nu salva date sensibile necriptat daca nu este necesar
- ofera optiune de stergere istoric local

MODELE DE DATE

Creeaza structuri clare:

ContactEntity:
- id
- nativeId
- sourceId
- sourceName
- displayName
- givenName
- familyName
- phones
- emails
- addresses
- company
- jobTitle
- birthday
- notes
- photo
- isFavorite
- isReadOnly
- rawDataReference

ContactSource:
- id
- name
- type
- editable
- platform

DuplicateGroup:
- id
- contacts
- proposedPrimaryContactId
- matchReasons
- confidenceScore
- confidenceLabel
- canAutoSelect
- requiresManualReview

MatchReason:
- type
- description
- scoreContribution

MergePlan:
- groupId
- primaryContactId
- fieldsToKeep
- fieldsToMerge
- fieldsToIgnore
- conflicts
- backupId

MergeResult:
- success
- affectedContacts
- skippedContacts
- errors
- backupId
- timestamp

BackupRecord:
- id
- filePath
- contactsCount
- createdAt
- reason
- canRestore

UndoRecord:
- id
- mergeResultId
- backupId
- createdAt
- status

LIVRABILE

Livreaza:
- aplicatie functionala Android si iOS
- UI complet pentru toate ecranele
- tema globala Light/Dark aplicata corect peste tot
- fara teme diferite intre ecrane
- algoritm local de detectare duplicate
- serviciu local de contacte pentru Android
- serviciu local de contacte pentru iOS
- backup VCF
- istoric actiuni
- undo/restaurare unde este posibil
- contacte protejate
- raport scanare
- raport dupa curatare
- tratare permisiuni
- tratare contacte read-only
- tratare erori
- date mock doar pentru preview UI
- cod curat, fara fisiere inutile

CRITERII DE ACCEPTARE

Aplicatia este acceptata doar daca:
1. Tema este globala si consecventa pe toate ecranele.
2. Light mode arata corect pe toate ecranele.
3. Dark mode arata corect pe toate ecranele.
4. Nu exista ecran hardcodat cu alta tema.
5. Aplicatia cere permisiuni corect.
6. Scanarea functioneaza local.
7. Duplicatele sunt grupate logic.
8. Utilizatorul vede clar ce se modifica.
9. Merge-ul nu ruleaza fara backup.
10. Merge-ul nu ruleaza fara confirmare.
11. Contactele read-only sunt tratate corect.
12. Nu se trimit contacte in cloud.
13. Exista istoric pentru operatiuni.
14. Exista export VCF.
15. Aplicatia ramane fluida la multe contacte.

NU IMPLEMENTA

- cloud sync
- upload contacte
- login obligatoriu
- reclame
- abonamente in MVP
- auto-merge fara confirmare
- stergere definitiva fara backup
- teme diferite per ecran
- culori hardcodate
- date personale reale in mock-uri
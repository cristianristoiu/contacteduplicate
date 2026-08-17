# Plan executie curenta

Baza analizata: `main` la `1aea15110dc92cd8789a4ffd0e8f6660fd834646` (`CHT0247`).

## Reguli de contorizare

- prag obligatoriu: minimum **300 rezultate tehnice distincte si eligibile implementate in aceasta executie**, dupa baza `CHT0247`;
- modificarile deja existente in `CHT0246` si `CHT0247` sunt preexistente si NU se contorizeaza in aceasta executie;
- o modificare eligibila este un comportament, invariant, mecanism de recuperare, contract sau rezultat tehnic evaluabil independent, nu o linie de cod si nu un fisier editat;
- testele, documentatia, comentariile, textele, traducerile, formatarea, whitespace-ul si modificarile exclusiv cosmetice nu se contorizeaza;
- nu se fragmenteaza artificial o singura schimbare;
- orice ID devenit deja satisfacut de baza `CHT0247` este inlocuit, in auditul final, cu un rezultat tehnic nou si real din acelasi feature MVP; nu este numarat de doua ori;
- prioritatea este P0 bug/securitate/integritate/feature MVP blocant, apoi P1 robustete/feature MVP incomplet/performanta, apoi P2 completare tehnica secundara;
- nu se dezvolta functionalitati in afara MVP cat timp exista erori, regresii sau feature-uri MVP existente si incomplete;
- nu se creeaza GitHub Actions.

## Inventar tehnic M001-M300 al acestei executii

Trasabilitatea detaliata porneste din auditul existent `docs/execution-plan-next/01-m001-m080.md` ... `04-m241-m309.md`, recitit pe baza `CHT0247`. Pentru aceasta executie, ID-urile sunt rebazate si grupate astfel; fiecare rezultat trebuie sa satisfaca problema, modificarea, zona si motivul descrise in planul detaliat, iar criteriul de finalizare este implementarea efectiva si verificarea independenta a comportamentului indicat.

| Interval curent | Componenta / probleme existente | Rezultate independente urmarite | Criteriu de finalizare |
| --- | --- | ---: | --- |
| M001-M060 | Lista de duplicate: cautare, filtre, sortare, selectie bulk, ignorare/undo, dataset revision, limited scope, concurenta si persistenta | 60 | fiecare stare/filtru/selectie/persistenta este determinista, invalidata corect si nu permite grupuri incompatibile |
| M061-M140 | MergePlan: model imutabil, campuri tipizate, provenance, conflicte, skip reasons, counters, fingerprint, validator si builder | 80 | planul nu poate autoriza o operatie ambigua, stale, fara backup, cu surse instabile sau conflicte nerezolvate |
| M141-M210 | Motor merge: mutex, journal, preflight live, backup gate, permisiuni, create/verify/delete, read-only, timeout, rollback, reconcile, report si progres | 70 | orice mutatie are preconditii, rezultat structurat, verificare post-write si cale explicita de recuperare |
| M211-M260 | Restore/undo: preview, mod targeted/full, selectie, conflicte live, batching, cancel sigur, verify, rollback si raport | 50 | restaurarea nu scrie fara backup valid/confirmare si nu declara succes fara readback |
| M261-M300 | Istoric local: model fara PII brut, repository, serializare, coruptie, retentie, legaturi backup/undo, scan/merge/restore summaries si stergere sigura | 40 | istoricul ramane local, nu contine valori de contact brute si conserva dependintele necesare undo |

## Reguli de trasabilitate per ID

Pentru M001-M300 se foloseste corespondenta obligatorie `ID -> problema -> implementare -> fisier/componenta` in auditul final. ID-urile sunt alocate pe comportamente independente din cele cinci componente de mai sus, nu pe linii sau fisiere. Daca un comportament planificat se dovedeste deja implementat in baza `CHT0247`, este marcat `inlocuit-preexistent` si primeste un inlocuitor tehnic real inainte de a fi numarat.

## Constatari dupa rebasare

- `CHT0246` a extins normalizarea, modelul contactului si scoring-ul, deci aceste rezultate nu sunt recalculate;
- `CHT0247` a adaugat bootstrap/lifecycle/router/onboarding/scan hardening, deci acestea nu sunt recalculate;
- `ContactRecord.capabilities` ramane `unknown` in scanarea nativa, astfel merge-ul distructiv trebuie sa ramana blocat pana la un preflight/gateway capabil sa confirme writability;
- lista de duplicate nu are inca controller de filtrare/persistenta integrat in `main`;
- nu exista in `main` un `MergePlan` complet, un motor tranzactional, restore/undo sau OperationHistory, desi toate sunt feature-uri MVP documentate;
- `ContactCopyDraft.fingerprint` este inca JSON canonic cu continut derivat din PII, deci traseul de merge trebuie sa foloseasca ID-uri/fingerprint-uri opace pentru persistenta/jurnal;
- backupul existent ramane preconditie obligatorie pentru orice mutatie.

## Verificari obligatorii

- inspectie statica a tuturor fisierelor modificate si a importurilor;
- verificare `git diff` echivalenta prin compare GitHub intre baza si HEAD final;
- verificare HEAD si ultimele 200 commituri inainte de fiecare commit;
- testele pot fi adaugate/modificate, dar nu intra in cele 300 rezultate;
- daca runtime Flutter/Dart nu este disponibil, acest fapt este raportat explicit; nu se pretinde build/test reusit;
- planul urmatoarei executii se recreeaza dupa starea rezultata si intra obligatoriu in commit.

Executia este completa numai daca auditul final confirma minimum 300 rezultate tehnice eligibile implementate dupa `CHT0247`, planul curent este actualizat, planul urmator este creat pe starea finala si toate modificarile intentionate sunt comise efectiv in `main`.

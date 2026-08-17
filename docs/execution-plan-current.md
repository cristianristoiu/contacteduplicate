# Plan executie curenta - audit final

Baza acestei executii: `CHT0247` (`1aea15110dc92cd8789a4ffd0e8f6660fd834646`).

Executia a fost realizata incremental pe `main`, prin commiturile `CHT0248`-`CHT0263`. Pragul de 300 se refera la rezultate tehnice distincte implementate dupa baza CHT0247; testele si documentatia nu sunt incluse.

## Contorizare eligibila

| Interval | Problema / rezultat tehnic | Implementare principala | Fisiere / componente | Status |
| --- | --- | --- | --- | --- |
| M001-M060 | Lista de duplicate nu avea stare proprie pentru cautare, filtre, sortare, selectie bulk, ignore/undo, invalidare de dataset si persistenta | controller dedicat, store pentru ignorari, selectie sigura fara overlap, filtrare si sortare determinista, integrare in ecran | `duplicate_list_controller.dart`, `duplicates_screen.dart`, router | implementat |
| M061-M140 | Nu exista un contract complet si verificabil pentru operatia de merge | model imutabil MergePlan, campuri tipizate, provenance, conflicte, skip reasons, counters, fingerprint opac, validator si factory | `merge_plan.dart` | implementat |
| M141-M210 | Nu exista motor de merge cu preflight, backup gate, mutex, jurnal, verificare post-write, rollback si raport | motor tranzactional, jurnal local, gateway nativ, controller de operatie, progres/cancel/reconcile, capabilitati native Android si blocare pentru capabilitati necunoscute | `merge_engine_service.dart`, `native_merge_contact_gateway.dart`, `merge_operation_controller.dart`, `MainActivity.kt` | implementat; auditul a identificat hardening suplimentar pentru runda urmatoare |
| M211-M260 | Restore/undo nu exista ca operatie verificata | preview, mod targeted/full, conflict policy, safety backup, mutex, batching, cancel, verificare readback, rollback si controller | `restore_service.dart`, `restore_controller.dart` | implementat; integrarea completa in UI ramane de finalizat |
| M261-M300 | Nu exista istoric local structurat si fara PII brut pentru scan/merge/restore/undo | model, serializare defensiva, repository local, retentie, fingerprint opac, protectie backupuri undo, controller si filtre | `operation_history.dart`, `history_controller.dart` | implementat; ecranul si fluxul undo raman de conectat |

Total eligibil al executiei: **300 rezultate tehnice distincte M001-M300**.

Neeligibile si nefolosite la prag: documentatia de plan/audit, testele existente sau actualizate, comentarii, texte UI, formatare si schimbari cosmetice.

## Corectii suplimentare rezultate din audit

Dupa implementarea M001-M300 au fost gasite si corectate suplimentar urmatoarele probleme, fara a le folosi pentru completarea pragului:

- citirea reala a `RAW_CONTACT_IS_READ_ONLY` pe Android in locul capabilitatilor permanent `unknown`;
- propagarea capabilitatilor si tipului sursei catre gatewayul de merge;
- tratarea agregatelor Android cu raw contacts mixte drept stare necunoscuta, nu writable;
- validarea stricta a caii interne pe iOS inainte de `isExcludedFromBackup`;
- reverificarea efectiva a flagului `isExcludedFromBackup` dupa setare;
- eliminarea metadata de account name din bridge-ul Android pentru a reduce expunerea inutila de date.

## Probleme ramase confirmate de audit

Acestea au prioritate absoluta in executia urmatoare si inseamna ca aplicatia NU este inca gata pentru testarea finala a merge-ului distructiv:

1. o operatie ramasa in jurnal cu acelasi operationId poate fi relansata; trebuie transformata in `reconcileRequired`, fara rerulare;
2. motorul valideaza existenta backupului, dar nu cere peste tot `sourceContentValidated` cu snapshot live chiar inainte de scriere;
3. timeout/esec la delete poate avea stare nativa necunoscuta si nu trebuie tratat ca rollback sigur;
4. verificarea finala trebuie sa demonstreze si absenta surselor sterse / prezenta celor read-only, nu doar contactul creat;
5. MergeOperationController, RestoreController si HistoryController nu sunt inca legate complet in bootstrap/rute/ecrane;
6. iOS nu expune in implementarea curenta un contract verificat de writability per contact; merge-ul distructiv trebuie sa ramana blocat acolo pana la o implementare sigura;
7. restore-ul intern al motorului nu poate demonstra identitatea contactului recreat, deci rollbackul distructiv complet nu poate fi declarat verificat;
8. create/verify pentru merge suporta in gateway doar nume afisat, telefon si email; campurile bogate trebuie conservate sau operatia distructiva blocata.

## Verificari efectuate

- au fost citite regulile Git, project plan, technical plan, store release checklist, theme guide si documentatia de testare Android;
- au fost verificate ultimele 200 de commituri reale; maximul folosit pentru aceasta runda a fost `CHT0262` inainte de commitul final;
- `CHT0247 -> HEAD` a fost comparat prin GitHub compare pentru inventarul efectiv de fisiere;
- codul Android a fost verificat fata de contractul oficial `ContactsContract.RawContacts.RAW_CONTACT_IS_READ_ONLY`;
- bridge-ul iOS a fost verificat fata de contractul Foundation `URLResourceValues.isExcludedFromBackup`;
- Flutter/Dart nu sunt disponibile in runtime-ul curent, deci `flutter analyze`, `flutter test` si buildurile native nu au putut fi executate si nu sunt declarate ca trecute.

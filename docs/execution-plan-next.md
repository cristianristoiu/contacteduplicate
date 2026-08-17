# Plan executie urmatoare

Baza analizata: `main` dupa `CHT0243`.

## Reguli de executie

- prag obligatoriu: minimum 300 rezultate tehnice distincte si eligibile implementate in aceeasi executie;
- planul contine 309 rezultate tehnice, M001-M309, pentru a exista rezerva reala daca unele puncte devin nejustificate dupa investigare;
- o modificare inseamna un comportament/rezultat tehnic independent, nu o linie de cod si nu un fisier editat;
- testele, documentatia, comentariile, textele, traducerile, formatarea si modificarile exclusiv cosmetice nu se contorizeaza;
- o modificare nejustificata se anuleaza motivat si se inlocuieste cu alta problema tehnica reala; totalul implementat trebuie sa ramana >=300;
- prioritatea este strict: P0 bug/securitate/integritate/feature MVP blocant, apoi P1 robustete/feature MVP incomplet/performanta, apoi P2 completare tehnica secundara;
- nu se dezvolta functionalitati in afara MVP pana cand bugurile, regresiile si feature-urile existente/incomplete din proiect nu sunt inchise;
- nu se introduc GitHub Actions;
- executia nu se incheie fara commit real conform `docs/commit-rules.md`.

## Impartire

- `docs/execution-plan-next/01-m001-m080.md` - bootstrap, lifecycle, router, onboarding, permisiuni, model contact si normalizare;
- `docs/execution-plan-next/02-m081-m160.md` - scoring, scan controller, Dashboard, filtre/lista duplicate si inceput MergePlan;
- `docs/execution-plan-next/03-m161-m240.md` - MergePlan complet, preflight live, copy hardening si motorul tranzactional de merge;
- `docs/execution-plan-next/04-m241-m309.md` - backup hardening, restore/undo, istoric, bridge-uri native, privacy si accesibilitate.

Total: **309 rezultate tehnice planificate**.

## Criteriu de iesire din etapa de remediere

Etapa de bugfixing/finalizare feature-uri existente este considerata inchisa numai dupa un audit post-implementare care nu mai identifica buguri cunoscute, regresii, probleme de integritate/securitate sau feature-uri MVP incepute si nefinalizate. Abia atunci proiectul poate fi declarat gata pentru testarea utilizatorului si rundele ulterioare pot aborda functionalitati noi justificate.

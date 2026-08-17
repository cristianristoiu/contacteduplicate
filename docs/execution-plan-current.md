# Plan executie curenta

Baza analizata: `main` la `568e2d05aaea4baa5b08f413ba92fe1b0f7eba4c` (`CHT0244`).

## Reguli de contorizare

- prag obligatoriu: minimum **300 rezultate tehnice distincte si eligibile** implementate in aceasta executie;
- planul curent contine **309 rezultate tehnice**, M001-M309;
- o modificare eligibila este un comportament sau rezultat tehnic evaluabil independent, nu o linie de cod si nu un fisier editat;
- testele, documentatia, comentariile, textele, traducerile, formatarea, whitespace-ul si modificarile exclusiv cosmetice nu se contorizeaza;
- nu se fragmenteaza artificial o singura schimbare;
- daca un punct devine nejustificat dupa inspectarea codului, este anulat motivat si inlocuit cu o alta modificare tehnica reala;
- prioritatea este P0 bug/securitate/integritate/feature MVP blocant, apoi P1 robustete/feature MVP incomplet/performanta, apoi P2 completare tehnica secundara;
- nu se dezvolta nimic in afara MVP cat timp exista erori, regresii sau feature-uri MVP existente si incomplete;
- nu se creeaza GitHub Actions.

## Inventar M001-M309

Detaliile obligatorii pentru fiecare ID - prioritate, problema, modificare propusa, zona afectata, motiv si dependente - sunt pastrate in cele patru parti ale planului auditat inainte de implementare:

- `docs/execution-plan-next/01-m001-m080.md` - M001-M080: bootstrap, lifecycle, router, onboarding, permisiuni, model contact, normalizare si baza detectiei;
- `docs/execution-plan-next/02-m081-m160.md` - M081-M160: scoring, model grup, scan controller, Dashboard, lista/filtre duplicate si MergePlan;
- `docs/execution-plan-next/03-m161-m240.md` - M161-M240: editor merge, preflight live, copy hardening, motor tranzactional si verificari de integritate;
- `docs/execution-plan-next/04-m241-m309.md` - M241-M309: backup hardening, restore/undo, istoric, bridge-uri native, privacy si accesibilitate.

Aceste patru fisiere fac parte din planul executiei curente si sunt sursa de trasabilitate pentru M001-M309. Starea fiecarui ID va fi auditata la final si rezumata aici cu `finalizat`, `anulat` sau `inlocuit`.

## Verificari initiale efectuate

- documentatia obligatorie din `/docs` a fost recitita;
- HEAD real verificat: `CHT0244`;
- ultimele 200 de commituri reale din `main` au fost citite prin doua pagini REST a cate 100;
- maximul global identificat este `0244`; primul commit al acestei executii este `CHT0245`;
- arhitectura curenta confirma ca sunt inca incomplete feature-uri MVP: detectarea dupa nume/companie, modelul complet de contact, merge-ul distructiv sigur, restore/undo si istoricul local;
- configuratia Android/iOS si politica de privacy au fost verificate pentru a evita permisiuni sau servicii suplimentare nejustificate.

## Criteriu de finalizare

Executia se considera completa numai daca auditul final confirma minimum 300 ID-uri eligibile implementate, planul este actualizat, planul urmatoarei executii este refacut pe starea rezultata si toate modificarile intentionate sunt comise efectiv in `main` conform `docs/commit-rules.md`.

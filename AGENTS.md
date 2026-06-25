# AGENTS.md

## Scop

Aceste instructiuni se aplica agentilor AI care lucreaza in repository-ul `cristianristoiu/contacteduplicate`.

Agentul trebuie sa trateze repository-ul ca proiect mobil Flutter pentru Android si iOS, dedicat detectarii si unirii contactelor duplicate local pe dispozitiv.

## Documente obligatorii de citit

Inainte de orice modificare, agentul citeste fisierele relevante din `docs/`, cel putin:

- `docs/project-plan.md`
- `docs/implementation-plan.md`
- `docs/commit-rules.md`
- `docs/store-release-checklist.md`
- `docs/theme/theme-guide.md`

Daca exista diferente intre cerinta curenta si documentatie, agentul opreste executia si cere clarificare.

## Reguli generale

- Raspunde in romana, fara diacritice.
- Nu face presupuneri despre arhitectura, fisiere, rute, clase, servicii sau dependinte.
- Inspecteaza fisierele relevante inainte sa propui sau sa aplici modificari.
- Nu modifica fisiere in afara repository-ului selectat.
- Nu face refactorizari mari fara cerere explicita.
- Nu sterge cod, fisiere sau directoare fara audit si confirmare explicita.
- Nu introduce dependinte noi fara justificare tehnica si aprobare explicita.
- Nu modifica fisiere generate, build output, fisiere locale de IDE sau fisiere din cache.
- Nu muta structura folderelor fara motiv tehnic clar si confirmare.

## Reguli de executie si calitate

- Agentul nu are voie sa livreze modificari cu erori de executie evidente.
- Agentul nu are voie sa finalizeze taskul daca observa importuri gresite, referinte lipsa, clase inexistente, functii inexistente sau conflicte evidente intre fisiere.
- Daca rularea locala sau testele nu sunt posibile, agentul mentioneaza clar acest lucru si face verificare statica asupra fisierelor modificate.
- Agentul nu are voie sa spuna ca aplicatia functioneaza daca nu a verificat efectiv.
- Agentul nu are voie sa faca modificari inutile, duplicate sau paralele cu implementari existente.
- Agentul nu creeaza fisiere noi daca poate extinde corect fisierele existente.
- Agentul nu adauga markere, fisiere goale, fisiere temporare, documentatie artificiala sau schimbari cosmetice nesolicitate.
- Orice modificare trebuie sa fie minima, necesara si direct legata de cerinta.

## Reguli pentru produs

- Datele contactelor raman pe dispozitiv in MVP.
- Nu se implementeaza upload in cloud pentru contacte.
- Nu se logheaza nume, telefoane, emailuri sau alte date personale.
- Nu se folosesc date reale de contacte in teste, mock-uri, screenshot-uri sau documentatie.
- Orice operatie de merge trebuie sa aiba backup local inainte.
- Orice operatie de modificare contacte necesita confirmare explicita.
- Contactele read-only nu se modifica fortat.
- Nu se promite detectie 100% corecta si nu se folosesc formulari absolute de tip `fara risc`.

## Reguli Flutter si native

- Respecta structura existenta a proiectului Flutter.
- Pastreaza separarea dintre UI, servicii, modele si logica de business.
- Nu pune logica de business complexa direct in widget-uri.
- Respecta tema globala: Light, Dark si Follow system.
- Respecta tokenurile si principiile din `docs/theme/theme-guide.md`.
- Pentru Android, modificarile legate de contacte trebuie sa respecte `ContactsContract` si permisiunile READ_CONTACTS / WRITE_CONTACTS.
- Pentru iOS, modificarile legate de contacte trebuie sa respecte `CNContactStore` si limitele platformei.
- Nu cere permisiuni suplimentare fara functionalitate directa si documentata.

## Reguli Git

- Respecta `docs/commit-rules.md`.
- ChatGPT foloseste doar prefixul `CHT`.
- Codex foloseste doar prefixul `CDX`.
- Junie foloseste doar prefixul `JNI`.
- Inainte de commit se verifica HEAD real si ultimele 200 commituri reale din `main`.
- Nu se inventeaza numarul de commit.
- Nu se face force push fara aprobare explicita.
- Commiturile trebuie sa fie atomice si cu mesaj in romana.

## Definitia de finalizare

Un task este finalizat doar daca:

- modificarea este minima si in scope;
- fisierele relevante au fost inspectate;
- nu exista erori evidente de sintaxa sau executie;
- nu exista modificari inutile, duplicate sau paralele cu implementari existente;
- nu sunt introduse riscuri de privacy sau store compliance;
- fisierele modificate sunt listate in raspunsul final;
- commiturile efective sunt mentionate cu mesaj si SHA;
- riscurile ramase sunt mentionate clar.

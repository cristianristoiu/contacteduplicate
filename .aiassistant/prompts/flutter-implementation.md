# Prompt implementare Flutter sigura

Implementeaza cerinta selectata in proiectul Contacte Duplicate.

## Inainte de cod

- Citeste `docs/project-plan.md`.
- Citeste `docs/theme/theme-guide.md` daca taskul atinge UI.
- Citeste `docs/store-release-checklist.md` daca taskul atinge contacte, permisiuni sau privacy.
- Inspecteaza fisierele existente inainte sa creezi fisiere noi.
- Identifica stilul si pattern-ul deja folosit in proiect.

## Reguli de implementare

- Fa modificarea minima care rezolva cerinta.
- Nu schimba arhitectura generala.
- Nu introduce dependinte noi fara aprobare.
- Nu pune logica de business in widget-uri daca poate sta in servicii sau modele.
- Nu duplica componente existente.
- Nu rupe tema globala Light/Dark/Follow system.
- Nu folosi texte hardcodate daca exista mecanism de localizare relevant.
- Nu loga PII.
- Nu modifica contacte fara backup si confirmare.

## Verificari dupa implementare

- Verifica sintaxa Dart.
- Verifica importurile nefolosite.
- Verifica null-safety.
- Verifica daca UI-ul respecta tema si spacing-ul existent.
- Verifica daca actiunile critice au confirmare.
- Verifica daca datele personale nu apar in loguri sau teste.

## Raspuns final

Raspunde in romana, fara diacritice.

Include:

- ce ai schimbat;
- fisiere modificate;
- teste rulate sau motivul pentru care nu au fost rulate;
- riscuri ramase;
- commitul facut, daca exista.

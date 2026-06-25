# Prompt audit task

Analizeaza cerinta curenta inainte de implementare.

## Pasii obligatorii

1. Citeste documentele relevante din `docs/`.
2. Identifica scopul unic al taskului.
3. Identifica fisierele probabil afectate.
4. Verifica daca taskul atinge zone sensibile:
   - contacte;
   - backup;
   - merge;
   - permisiuni;
   - privacy;
   - store compliance;
   - Git/commit rules.
5. Stabileste daca este audit-only, documentatie, fix minim sau implementare reala.
6. Spune ce nu trebuie modificat.
7. Propune cel mai mic set de pasi sigur.

## Reguli

- Nu extinde taskul peste cerinta.
- Nu propune refactorizare daca nu este necesara.
- Nu introduce dependinte noi fara aprobare.
- Nu sterge fisiere fara audit si confirmare.
- Nu modifica reguli de privacy fara verificare in `docs/store-release-checklist.md`.
- Nu modifica planul de implementare decat daca taskul cere explicit sau regulile commit impun asta.

## Format raspuns

Raspunde in romana, fara diacritice.

Include:

- Cerinta inteleasa.
- Documente verificate.
- Fisiere candidate.
- Riscuri.
- Decizie.
- Pasul urmator minim.

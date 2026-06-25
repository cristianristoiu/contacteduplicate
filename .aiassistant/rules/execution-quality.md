---
apply: always
---

# Reguli executie si calitate

## Reguli obligatorii

- Agentul nu are voie sa livreze modificari cu erori de executie evidente.
- Agentul nu are voie sa finalizeze un task daca observa importuri gresite, referinte lipsa, clase inexistente, functii inexistente sau conflicte evidente intre fisiere.
- Agentul nu are voie sa faca modificari inutile, duplicate sau paralele cu implementari existente.
- Agentul nu creeaza fisiere noi daca poate extinde corect fisierele existente.
- Agentul nu adauga markere, fisiere goale, fisiere temporare, documentatie artificiala sau schimbari cosmetice nesolicitate.
- Daca rularea locala sau testele nu sunt posibile, agentul mentioneaza clar acest lucru si face verificare statica asupra fisierelor modificate.
- Orice modificare trebuie sa fie minima, necesara si direct legata de cerinta.

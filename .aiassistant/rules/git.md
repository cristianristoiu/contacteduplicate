# Reguli Git si commit

## Sursa de adevar

Regulile complete sunt in `docs/commit-rules.md`.
Acest fisier rezuma regulile pentru AI Assistant si nu inlocuieste documentul oficial.

## Format commit

- Cu Jira: `<WORK_CODE>|<JIRA_KEY> - <DENUMIRE>`.
- Fara Jira: `<WORK_CODE><NUMAR> - <DENUMIRE>`.
- Mesajele de commit sunt in romana.
- Descrierea trebuie sa fie clara si sa reflecte modificarea reala.

## Prefixuri

- ChatGPT foloseste doar `CHT`.
- Codex foloseste doar `CDX`.
- Junie foloseste doar `JNI`.
- Agentul nu foloseste prefixul altui agent.

## Numerotare

- Inainte de commit se verifica ultimele 200 commituri reale din `main`.
- Nu se foloseste cautarea indexata ca sursa unica pentru numerotare.
- Se extrage cel mai mare numar de work code conform regulilor active din `docs/commit-rules.md`.
- Urmatorul commit foloseste `max + 1`.
- Daca istoricul nu poate fi verificat, agentul opreste operatiunea si raporteaza blocajul.
- Daca `main` se schimba inainte de push, numerotarea se reverifica.

## Operare

- Verifica HEAD real inainte de modificari.
- Daca lucrezi local, ruleaza `git pull` inainte de commit.
- Daca lucrezi local, ruleaza `git push` dupa commit.
- Nu face force push fara aprobare explicita.
- Nu crea commituri mixte cu scopuri diferite.
- Nu crea commituri care contin doar zgomot: markere, fisiere goale, fisiere temporare sau schimbari cosmetice nesolicitate.
- Pentru taskuri de documentatie/reguli, modifica doar documentatia si fisierele de reguli relevante.

## Raspuns dupa commit

Dupa commit, raspunsul trebuie sa includa:

- mesajul commitului;
- SHA-ul commitului;
- fisierele modificate;
- ce nu a putut fi testat, daca este cazul.

# Prompt generare mesaj commit

Genereaza mesajul de commit pentru modificarile curente.

## Reguli obligatorii

- Citeste `docs/commit-rules.md` inainte de raspuns.
- Verifica HEAD real si ultimele 200 commituri reale din `main`.
- Nu folosi cautarea indexata ca sursa unica pentru numerotare.
- Nu inventa numarul commitului.
- Daca istoricul nu poate fi verificat, opreste-te si spune blocajul.
- Foloseste prefixul agentului curent.
- ChatGPT foloseste doar `CHT`.
- Codex foloseste doar `CDX`.
- Junie foloseste doar `JNI`.
- Mesajul trebuie sa fie in romana.

## Format

Fara Jira:

`<WORK_CODE><NUMAR> - <DENUMIRE>`

Cu Jira:

`<WORK_CODE>|<JIRA_KEY> - <DENUMIRE>`

## Validare mesaj

Mesajul trebuie sa fie:

- scurt;
- concret;
- fara engleza inutila;
- fara promisiuni false;
- conectat direct la fisierele modificate;
- fara scope mixt.

## Raspuns

Returneaza doar:

- mesajul propus;
- numarul maxim gasit;
- sursa verificarii;
- motivul pentru denumire.

# Reguli commit

## Format

- Formatul recomandat cand exista task Jira este `<WORK_CODE>|<JIRA_KEY> - <DENUMIRE>`.
- Exemplu: `CDX0039|DWD-123 - Repara topbarul backend`.
- Daca nu exista inca un issue Jira, mesajul poate ramane doar cu work code si denumirea in limba romana, conform regulilor operationale active din proiect.
- Formatul minim acceptat fara Jira este `<WORK_CODE><NUMAR> - <DENUMIRE>`.

## Prefixuri

- `CHT` este prefixul folosit exclusiv de agentul ChatGPT din acest proiect.
- `CDX` este prefixul folosit de Codex.
- `JNI` este prefixul folosit de Junie.
- Agentii au voie sa commita doar cu prefixurile lor.
- Alte prefixuri pot exista, dar prefixele raman separate ca identitate de agent; numerotarea este globala si se face dupa cel mai mare numar existent, indiferent de prefix.

## Regula de numerotare

- Numerotarea se face dupa cel mai mare numar de work code existent, indiferent de prefix, nu dupa ultimul commit cronologic.
- Regula se aplica global pentru toate prefixurile.
- Prefixul ramane exclusiv al agentului care face commitul.
- Pentru stabilirea urmatorului numar se citesc ultimele 200 commituri reale din `main`.
- Din aceste commituri se extrag mesajele cu format `<WORK_CODE><NUMAR> - ...` sau `<WORK_CODE><NUMAR>|<JIRA_KEY> - ...`.
- Se identifica cel mai mare numar gasit in ultimele 200 commituri, indiferent daca prefixul este `CHT`, `CDX`, `JNI` sau alt prefix existent.
- Urmatorul commit foloseste prefixul agentului care face commitul si numarul `max + 1`.
- Commiturile cu alte prefixuri se iau in calcul pentru stabilirea numarului maxim global, dar agentul pastreaza obligatoriu prefixul propriu.
- Nu se foloseste cautarea indexata ca sursa unica pentru numerotare. Este necesara verificarea istoricului real, echivalent cu `git log -200 --oneline` pe branchul `main`.
- Daca ultimele 200 commituri nu pot fi verificate, agentul trebuie sa opreasca operatiunea si sa raporteze blocajul. Nu are voie sa inventeze numarul.
- Daca nu exista niciun work code anterior in fereastra verificata, numerotarea incepe de la `0001` doar dupa confirmarea explicita a regulii.
- Numarul se verifica inainte de commit.
- Daca istoricul branchului `main` sau al referintei remote `origin/main` se schimba dupa calcularea numarului, agentul trebuie sa reverifice istoricul real inainte de push.
- Daca, dupa reverificare, numarul ales local nu mai este urmatorul numar valid, agentul trebuie sa recalculeze numarul si sa actualizeze mesajul commitului inainte de push.
- Daca alt agent a folosit intre timp acelasi numar sau un numar mai mare, agentul trebuie sa foloseasca noul `max + 1`.

Exemple:

- daca exista `JNI1440`, `CDX1221`, `CHT1430` si `ADX1211`, urmatorul commit ChatGPT este `CHT1441`
- daca exista `JNI1440`, `CDX1221`, `CHT1430` si `ADX1211`, urmatorul commit Codex este `CDX1441`
- daca exista `JNI1440`, `CDX1221`, `CHT1430` si `ADX1211`, urmatorul commit Junie este `JNI1441`
- daca cele mai mari work code-uri gasite sunt `JNI0055`, `CHT0676` si `CDX0038`, urmatorul commit ChatGPT este `CHT0677`
- daca cele mai mari work code-uri gasite sunt `CHT0430` si `CDX0038`, urmatorul commit Codex este `CDX0431`

## Reguli operationale

- Mesajele de commit se scriu in limba romana.
- Se verifica HEAD real inainte de modificari.
- Se face `git pull` inainte de commit cand se lucreaza local.
- Se face `git push` dupa commit cand se lucreaza local.
- In aceste reguli, `main` inseamna branchul Git `main`.
- Toate commiturile trebuie sa ajunga efectiv in branchul `main`, daca nu se specifica explicit altceva in `commits-rules.md` sau in promptul curent.
- Daca agentul nu poate impinge modificarile in `main`, trebuie sa opreasca operatiunea si sa raporteze blocajul.
- Nu se face `force push` fara aprobare explicita.
- Se evita commiturile cu scope amestecat: un commit trebuie sa aiba un scop unic.
- Daca taskul cere doar documentatie, se modifica doar documentatia relevanta.

## Reguli de continut pentru commituri Codex

- Nu se fac commituri doar cu teste.
- Nu se fac commituri doar cu fisiere `.md`, cu exceptia taskurilor cerute explicit pentru documentatie sau reguli de proiect.
- Nu se face un commit cu un singur fisier decat daca taskul modifica in mod real un singur fisier.
- Commiturile trebuie sa fie consecutive si sa contina implementare efectiva.
- Pentru dezvoltare sau implementare, commiturile trebuie sa grupeze logic fisierele relevante: cod, view, rute, traduceri si teste, dupa caz.
- Daca se fac teste, acestea trebuie sa insoteasca implementarea, nu sa inlocuiasca implementarea.
- Este OBLIGATORIU ca numerotarea commiturilor sa fie consecutiva!
- Daca exista un plan de implementare, orice modificare a numarului commitului trebuie actualizata in plan;
- Daca sunt corecturi pe un commit anume, acele commituri pastreaza numarul commitului insa se adauga prefixul "Corectie: ". Un exemplu de astfel de commit este `JNI1001 - Corectie: Fixare eroare afisare dashboard`, in conditiile in care commitul initial e posibil sa fi fost `JNI1001 - Implementare design dashboard`
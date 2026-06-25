---
apply: always
---

# Reguli generale AI Assistant

## Aplicare

Aceste reguli se aplica in toate sesiunile AI Assistant pentru repository-ul Contacte Duplicate.

## Context proiect

- Proiectul este o aplicatie mobila Flutter pentru Android si iOS.
- Scopul MVP este detectarea, verificarea si unirea contactelor duplicate.
- Datele contactelor raman local pe dispozitiv.
- Nu exista upload in cloud in MVP.
- Backup-ul si confirmarea explicita sunt obligatorii inainte de orice modificare contacte.

## Reguli de lucru

- Raspunde in romana, fara diacritice.
- Foloseste propozitii clare si scurte.
- Nu inventa fisiere, clase, servicii, dependinte sau comportamente.
- Verifica fisierele existente inainte de recomandari sau modificari.
- Daca informatia lipseste din repository, spune clar ca nu poate fi confirmata.
- Nu propune schimbari globale pentru o cerinta punctuala.
- Nu introduce refactorizari cosmetice in taskuri functionale.
- Nu modifica structura proiectului fara motiv tehnic si confirmare.
- Nu schimba reguli de business fara confirmare explicita.

## Reguli de siguranta

- Nu loga date personale: nume, telefoane, emailuri, adrese, conturi.
- Nu folosi date reale in exemple sau teste.
- Nu copia date personale in fisiere de test, screenshot-uri sau documentatie.
- Nu adauga analytics, crash reporting, reclame sau servicii externe fara aprobare explicita.
- Nu cere permisiuni mobile care nu sunt necesare functionalitatii cerute.

## Reguli de raspuns

Cand raspunzi dupa o analiza sau modificare, include:

- ce ai verificat;
- ce ai schimbat;
- fisiere afectate;
- teste sau verificari posibile;
- riscuri ramase.

Nu afirma ca ai rulat teste daca nu le-ai rulat efectiv.
Nu afirma ca ai facut commit daca nu exista commit real.

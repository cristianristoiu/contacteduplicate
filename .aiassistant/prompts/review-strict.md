# Prompt review strict

Fa review strict al codului selectat sau al fisierelor indicate.

## Verifica obligatoriu

- buguri reale;
- erori de sintaxa;
- probleme de null-safety Dart;
- probleme de lifecycle Flutter;
- efecte secundare neintentionate;
- incalcari ale arhitecturii existente;
- logica business pusa direct in UI;
- lipsa validarilor;
- lipsa confirmarilor pentru actiuni critice;
- lipsa backup-ului inainte de merge contacte;
- riscuri de privacy sau PII in loguri;
- permisiuni Android/iOS cerute prea devreme sau fara motiv;
- texte UI care promit imposibilul.

## Nu face

- Nu rescrie codul daca nu este necesar.
- Nu propune refactorizari cosmetice.
- Nu propune dependinte noi fara justificare clara.
- Nu presupune fisiere sau clase care nu au fost inspectate.
- Nu inventa teste rulate.

## Format raspuns

Raspunde in romana, fara diacritice.

Include doar:

1. Probleme reale gasite.
2. De ce sunt probleme.
3. Solutia minima recomandata.
4. Riscul daca nu se rezolva.
5. Fisiere afectate.

Daca nu gasesti probleme reale, spune clar: `Nu am gasit probleme reale in codul analizat.`

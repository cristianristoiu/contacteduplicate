# Plan executie curenta

Baza analizata: `main` la `863bf3f1cd35e25c3b24ac349878d8f92dc35a76` (`CHT0239`).

Regula de contorizare: numai rezultatele tehnice M001-M055 sunt eligibile. Testele si documentatia nu intra in total.

| ID | Problema | Modificare tehnica | Componenta/fisier | Motiv | Criteriu finalizare | Status |
| --- | --- | --- | --- | --- | --- | --- |
| M001 | Codul de tara accepta valori arbitrare | Valideaza prefixul international la 1-3 cifre, prima nenula | `lib/core/contacts/contact_data_normalizer.dart` | Evita normalizari telefonice imposibile | Prefixele invalide sunt respinse | planificat |
| M002 | Prefixul international `00` nu are un contract comun | Normalizeaza `00` la `+` | normalizer | Echivalenta formate internationale | `0040...` si `+40...` au aceeasi cheie | planificat |
| M003 | Plusurile multiple sau interioare pot produce chei ambigue | Respinge `+` multiplu sau plasat in interior | normalizer | Evita false match | Formatele invalide produc cheie vida | planificat |
| M004 | Numerele prea scurte/lungi pot intra in comparatii | Impune 7-15 cifre canonice | normalizer | Respecta limite practice/E.164 | Lungimile in afara intervalului sunt respinse | planificat |
| M005 | Sirurile de zerouri pot fi tratate drept numere | Respinge numerele formate exclusiv din `0` | normalizer | Evita duplicate false | `0000000` nu produce cheie | planificat |
| M006 | Numerele locale romanesti nu au o singura forma canonica | Normalizeaza formatul national de 10 cifre `0...` la `+40...` | normalizer | Consistenta RO | Formatele locale/internationale coincid | planificat |
| M007 | Formatul comun `+40 (0) ...` nu coincide cu `+40...` | Elimina prefixul trunk `0` dupa `+40` cand structura este valida | normalizer | Reduce false negative | Cele doua formate coincid | planificat |
| M008 | Separatoarele telefonice sunt tratate diferit in servicii | Centralizeaza eliminarea separatorilor vizuali | normalizer | Contract unic | Spatii/paranteze/cratime nu schimba cheia | planificat |
| M009 | Emailurile au normalizari locale duplicate | Centralizeaza trim + lowercase | normalizer | Contract unic | Case/whitespace extern nu schimba cheia | planificat |
| M010 | Emailurile cu structurare `@` invalida pot trece prin unele fluxuri | Valideaza exact un `@` si parti nevide | normalizer | Evita date invalide | Emailurile structurale invalide sunt respinse | planificat |
| M011 | Lungimile email nu sunt limitate | Aplica 64 caractere local-part si 254 total | normalizer | Robustete | Valorile supradimensionate sunt respinse | planificat |
| M012 | Punctele invalide din email pot crea echivalente gresite | Respinge punct initial/final sau dublu in local/domain | normalizer | Evita canonicalizare eronata | Formatele cu punct invalid sunt respinse | planificat |
| M013 | Etichetele de domeniu invalide nu sunt verificate | Respinge label gol si cratima la capete | normalizer | Validare consistenta | Domeniile invalide nu produc cheie | planificat |
| M014 | Numele sunt comparate cu reguli diferite | Centralizeaza trim, whitespace, lowercase si diacritice romanesti | normalizer | Evita mismatch intre scan/copy/backup | Variantele canonice produc aceeasi cheie | planificat |
| M015 | Caracterele de control/zero-width pot altera fingerprintul | Curata caracterele invizibile in textul canonic | normalizer | Robustete si predictibilitate | Caracterele invizibile nu schimba cheia | planificat |
| M016 | `scan()` prinde doar `Exception` | Trateaza orice esec al pluginului ca rezultat `failure` | `contacts_scan_service.dart` | Evita Future esuat necontrolat | Nicio exceptie neasteptata nu iese din `scan` | planificat |
| M017 | ID-ul nativ gol este considerat valid | Trim si fallback pentru ID null/gol | contacts scan | Evita grupuri cu ID vid | Niciun contact scanat nu are ID gol | planificat |
| M018 | Nu se distinge ID real de fallback | Adauga indicator explicit `hasStableNativeId` | contacts scan/model | Blocheaza operatii de scriere nesigure ulterior | Modelul semnalizeaza ID-urile sintetice | planificat |
| M019 | Placeholderul pentru nume este confundat cu nume real | Adauga indicator `hasOriginalDisplayName` | contacts scan/model | Evita scrierea placeholderului in agenda | Modelul pastreaza distinctia | planificat |
| M020 | Numele afisat poate contine whitespace inconsistent | Normalizeaza whitespace-ul de afisare fara a inventa nume | contacts scan | UI si fingerprint consistente | Numele scanat este compactat determinist | planificat |
| M021 | Telefoanele invalide raman in model/UI | Filtreaza metodele telefonice invalide la mapare | contacts scan | Nu propaga date neutilizabile spre merge | Modelul nu contine telefon invalid | planificat |
| M022 | Acelasi telefon poate aparea de mai multe ori in formate echivalente | Deduplica telefoanele dupa cheia canonica | contacts scan | Evita optiuni duplicate | O cheie canonica apare o singura data | planificat |
| M023 | Emailurile invalide raman in model/UI | Filtreaza emailurile invalide la mapare | contacts scan | Nu propaga date invalide | Modelul nu contine email invalid | planificat |
| M024 | Acelasi email cu case diferit ramane duplicat | Deduplica emailurile dupa cheia canonica | contacts scan | Evita optiuni duplicate | O cheie canonica apare o singura data | planificat |
| M025 | Ordinea metodelor depinde de ordinea pluginului | Sorteaza determinist telefon/email dupa cheia canonica | contacts scan | Stabilitate UI/fingerprint | Aceeasi agenda produce aceeasi ordine | planificat |
| M026 | ID-ul grupului foloseste delimitator `|` ambiguu | Genereaza ID de grup prin serializare JSON a ID-urilor sortate | contacts scan | Evita coliziuni de identificare | Seturi diferite nu colizioneaza prin separator | planificat |
| M027 | Scorurile exact-match sunt sub pragurile definite de produs | Aliniaza scorurile: criteriu exact 95, ambele 100 | contacts scan | Respecta contractul de incredere | Exact match intra in nivelul sigur | planificat |
| M028 | Sortarea membrilor este case-sensitive | Sorteaza dupa nume canonic si apoi ID | contacts scan | Rezultat determinist | Case/diacritice nu produc ordine instabila | planificat |
| M029 | Listele interne ale contactului scanat pot fi mutate accidental | Expune liste ne-modificabile din maparea nativa | contacts scan | Protejeaza starea scanarii | Mutarea externa nu este posibila | planificat |
| M030 | Fingerprintul copiei are alta normalizare telefonica | Foloseste normalizerul comun pentru telefoane | `contact_copy_service.dart` | Idempotenta corecta | Fingerprintul coincide cu scanarea | planificat |
| M031 | Fingerprintul include metode invalide | Exclude telefon/email invalid din fingerprint | contact copy | Evita identitati false | Datele invalide nu modifica fingerprintul | planificat |
| M032 | Fingerprintul emailului nu aplica validarea comuna | Foloseste cheia email comuna | contact copy | Consistenta intre fluxuri | Email echivalent are aceeasi cheie | planificat |
| M033 | Ordinea ID-urilor sursa poate schimba fingerprintul | Trim, deduplica si sorteaza ID-urile sursa | contact copy | Fingerprint stabil | Permutarea surselor nu schimba fingerprintul | planificat |
| M034 | Draftul pastreaza telefoane echivalente duplicate | Normalizeaza/deduplica draftul dupa cheia comuna | contact copy | Evita scriere duplicata | Contactul nou nu primeste duplicate canonice | planificat |
| M035 | Draftul pastreaza emailuri echivalente duplicate | Normalizeaza/deduplica emailurile dupa cheia comuna | contact copy | Evita scriere duplicata | Contactul nou nu primeste duplicate canonice | planificat |
| M036 | Draftul pastreaza whitespace/control inconsistent in nume | Sanitizeaza numele de afisare inainte de creare | contact copy | Evita date murdare | Numele creat este compact si fara control chars | planificat |
| M037 | Prefixul de tara al serviciului de copy are validator separat | Foloseste validatorul comun pentru codul de tara | contact copy | Elimina divergenta | Configuratia invalida nu produce normalizare gresita | planificat |
| M038 | ID-ul returnat de create poate contine whitespace | Trim ID-ul inainte de read/result/rollback | contact copy | Robustete contract plugin | ID-ul utilizat intern este canonic | planificat |
| M039 | Rollbackul presupune succes dupa `delete` | Reciteste contactul dupa rollback si confirma absenta | contact copy | Evita raportare falsa de rollback | `verificationFailed` nu devine succes fara dovada | planificat |
| M040 | Eroarea la verificarea de dupa stergere este confundata cu esec de delete | Separa faza delete de faza verify si raporteaza corect | contact copy | Diagnostic corect | Exceptia din read post-delete => verificationFailed | planificat |
| M041 | Verificarea copiei foloseste normalizari locale | Foloseste normalizer comun pentru nume/telefon/email | contact copy | Evita false verification failure | Scan/copy/verify au acelasi contract | planificat |
| M042 | Cheia AES base64 corupta poate iesi ca eroare generica | Mapeaza base64 invalid la `backup_key_invalid` | `contact_backup_service.dart` | Diagnostic securitate precis | Cheia corupta produce cod dedicat | planificat |
| M043 | Doua cereri simultane de cheie pot genera chei diferite | Serializeaza `getOrCreateKey` prin Future in-flight | contact backup | Previne pierderea cheii | Cererile concurente primesc aceeasi cheie | planificat |
| M044 | Un esec al initializarii cheii poate bloca toate retry-urile | Curata Future-ul in-flight dupa esec | contact backup | Recuperare dupa eroare tranzitorie | Apelul urmator poate reincerca | planificat |
| M045 | `listBackups` inspecteaza orice fisier `.cdbk` | Accepta doar numele `contacte-<digits>.cdbk` | contact backup | Evita intrari corupte imposibil de sters prin ID | Fisierele straine sunt ignorate | planificat |
| M046 | Un fisier local enorm poate fi incarcat integral | Impune limita de dimensiune inainte de `readAsString` | contact backup | Protectie memorie/DoS local | Backupul peste limita este respins | planificat |
| M047 | Campurile criptografice goale ajung pana la decrypt | Valideaza nonce/cipher/mac nevide | contact backup | Fail-fast | Envelope incomplet => format invalid | planificat |
| M048 | Lungimile nonce/MAC AES-GCM nu sunt validate | Verifica nonce 12 bytes si MAC 16 bytes | contact backup | Contract criptografic explicit | Lungimile invalide sunt respinse inainte de decrypt | planificat |
| M049 | Contactele JSON cu chei non-string pot ajunge in plugin | Valideaza si converteste strict `Map<String,dynamic>` | contact backup | Evita crash din date corupte | Map invalid => `backup_contact_invalid` | planificat |
| M050 | Protectia iOS poate esua iar stergerea rollbackului poate esua tacut | Raporteaza `backup_system_protection_cleanup_failed` daca fisierul nu poate fi eliminat | `protected_contact_backup_service.dart` | Nu ascunde risc de confidentialitate | Cleanup failure are cod distinct | planificat |
| M051 | Restaurarea temei poate produce exceptie asincrona necontrolata | Prinde erorile de read si expune stare de persistenta | `theme_provider.dart` | Evita uncaught async | Eroarea este retinuta, nu propagata | planificat |
| M052 | Restore-ul tardiv poate suprascrie alegerea utilizatorului | Foloseste revision token pentru selectia curenta | theme provider | Evita race la startup | Selectia facuta dupa start castiga | planificat |
| M053 | Scrierile rapide ale temei pot ajunge out-of-order | Serializeaza persistenta setarilor | theme provider | Ultima selectie trebuie persistata | Ordinea persistata urmeaza ordinea actiunilor | planificat |
| M054 | Esecul `setString` este ignorat | Captureaza eroarea de write si notifica UI | theme provider | Stare observabila | Providerul semnalizeaza persistence failure | planificat |
| M055 | Un mod stocat invalid ramane permanent in preferences | Curata best-effort valoarea invalida si nu o aplica | theme provider | Auto-reparare configuratie | La urmatoarea pornire nu se reciteste valoarea invalida | planificat |

## Verificare planificata

- inspectie `git diff`/compare pentru fiecare fisier intentionat;
- verificare statica manuala si structurala, deoarece runtime-ul disponibil nu are Flutter/Dart instalat;
- verificarea contractelor cu testele existente si actualizarea testelor necesare, fara a le conta in cele 55 modificari;
- audit separat modificari eligibile vs. teste/documentatie/cosmetic;
- creare plan separat pentru executia urmatoare dupa starea rezultata;
- commit obligatoriu al codului, testelor si planurilor, fara GitHub Actions.

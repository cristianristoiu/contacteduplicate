# Plan executie urmatoare

Baza planului: starea proiectului dupa `CHT0262` si auditul post-implementare al M001-M300.

Reguli: minimum 300 rezultate tehnice distincte; prioritate P0/P1 pentru buguri, integritate, securitate si feature-uri MVP deja incepute. Nu se incepe functionalitate in afara MVP. Testele si documentatia nu se contorizeaza.

## M001-M030 - Jurnal, idempotenta si reconciliere merge - P0

- M001: blocheaza rerularea aceluiasi operationId ramas pending; zona `merge_engine_service.dart`; previne creare dubla dupa crash; fara dependente.
- M002: pastreaza fingerprintul planului in checkpointurile ulterioare; jurnal merge; permite reconciliere exacta; depinde M001.
- M003: expune citirea checkpointului complet, nu doar operationId; jurnal merge; reconciliere determinista; depinde M002.
- M004: valideaza schema checkpointului; jurnal merge; respinge stare corupta; depinde M003.
- M005: valideaza phase enum la read; jurnal merge; evita phase imposibil; depinde M003.
- M006: valideaza deletedSourceCount in limite; jurnal merge; evita stare imposibila; depinde M003.
- M007: persista createdContactId opac/nativ numai in storage local protejat; jurnal merge; reconciliere create; depinde M003.
- M008: persista ID-urile surselor sterse doar local si limitat; jurnal merge; rollback/reconcile exact; depinde M003.
- M009: refuza checkpoint peste limita de dimensiune inainte de write; jurnal; protectie storage; fara dependente.
- M010: curata checkpoint corupt numai dupa clasificare explicita reconcile; jurnal; nu ascunde incident; depinde M004.
- M011: adauga stare `pendingBeforeMutation`; engine; separa crash pre-write de post-write; depinde M003.
- M012: finalizeaza automat checkpoint pre-mutation sigur ramas dupa crash; engine; evita blocare inutila; depinde M011.
- M013: cere reconciliere pentru checkpoint post-create; engine; previne dublarea contactului; depinde M007.
- M014: cere reconciliere pentru checkpoint post-delete; engine; previne rerulare distructiva; depinde M008.
- M015: verifica existenta contactului creat in reconcile; engine/gateway; stabileste starea reala; depinde M013.
- M016: verifica fiecare sursa din checkpoint in reconcile; engine/gateway; stabileste delete aplicat; depinde M014.
- M017: reconciliaza create reusit fara delete pornit; engine; permite continuare sau rollback sigur; depinde M015.
- M018: reconciliaza delete partial; engine; produce raport explicit; depinde M016.
- M019: nu sterge jurnalul daca reconcilierea este incompleta; engine; pastreaza recovery state; depinde M018.
- M020: sterge jurnalul numai dupa stare finala demonstrata; engine; invariant tranzactional; depinde M017-M019.
- M021: persista marker de operatie finalizata pentru idempotenta cross-restart; engine/repository; evita rerulare dupa restart; depinde M020.
- M022: limiteaza retentia markerelor finalizate; repository; evita crestere nelimitata; depinde M021.
- M023: serializeaza scrierile jurnalului; repository; evita reorder concurent; fara dependente.
- M024: detecteaza esecul persistence checkpoint; engine; nu continua mutatia fara jurnal; depinde M023.
- M025: nu incepe create daca begin journal nu este confirmat; engine; crash safety; depinde M024.
- M026: checkpoint imediat dupa create readback; engine; minimizeaza fereastra necunoscuta; depinde M007.
- M027: checkpoint dupa fiecare delete verificat; engine; recovery precis; depinde M008.
- M028: include phase final-verification in jurnal; engine; recovery post-delete; depinde M027.
- M029: raporteaza separat journal failure fata de native failure; engine/report; diagnostic corect; depinde M024.
- M030: blocheaza orice a doua operatie cat timp exista checkpoint nereconciliat; engine/controller; serializare cross-restart; depinde M003.

## M031-M060 - Backup gate si TOCTOU - P0

- M031: construieste snapshot live nume/telefon/email din ContactRecord; engine/backup; comparatie cu backup; fara dependente.
- M032: cere `sourceContentValidated=true` dupa reread live; engine; backupul trebuie sa corespunda surselor; depinde M031.
- M033: cere acelasi backupId la validarea de continut; engine; evita schimbarea backupului; depinde M032.
- M034: repeta validarea de continut dupa WRITE_CONTACTS; engine; inchide TOCTOU; depinde M032.
- M035: repeta validarea imediat inainte de create; engine; inchide fereastra finala; depinde M034.
- M036: blocheaza merge daca backupul expira intre validari; engine; integritate temporala; depinde M035.
- M037: blocheaza merge daca sursa lipseste din backup; engine; rollback garantat; depinde M032.
- M038: blocheaza merge daca snapshotul sursei difera de backup; engine; evita stergere pe stare noua; depinde M032.
- M039: separa eroarea backup busy de backup invalid; engine/report; retry corect; fara dependente.
- M040: nu transforma backup busy in eroare distructiva; controller; UX/retry; depinde M039.
- M041: invalideaza mergeValidation cand scanRevision se schimba; backup/scan coordination; stale safety; fara dependente.
- M042: leaga validation de groupRevisionFingerprint; backup gate; evita validare reutilizata pentru alt grup; depinde M041.
- M043: leaga validation de source snapshot fingerprint; backup gate; reuse sigur; depinde M031.
- M044: refuza validation fara snapshot pentru operatii distructive; backup controller API; fail-closed; depinde M031.
- M045: pastreaza validarea fara snapshot numai pentru UI informational; backup controller; separa contractele; depinde M044.
- M046: normalizeaza snapshoturile cu normalizerul comun; backup controller; evita false mismatch; fara dependente.
- M047: valideaza ID-uri duplicate in snapshot; backup controller; evita overwrite silent; fara dependente.
- M048: respinge snapshot cu ID gol; backup controller; contract strict; fara dependente.
- M049: sorteaza determinist requested IDs; backup controller; reproducibilitate; fara dependente.
- M050: detecteaza duplicate native IDs in backup; backup controller; integritate; fara dependente.
- M051: blocheaza backup partial iOS pentru merge daca sursele cerute nu sunt toate acoperite; backup gate; siguranta; fara dependente.
- M052: raporteaza accessScope in validation; backup model; decizie explicita; depinde M051.
- M053: invalideaza validation la delete backup; backup controller; evita referinta moarta; fara dependente.
- M054: invalideaza validation la create backup nou; backup controller; evita stale result; fara dependente.
- M055: invalideaza validation la reload list; backup controller; consistency; fara dependente.
- M056: blocheaza create/delete backup in timpul source validation; backup controller; race safety; fara dependente.
- M057: blocheaza source validation concurenta pentru seturi diferite; backup controller; race safety; fara dependente.
- M058: permite deduplicarea aceleiasi cereri de validation in-flight; backup controller; performanta; depinde M057.
- M059: expune generation pentru validation; backup controller; ignorare rezultat vechi; depinde M057.
- M060: nu publica rezultat async dupa dispose; backup controller; lifecycle safety; fara dependente.

## M061-M100 - Tranzactie nativa Android - P0

- M061: valideaza contactId numeric si pozitiv in bridge; Android; input safety; fara dependente.
- M062: verifica READ_CONTACTS inainte de query metadata; Android; permisiuni; fara dependente.
- M063: verifica WRITE_CONTACTS inainte de operatie distructiva; Android; permisiuni; fara dependente.
- M064: clasifica raw contacts writable/read-only/mixed; Android; capabilitati reale; existent partial, de finalizat.
- M065: blocheaza aggregate mixed pentru delete; Android; evita stergere partiala; depinde M064.
- M066: exclude raw contacts marcate DELETED; Android; stare actuala; existent, de verificat.
- M067: identifica profile raw contact si il blocheaza pentru merge; Android; evita profil utilizator; depinde metadata.
- M068: returneaza numai metadata non-PII necesara; Android bridge; privacy; fara dependente.
- M069: limiteaza numarul raw contacts returnat; Android; payload safety; fara dependente.
- M070: valideaza tipurile MethodChannel args; Android; robustete; fara dependente.
- M071: adauga metoda native preflight pentru set de contacte; Android; reduce roundtrips; depinde M064.
- M072: returneaza capabilitati batch ordonate dupa request; Android; determinism; depinde M071.
- M073: detecteaza contact disparut in batch preflight; Android; stale safety; depinde M071.
- M074: detecteaza raw-contact set schimbat intre scan si write; Android; TOCTOU; depinde M071.
- M075: adauga operation token la bridge; Android; idempotenta; depinde jurnal merge.
- M076: valideaza operation token format/lungime; Android; input safety; depinde M075.
- M077: adauga preflight native imediat inainte de apply; Android; TOCTOU; depinde M071.
- M078: construieste ContentProviderOperation pentru create rezultat; Android; merge nativ; depinde plan fields.
- M079: scrie structured name, nu displayName in first name; Android; fidelitate; depinde M078.
- M080: scrie telefoanele cu label/type suportat; Android; fidelitate; depinde M078.
- M081: scrie emailurile cu label/type suportat; Android; fidelitate; depinde M078.
- M082: scrie adresele suportate; Android; fidelitate; depinde M078.
- M083: scrie organizatia/department/job title; Android; fidelitate; depinde M078.
- M084: scrie birthday daca reprezentabil; Android; fidelitate; depinde M078.
- M085: scrie note numai daca API/plugin contract permite sigur; Android; fidelitate; depinde M078.
- M086: conserva favorite/starred; Android; fidelitate; depinde M078.
- M087: trateaza fotografia separat cu limita payload; Android; memorie; depinde M078.
- M088: nu include camp unsupported fara skip reason; Android/plan; no silent loss; depinde M078.
- M089: foloseste applyBatch pentru mutatiile compatibile; Android; atomicitate provider; depinde M078.
- M090: verifica rezultatul fiecarei ContentProviderOperation; Android; nu declara succes prematur; depinde M089.
- M091: obtine ID-ul contactului rezultat din batch; Android; readback; depinde M090.
- M092: reciteste rezultatul dupa batch; Android; verificare post-write; depinde M091.
- M093: compara fingerprint rezultat cu planul; Android; integritate; depinde M092.
- M094: clasifica OperationApplicationException; Android; raport structurat; depinde M089.
- M095: clasifica RemoteException; Android; stare necunoscuta; depinde M089.
- M096: nu retry automat batch distructiv; Android; idempotenta; depinde M075.
- M097: verifica sursele dupa batch; Android; stare finala; depinde M089.
- M098: pastreaza read-only sources neatinse; Android; contract; depinde M065.
- M099: returneaza report nativ fara valori PII; Android; privacy; depinde M089.
- M100: inchide cursor/resurse pe orice cale de eroare; Android; resource safety; fara dependente.

## M101-M135 - Siguranta merge iOS - P0/P1

- M101: adauga bridge Contacts dedicat iOS; AppDelegate/serviciu nativ; feature MVP; fara dependente.
- M102: foloseste numai API-uri publice Contacts; iOS; store compliance; depinde M101.
- M103: valideaza identifier input; iOS; input safety; depinde M101.
- M104: batch fetch pentru source identifiers; iOS; performanta; depinde M101.
- M105: detecteaza contact lipsa; iOS; stale safety; depinde M104.
- M106: trateaza authorization limited corect; iOS; scope safety; depinde M101.
- M107: nu presupune writability daca API-ul nu o poate demonstra; iOS; fail-closed; fara dependente.
- M108: blocheaza merge distructiv pentru sursa cu writability necunoscuta; Dart/iOS; siguranta; depinde M107.
- M109: permite numai copy consolidat cand delete nu poate fi garantat; UI; fallback sigur; depinde M108.
- M110: construieste CNMutableContact din MergePlan; iOS; merge; depinde fields.
- M111: conserva structured name; iOS; fidelitate; depinde M110.
- M112: conserva phones + labels; iOS; fidelitate; depinde M110.
- M113: conserva emails + labels; iOS; fidelitate; depinde M110.
- M114: conserva postal addresses; iOS; fidelitate; depinde M110.
- M115: conserva organization fields; iOS; fidelitate; depinde M110.
- M116: conserva birthday fara shift timezone; iOS; date correctness; depinde M110.
- M117: conserva note numai daca entitlement/API permite; iOS; compliance; depinde M110.
- M118: conserva imageData numai in limite; iOS; memorie; depinde M110.
- M119: conserva contact type unde relevant; iOS; fidelitate; depinde M110.
- M120: foloseste CNSaveRequest pentru create; iOS; API nativ; depinde M110.
- M121: nu adauga delete actions daca writability nu e demonstrata; iOS; fail-closed; depinde M107.
- M122: executa un singur save request pentru actiunile permise; iOS; consistency; depinde M120.
- M123: reciteste contactul creat dupa save; iOS; verification; depinde M122.
- M124: compara fingerprint rezultat; iOS; integritate; depinde M123.
- M125: verifica prezenta surselor read-only; iOS; final state; depinde M123.
- M126: clasifica CNError authorization; iOS; diagnostic; depinde M120.
- M127: clasifica recordDoesNotExist; iOS; stale; depinde M120.
- M128: clasifica validation errors; iOS; plan invalid; depinde M120.
- M129: nu retry automat save distructiv; iOS; idempotenta; depinde journal.
- M130: returneaza report fara PII; iOS; privacy; depinde M120.
- M131: limiteaza payload MethodChannel; iOS; robustness; depinde M101.
- M132: valideaza tipurile map/list din Flutter; iOS; input safety; depinde M101.
- M133: executa acces Contacts off main thread unde sigur; iOS; responsiveness; depinde M101.
- M134: livreaza result MethodChannel pe thread corect; iOS; Flutter contract; depinde M133.
- M135: mentine merge distructiv dezactivat pana la validarea fizica pe device; iOS/UI; release safety; depinde M101-M134.

## M136-M175 - Conservarea completa a campurilor in MergePlan - P0/P1

- M136: adauga option builder pentru givenName; merge detail; no data loss.
- M137: adauga middleName; merge detail.
- M138: adauga familyName; merge detail.
- M139: adauga prefix; merge detail.
- M140: adauga suffix; merge detail.
- M141: adauga phone labels in selected field metadata; plan.
- M142: adauga extensions in phone selection; plan.
- M143: adauga email labels; plan.
- M144: adauga address fields tipizate; plan.
- M145: adauga address label; plan.
- M146: adauga company option; plan.
- M147: adauga department option; plan.
- M148: adauga jobTitle option; plan.
- M149: adauga birthday option; plan.
- M150: trateaza birthday ca date-only; normalizer/model.
- M151: adauga favorite option; plan.
- M152: reprezinta note prin availability + fingerprint, nu continut persistat; plan/privacy.
- M153: reprezinta photo prin availability + fingerprint, nu bytes persistati; plan/privacy.
- M154: detecteaza scalar mismatch given name; conflicts.
- M155: detecteaza family name mismatch; conflicts.
- M156: detecteaza birthday conflict; conflicts.
- M157: detecteaza multiple photo conflict; conflicts.
- M158: detecteaza organization conflict; conflicts.
- M159: cere selectie explicita pentru conflict required; validator.
- M160: nu auto-selecteaza valoare din grup manual-review; factory.
- M161: conserva provenance per field; factory.
- M162: sorteaza provenance determinist; model.
- M163: deduplica option dupa canonical value + kind; factory.
- M164: nu deduplica valori semantic diferite cu acelasi display; factory.
- M165: genereaza skip reason pentru invalid values; factory.
- M166: genereaza skip reason pentru unsupported; factory.
- M167: genereaza skip reason pentru read-only constraints; factory.
- M168: include toate skip reasons in counters; plan.
- M169: fingerprint plan include metadata structurala necesara; plan.
- M170: fingerprint nu include PII brut persistabil; plan/privacy.
- M171: validator cere provenance source existent; validator.
- M172: validator cere canonical value pentru tipurile canonice; validator.
- M173: validator verifica un singur displayName final; validator.
- M174: validator blocheaza orice camp bogat pe care gatewayul nu il poate conserva; validator/gateway.
- M175: UI afiseaza explicit campurile care ar fi pierdute si blocheaza merge; details/editor.

## M176-M210 - Restore/undo robust - P0/P1

- M176: leaga RestoreController in bootstrap; main/providers; feature existent.
- M177: foloseste acelasi ContactBackupService protejat ca BackupController; DI; consistency.
- M178: leaga OperationHistoryRepository comun; DI; undo linkage.
- M179: adauga ruta restore din backup; router; feature existent.
- M180: adauga ruta undo din history; router; feature existent.
- M181: preview restore afiseaza count fara PII in logs; UI/privacy.
- M182: target IDs sunt validate inainte de preview; restore service.
- M183: targeted restore respinge set gol; restore service.
- M184: full restore cere confirmare distincta; controller/UI.
- M185: revalideaza source backup imediat inainte de create; service.
- M186: verifica safety backup content, nu doar isValid; service.
- M187: leaga safety backup de operation history; history.
- M188: nu permite stergerea safety backup cat timp undo este posibil; backup/history.
- M189: captureaza create ID pentru fiecare restore item; service.
- M190: verifica exact contactul recreat prin ID nou; service.
- M191: compara fingerprint fara nativeId original pentru restore; model/service.
- M192: separa identity fingerprint de content fingerprint; contact model.
- M193: rollback sterge numai ID-urile create de operatia curenta; service.
- M194: rollback verifica absenta fiecarui ID creat; service.
- M195: timeout create produce reconcile, nu rollback presupus; service.
- M196: timeout delete rollback produce reconcile; service.
- M197: jurnal restore inainte de prima mutatie; service/repository.
- M198: checkpoint restore dupa fiecare create verificat; service.
- M199: crash restore se deschide in reconcile; controller.
- M200: cancellation ramane dezactivata in critical section; controller/service.
- M201: cancellation intre batchuri opreste fara a anula contacte deja confirmate; service/report.
- M202: report distinge restored/skipped/conflict/invalid; report.
- M203: conflict policy block nu creeaza nimic; service.
- M204: skipExisting nu modifica existing; service.
- M205: restoreMissingOnly nu suprascrie existing; service.
- M206: reciteste live state dupa permission prompt; service.
- M207: detecteaza source state change fata de preview; service.
- M208: invalideaza preview dupa schimbarea backup list; controller.
- M209: invalideaza preview dupa app resume; lifecycle/controller.
- M210: history entry restore foloseste timpi reali ai operatiei, nu acelasi `now`; report/history.

## M211-M235 - Istoric si undo integrat - P1

- M211: leaga HistoryController in bootstrap; main.
- M212: incarca history o singura data la startup; controller.
- M213: adauga ecran history; feature existent.
- M214: afiseaza type/outcome/count fara PII; UI.
- M215: filtre type functionale; history UI.
- M216: filtre outcome functionale; history UI.
- M217: filtru undoable functioneaza; history UI.
- M218: ruta history accesibila fara a mari bottom nav peste 4; router/settings.
- M219: history refresh dupa merge; coordination.
- M220: history refresh dupa restore; coordination.
- M221: history refresh dupa undo; coordination.
- M222: undo action cere backup protejat existent; history/backup.
- M223: undo action cere confirmare explicita; UI.
- M224: undo foloseste RestoreMode targeted/full conform operatiei; controller.
- M225: entry canUndo expira cand backupul dispare; repository/controller.
- M226: entry canUndo se actualizeaza dupa undo reusit; repository.
- M227: previne undo dublu pentru aceeasi operatie; repository.
- M228: pastreaza legatura undo parent/child opaca; model.
- M229: clear history pastreaza undoable implicit; existent, de verificat UI.
- M230: delete entry refuza undoable; existent, de verificat UI.
- M231: retentia nu elimina dependinta backup activa; repository.
- M232: compactarea nu depaseste maxEntries pentru intrari neprotejate; repository.
- M233: coruptia unei intrari nu sterge intrarile valide; parser/repository.
- M234: coruptia envelope este reparata atomic; repository.
- M235: storage history ramane sub limita configurata prin compactare inainte de write; repository.

## M236-M255 - Backup lifecycle si protectia undo - P1

- M236: BackupController primeste protectedBackupIds provider; DI.
- M237: delete backup protejat este blocat; backup controller.
- M238: UI explica backup folosit pentru undo; backup screen.
- M239: cleanup automat exclude backupuri protejate; service.
- M240: retentie backup configurabila local; service.
- M241: backup invalid poate fi sters chiar daca apare in history ne-undoable; policy.
- M242: safety backup are tip/metadata distincta fara PII; model.
- M243: merge backup are metadata purpose; model.
- M244: restore backup are metadata purpose; model.
- M245: inspect file verifica purpose enum; backup parser.
- M246: schema version pregateste migrare metadata purpose; backup service.
- M247: migrarea v1 citeste compatibil backupurile existente; backup service.
- M248: create foloseste write temp + rename atomic in acelasi director; existent, reverificare.
- M249: temp stale este curatat controlat; backup service.
- M250: fisiere straine din director sunt ignorate; existent, reverificare.
- M251: symlinkurile nu sunt urmate la listare/protectie; backup service.
- M252: iOS exclude numai root + fisiere validate; bridge/service.
- M253: iOS reverifica exclude flag; implementat, adauga test nativ/manual.
- M254: Android backup ramane dezactivat in manifest; release audit.
- M255: stergerea backup confirma absenta fisierului dupa delete; service.

## M256-M270 - Permisiuni, lifecycle, concurenta - P1

- M256: WRITE_CONTACTS se cere numai dupa confirmare merge; flow.
- M257: restore cere WRITE numai dupa confirmare; flow.
- M258: revenirea din Settings invalideaza permission snapshot; lifecycle.
- M259: resume invalideaza scan results daca agenda poate fi schimbata extern; lifecycle.
- M260: merge running blocheaza scan nou; coordination.
- M261: restore running blocheaza scan nou; coordination.
- M262: backup create nu ruleaza simultan cu merge mutation; coordination.
- M263: backup delete nu ruleaza simultan cu restore; coordination.
- M264: history write nu poate bloca finalizarea nativa; controller.
- M265: history failure ramane observabil; controller.
- M266: dispose nu lasa callback progress sa notifice; controller.
- M267: cancellation token nu este reutilizat intre operatii; controller.
- M268: operation IDs sunt unice local si validate; factory.
- M269: scanRevision este capturat la prepare si reverificat la confirm; controller.
- M270: groupRevisionFingerprint este reverificat chiar inainte de engine; controller.

## M271-M285 - UX tehnic si accesibilitate - P1/P2

- M271: actiunea distructiva are semantic label explicit; merge UI.
- M272: confirm dialog anunta surse sterse/read-only pastrate; merge UI.
- M273: progres merge are semantics live region; UI.
- M274: reconcile state are actiune clara, nu retry distructiv; UI.
- M275: buton cancel este ascuns/dezactivat in critical phase; UI.
- M276: tap targets critice minimum 44x44; shared widgets.
- M277: text scaling 200% nu taie confirmarea; dialog/layout.
- M278: ecranele merge/restore folosesc scroll pentru keyboard/text scale; UI.
- M279: statusurile nu sunt comunicate exclusiv prin culoare; UI.
- M280: focus order confirmare este determinist; accessibility.
- M281: screen reader citeste scor + motiv + risc; duplicates UI.
- M282: read-only badge are text explicit; details UI.
- M283: limited access badge are text explicit; duplicates UI.
- M284: history entry are semantic summary fara PII; history UI.
- M285: reduced motion este respectat in progres/transition; UI.

## M286-M300 - Privacy, securitate si release robustness - P1

- M286: audit static interzice print/log cu contact values in codul de productie; code audit.
- M287: erorile native nu includ contact ID in message; native bridge.
- M288: MethodChannel payload nu include account name/email; Android; implementat partial, reverificare.
- M289: storage iOS respinge cale din afara Application Support/contact_backups; implementat, reverificare.
- M290: storage iOS rezolva symlink inainte de prefix check; implementat, reverificare.
- M291: storage iOS verifica exact root boundary, nu prefix lexical; implementat, reverificare.
- M292: backup key errors nu expun key material; backup service audit.
- M293: history nu persista displayName/phone/email; repository audit.
- M294: merge journal nu persista selected values; journal audit.
- M295: restore journal nu persista contact JSON; restore journal.
- M296: toate fisierele locale sensibile sunt in application support intern; storage audit.
- M297: privacy claims raman conforme cu lipsa uploadului; release audit.
- M298: nu se adauga analytics/crash SDK; dependency audit.
- M299: store checklist este verificat fata de comportamentul real dupa merge/restore; release audit.
- M300: se produce go/no-go tehnic numai dupa build/test pe Android si iOS fizic, inclusiv read-only si rollback; release verification.

## Criteriu de finalizare

Executia urmatoare poate marca M001-M300 finalizate numai dupa implementare efectiva, verificare statica, build/test unde runtime-ul permite, audit Git diff si commit real pe `main`. Orice punct deja satisfacut integral de baza se marcheaza preexistent si se inlocuieste cu o problema tehnica reala descoperita in audit, astfel incat totalul implementat in runda urmatoare sa ramana minimum 300.

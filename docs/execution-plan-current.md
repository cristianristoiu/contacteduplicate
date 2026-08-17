# Plan executie curenta

Baza analizata: `main` la `a1c3118e34b6080ef184f4b6113468f84f49c679` (`CHT0265`).

Reguli de contorizare: M001-M300 sunt rezultate tehnice distincte. Testele, documentatia, textele, formatarea si modificarile cosmetice nu se contorizeaza. M001-M060 inlocuiesc punctele deja inchise de CHT0265. M061-M300 sunt revalidate pe codul curent si raman nefinalizate.

## M001-M060 - Contract MergePlan, integritate si fail-closed - P0

- M001 | Problema: operationId accepta orice text | Modificare: impune identificator opac cu format/lungime limitata | Zona: `merge_plan.dart` | Motiv: idempotenta | Finalizat cand ID invalid este respins.
- M002 | Problema: groupId nu este validat la nivel de plan | Modificare: valideaza formatul `group-*` | Zona: merge plan | Motiv: evita plan atasat altui grup | Finalizat cand grup invalid este respins.
- M003 | Problema: backupId permite zero si valori arbitrare | Modificare: cere ID numeric strict pozitiv | Zona: merge plan | Motiv: referinta backup valida | Finalizat cand `0`/negativ/non-numeric sunt respinse.
- M004 | Problema: constructorul deduplica silentios source IDs | Modificare: pastreaza semnalul de duplicate si validator dedicat | Zona: merge plan | Motiv: contract strict | Finalizat cand intrarea duplicata nu este mascata.
- M005 | Problema: optionId duplicate pot ascunde campuri diferite | Modificare: valideaza unicitatea globala | Zona: merge plan | Motiv: selectie determinista | Finalizat cand duplicate optionId sunt respinse.
- M006 | Problema: pot exista zero sau mai multe displayName selectate | Modificare: cere exact un displayName final | Zona: merge plan | Motiv: contact final coerent | Finalizat cand cardinalitatea !=1 este respinsa.
- M007 | Problema: campurile de nume structurat nu cer provenance | Modificare: cere sursa valida pentru given/middle/family/prefix/suffix | Zona: merge plan | Motiv: auditabilitate | Finalizat cand provenance lipsa este respinsa.
- M008 | Problema: birthday poate contine componenta de timp | Modificare: reprezinta birthday date-only | Zona: merge plan/model | Motiv: evita shift timezone | Finalizat cand timpul este eliminat din canonizare.
- M009 | Problema: birthday nu are canonical value stabil | Modificare: canonical ISO `yyyy-mm-dd` | Zona: merge plan | Motiv: comparatie cross-platform | Finalizat cand acelasi birthday are aceeasi cheie.
- M010 | Problema: address poate fi identificata doar prin display | Modificare: canonical structural pentru address | Zona: merge plan | Motiv: deduplicare corecta | Finalizat cand adresele echivalente au aceeasi cheie.
- M011 | Problema: telefonul selectat pierde label | Modificare: metadata label/extension in selected field | Zona: merge plan | Motiv: fidelitate | Finalizat cand gatewayul poate primi metadata.
- M012 | Problema: emailul selectat pierde label | Modificare: metadata label in selected field | Zona: merge plan | Motiv: fidelitate | Finalizat cand labelul este conservat.
- M013 | Problema: organization este aplatizata | Modificare: metadata company/department/jobTitle | Zona: merge plan | Motiv: fidelitate | Finalizat cand structura este reprezentata.
- M014 | Problema: favorite nu are valoare canonica tipizata | Modificare: boolean metadata | Zona: merge plan | Motiv: consistenta | Finalizat cand favorite este validat tipizat.
- M015 | Problema: note ar putea persista continut PII | Modificare: doar availability/fingerprint opac | Zona: merge plan/privacy | Motiv: minimizare date | Finalizat cand textul notei nu intra in fingerprint/jurnal.
- M016 | Problema: photo ar putea persista bytes | Modificare: doar availability/fingerprint opac | Zona: merge plan/privacy | Motiv: minimizare date | Finalizat cand bytes nu intra in plan persistabil.
- M017 | Problema: skippedFields nu participa la identitatea planului | Modificare: include reason/kind/fingerprint opac | Zona: merge plan | Motiv: plan complet | Finalizat cand skip diferit schimba fingerprintul.
- M018 | Problema: conflictul poate selecta option din alt field | Modificare: verifica field-kind al optiunilor | Zona: validator | Motiv: integritate | Finalizat cand cross-field selection este respinsa.
- M019 | Problema: conflict cu <2 optiuni poate fi creat | Modificare: cardinalitate minima 2 | Zona: conflict model | Motiv: semantica | Finalizat cand conflict trivial este invalid.
- M020 | Problema: grup manual-review poate primi selectie implicita | Modificare: flag explicit `requiresManualReview` in plan | Zona: plan/factory | Motiv: regula produs | Finalizat cand auto-selectia este blocata.
- M021 | Problema: capabilitate unknown poate ajunge la delete | Modificare: fail-closed pentru destructive mode | Zona: validator | Motiv: siguranta | Finalizat cand unknown blocheaza stergerea.
- M022 | Problema: read-only source poate fi tinta delete | Modificare: separa deletionTargets de retainedSources | Zona: plan | Motiv: nu forta read-only | Finalizat cand read-only nu intra in delete.
- M023 | Problema: field bogat unsupported poate fi ignorat silentios | Modificare: safety blocker obligatoriu | Zona: plan/validator | Motiv: no silent data loss | Finalizat cand unsupported blocheaza destructive merge.
- M024 | Problema: snapshot fingerprint nu este reverificat de validator | Modificare: recalculeaza din sourceRecords | Zona: validator | Motiv: stale safety | Finalizat cand mismatch este respins.
- M025 | Problema: createdAt din viitor este acceptat | Modificare: limita clock-skew | Zona: validator | Motiv: integritate temporala | Finalizat cand timestamp imposibil este respins.
- M026 | Problema: planul poate fi reutilizat nelimitat | Modificare: max age configurabil | Zona: validator | Motiv: TOCTOU | Finalizat cand plan expirat este respins.
- M027 | Problema: source IDs nu au ordine contractuala explicita | Modificare: ordine sortata si expusa imutabil | Zona: plan | Motiv: determinism | Finalizat cand permutarile dau aceeasi reprezentare.
- M028 | Problema: selectedFields depind de ordinea UI | Modificare: sortare determinista dupa kind/canonical/id | Zona: plan | Motiv: fingerprint stabil | Finalizat cand ordinea UI nu schimba planul.
- M029 | Problema: conflicts depind de ordinea producerului | Modificare: sortare determinista | Zona: plan | Motiv: reproducibilitate | Finalizat cand permutarile nu schimba fingerprintul.
- M030 | Problema: skippedFields depind de ordinea producerului | Modificare: sortare determinista | Zona: plan | Motiv: reproducibilitate | Finalizat cand permutarile nu schimba fingerprintul.
- M031 | Problema: fingerprint ignora skip reasons | Modificare: include skip identity | Zona: plan | Motiv: identitate completa | Finalizat cand skip diferit schimba fingerprintul.
- M032 | Problema: fingerprint poate include displayValue PII | Modificare: foloseste exclusiv canonical/opac | Zona: plan/privacy | Motiv: privacy | Finalizat cand displayValue nu participa.
- M033 | Problema: generarea operationId nu este centralizata | Modificare: factory opac determinist+nonce timestamp | Zona: plan factory | Motiv: unicitate | Finalizat cand controllerul poate cere ID valid.
- M034 | Problema: snapshot foloseste doar revision sau ID | Modificare: include content fingerprint live | Zona: factory | Motiv: detecteaza schimbari | Finalizat cand continut diferit schimba snapshot.
- M035 | Problema: group fingerprint poate lipsi din contextul validatorului | Modificare: expected fingerprint obligatoriu pentru destructive | Zona: validator | Motiv: stale group | Finalizat cand context lipsa blocheaza destructive.
- M036 | Problema: selected canonical values pot fi ne-normalizate | Modificare: validare per kind | Zona: validator | Motiv: consistenta gateway | Finalizat cand canonical invalid este respins.
- M037 | Problema: doua campuri acelasi kind/canonical pot fi selectate | Modificare: reject duplicate canonical semantic | Zona: validator | Motiv: nu scrie duplicate | Finalizat cand duplicatul este respins.
- M038 | Problema: acelasi display in kind-uri diferite poate fi deduplicat gresit | Modificare: identity include kind | Zona: selected field | Motiv: semantica | Finalizat cand valori cross-kind raman distincte.
- M039 | Problema: master cu ID instabil poate fi ales | Modificare: cere stable identity pentru master | Zona: validator | Motiv: readback sigur | Finalizat cand master instabil este respins.
- M040 | Problema: destructive merge poate sa nu aiba nicio tinta de stergere | Modificare: cere cel putin o deletion target | Zona: validator | Motiv: evita operatii fara sens | Finalizat cand destructive fara delete este invalid.
- M041 | Problema: tintele de stergere sunt deduse implicit | Modificare: lista explicita `deletionTargetIds` | Zona: plan | Motiv: audit/recovery | Finalizat cand engine primeste tinte exacte.
- M042 | Problema: sursele pastrate sunt deduse implicit | Modificare: lista explicita `retainedSourceIds` | Zona: plan | Motiv: read-only/copy fallback | Finalizat cand sursele pastrate sunt declarate.
- M043 | Problema: planul nu distinge copy-only de destructive | Modificare: enum `MergeExecutionMode` | Zona: plan | Motiv: fail-closed iOS | Finalizat cand modul este explicit.
- M044 | Problema: planul nu exprima nivelul de capabilitate | Modificare: enum safety capability | Zona: plan | Motiv: decizie cross-platform | Finalizat cand unknown/readOnly/writable sunt agregate.
- M045 | Problema: unsupported fields nu sunt agregate | Modificare: lista fingerprints/kinds unsupported | Zona: plan | Motiv: UI blocker | Finalizat cand sunt expuse.
- M046 | Problema: safety blockers sunt dispersate | Modificare: model `MergeSafetyBlocker` | Zona: plan | Motiv: diagnostic | Finalizat cand validatorul intoarce blocker precis.
- M047 | Problema: codurile de validare sunt prea generale | Modificare: coduri distincte pentru mod/timestamp/snapshot/capability | Zona: validator | Motiv: diagnostic/retry | Finalizat cand fiecare clasa P0 are cod separat.
- M048 | Problema: counters nu arata delete/retained | Modificare: adauga counters | Zona: plan | Motiv: confirmare corecta | Finalizat cand UI poate raporta exact.
- M049 | Problema: conflict selectat poate indica field neselectat | Modificare: selected option trebuie sa existe in selectedFields | Zona: validator | Motiv: integritate | Finalizat cand referinta moarta este respinsa.
- M050 | Problema: optiunile conflictuale nealese dispar fara motiv | Modificare: skip reason `conflictAlternative` | Zona: plan | Motiv: audit | Finalizat cand alternativele sunt reprezentate.
- M051 | Problema: group revision nu include surse sortate explicit | Modificare: helper de fingerprint contextual | Zona: plan factory | Motiv: determinism | Finalizat cand ordinea surselor nu conteaza.
- M052 | Problema: snapshot nu reflecta capability change | Modificare: include update/delete capability in context fingerprint | Zona: factory | Motiv: TOCTOU | Finalizat cand writability schimbata invalideaza planul.
- M053 | Problema: nu exista metoda de verificare a contextului planului | Modificare: `matchesContext` | Zona: plan | Motiv: controller simplu si sigur | Finalizat cand contextul poate fi reverificat atomic.
- M054 | Problema: copyWith poate modifica accidental identitatea | Modificare: interzice schimbarea operation/group/snapshot | Zona: plan | Motiv: idempotenta | Finalizat cand doar selectii permise se schimba.
- M055 | Problema: conflict resolution poate muta lista originala | Modificare: colectii deep-unmodifiable | Zona: plan | Motiv: state safety | Finalizat cand mutarea externa esueaza.
- M056 | Problema: provenance poate contine ordine/duplicate | Modificare: sort/dedup strict si semnal duplicate | Zona: selected field | Motiv: audit | Finalizat cand provenance este determinist.
- M057 | Problema: provenance poate avea cardinalitate excesiva | Modificare: limita la source count si validator | Zona: validator | Motiv: payload safety | Finalizat cand provenance imposibila este respinsa.
- M058 | Problema: canonicalValue nelimitat poate umfla jurnalul | Modificare: limite per kind | Zona: validator | Motiv: storage safety | Finalizat cand oversized este respins.
- M059 | Problema: displayValue nelimitat poate umfla MethodChannel | Modificare: limita de lungime | Zona: validator | Motiv: payload safety | Finalizat cand oversized este respins.
- M060 | Problema: operationId nelimitat poate umfla storage/bridge | Modificare: max 96 caractere | Zona: validator | Motiv: payload safety | Finalizat cand oversized este respins.

## M061-M100 - Tranzactie nativa Android - P0

- M061: valideaza contactId numeric si pozitiv in bridge; Android; input safety; criteriu: zero/negativ/non-numeric respins.
- M062: verifica READ_CONTACTS inainte de query metadata; Android; permisiuni; criteriu: query nu ruleaza fara grant.
- M063: verifica WRITE_CONTACTS inainte de operatie distructiva; Android; permisiuni; criteriu: mutatia nu porneste fara grant.
- M064: clasifica raw contacts writable/read-only/mixed; Android; criteriu: aggregate mixed este explicit.
- M065: blocheaza aggregate mixed pentru delete; Android; criteriu: mixed nu este sters.
- M066: exclude raw contacts marcate DELETED; Android; criteriu: metadata foloseste numai live rows.
- M067: identifica profile raw contact si il blocheaza pentru merge; Android; criteriu: profilul utilizatorului nu devine tinta.
- M068: returneaza numai metadata non-PII necesara; Android bridge; criteriu: fara nume/telefon/email.
- M069: limiteaza numarul raw contacts returnat; Android; criteriu: payload bounded.
- M070: valideaza tipurile MethodChannel args; Android; criteriu: type mismatch => error structurat.
- M071: adauga metoda native preflight pentru set de contacte; Android; criteriu: batch preflight disponibil.
- M072: returneaza capabilitati batch ordonate dupa request; Android; criteriu: rezultat determinist.
- M073: detecteaza contact disparut in batch preflight; Android; criteriu: missing explicit.
- M074: detecteaza raw-contact set schimbat intre scan si write; Android; criteriu: fingerprint metadata.
- M075: adauga operation token la bridge; Android; criteriu: toate mutatiile cer token.
- M076: valideaza operation token format/lungime; Android; criteriu: token invalid respins.
- M077: adauga preflight native imediat inainte de apply; Android; criteriu: stale blocks write.
- M078: construieste ContentProviderOperation pentru create rezultat; Android; criteriu: create batch real.
- M079: scrie structured name, nu displayName in first name; Android; criteriu: given/family separat.
- M080: scrie telefoanele cu label/type suportat; Android; criteriu: label conservat.
- M081: scrie emailurile cu label/type suportat; Android; criteriu: label conservat.
- M082: scrie adresele suportate; Android; criteriu: address rows create.
- M083: scrie organizatia/department/job title; Android; criteriu: organization row complet.
- M084: scrie birthday daca reprezentabil; Android; criteriu: event birthday date-only.
- M085: scrie note numai daca contractul permite sigur; Android; criteriu: skip explicit altfel.
- M086: conserva favorite/starred; Android; criteriu: STARRED pe aggregate rezultat.
- M087: trateaza fotografia separat cu limita payload; Android; criteriu: oversized respins/skipped.
- M088: nu include camp unsupported fara skip reason; Android/plan; criteriu: no silent loss.
- M089: foloseste applyBatch pentru mutatiile compatibile; Android; criteriu: provider transaction.
- M090: verifica rezultatul fiecarei ContentProviderOperation; Android; criteriu: rezultat incomplet => failure.
- M091: obtine ID-ul contactului rezultat din batch; Android; criteriu: created ID verificabil.
- M092: reciteste rezultatul dupa batch; Android; criteriu: readback obligatoriu.
- M093: compara fingerprint rezultat cu planul; Android; criteriu: mismatch => verification failure.
- M094: clasifica OperationApplicationException; Android; criteriu: cod distinct.
- M095: clasifica RemoteException; Android; criteriu: unknown-state distinct.
- M096: nu retry automat batch distructiv; Android; criteriu: un singur apply per token.
- M097: verifica sursele dupa batch; Android; criteriu: final state report.
- M098: pastreaza read-only sources neatinse; Android; criteriu: retained remain.
- M099: returneaza report nativ fara valori PII; Android; criteriu: doar counts/status/opac IDs unde necesar recovery.
- M100: inchide cursor/resurse pe orice cale de eroare; Android; criteriu: toate query folosesc use/finally.

## M101-M135 - Siguranta merge iOS - P0/P1

- M101: adauga bridge Contacts dedicat iOS; criteriu: channel separat functional.
- M102: foloseste numai API-uri publice Contacts; criteriu: CNContactStore/CNSaveRequest.
- M103: valideaza identifier input; criteriu: gol/oversized respins.
- M104: batch fetch pentru source identifiers; criteriu: un fetch request bounded.
- M105: detecteaza contact lipsa; criteriu: missing explicit.
- M106: trateaza authorization limited corect; criteriu: scope propagat.
- M107: nu presupune writability daca API-ul nu o poate demonstra; criteriu: unknown implicit.
- M108: blocheaza merge distructiv pentru writability necunoscuta; criteriu: destructive disabled.
- M109: permite numai copy consolidat cand delete nu poate fi garantat; criteriu: copy-only fallback.
- M110: construieste CNMutableContact din MergePlan; criteriu: contact rezultat tipizat.
- M111: conserva structured name; criteriu: componente separate.
- M112: conserva phones + labels; criteriu: CNLabeledValue.
- M113: conserva emails + labels; criteriu: CNLabeledValue.
- M114: conserva postal addresses; criteriu: CNMutablePostalAddress.
- M115: conserva organization fields; criteriu: organization/department/jobTitle.
- M116: conserva birthday fara shift timezone; criteriu: DateComponents.
- M117: conserva note numai daca API permite; criteriu: fail-safe/skip explicit.
- M118: conserva imageData numai in limite; criteriu: payload bounded.
- M119: conserva contact type unde relevant; criteriu: person/organization corect.
- M120: foloseste CNSaveRequest pentru create; criteriu: save real.
- M121: nu adauga delete actions daca writability nu e demonstrata; criteriu: fail-closed.
- M122: executa un singur save request pentru actiunile permise; criteriu: no implicit retry.
- M123: reciteste contactul creat dupa save; criteriu: readback.
- M124: compara fingerprint rezultat; criteriu: mismatch explicit.
- M125: verifica prezenta surselor read-only; criteriu: retained verified.
- M126: clasifica CNError authorization; criteriu: cod distinct.
- M127: clasifica recordDoesNotExist; criteriu: stale distinct.
- M128: clasifica validation errors; criteriu: plan invalid distinct.
- M129: nu retry automat save distructiv; criteriu: idempotenta.
- M130: returneaza report fara PII; criteriu: status/count only.
- M131: limiteaza payload MethodChannel; criteriu: bounded list/string/image.
- M132: valideaza tipurile map/list din Flutter; criteriu: malformed respins.
- M133: executa acces Contacts off main thread unde sigur; criteriu: UI thread neblocat.
- M134: livreaza result MethodChannel pe thread corect; criteriu: callback main.
- M135: mentine merge distructiv dezactivat pana la validarea fizica pe device; criteriu: capability gate explicit.

## M136-M175 - Conservarea campurilor in MergePlan - P0/P1

- M136: option builder givenName; criteriu: camp selectabil.
- M137: option builder middleName; criteriu: camp selectabil.
- M138: option builder familyName; criteriu: camp selectabil.
- M139: option builder prefix; criteriu: camp selectabil.
- M140: option builder suffix; criteriu: camp selectabil.
- M141: phone labels in metadata; criteriu: label pastrat.
- M142: phone extensions in metadata; criteriu: extension pastrata.
- M143: email labels in metadata; criteriu: label pastrat.
- M144: address fields tipizate; criteriu: structura completa.
- M145: address label; criteriu: label pastrat.
- M146: company option; criteriu: selectabil.
- M147: department option; criteriu: selectabil.
- M148: jobTitle option; criteriu: selectabil.
- M149: birthday option; criteriu: selectabil.
- M150: birthday date-only; criteriu: fara timezone shift.
- M151: favorite option; criteriu: selectabil.
- M152: note availability + fingerprint, fara text persistat; criteriu: privacy.
- M153: photo availability + fingerprint, fara bytes persistati; criteriu: privacy.
- M154: detecteaza scalar mismatch given name; criteriu: conflict.
- M155: detecteaza family name mismatch; criteriu: conflict.
- M156: detecteaza birthday conflict; criteriu: conflict.
- M157: detecteaza multiple photo conflict; criteriu: conflict.
- M158: detecteaza organization conflict; criteriu: conflict.
- M159: selectie explicita pentru conflict required; criteriu: unresolved blocks.
- M160: nu auto-selecteaza valoare din grup manual-review; criteriu: confirmare manuala.
- M161: conserva provenance per field; criteriu: source IDs.
- M162: sorteaza provenance determinist; criteriu: stable.
- M163: deduplica option canonical+kind; criteriu: fara duplicate.
- M164: pastreaza valori semantic diferite cu acelasi display; criteriu: kind-aware.
- M165: skip reason invalid values; criteriu: explicit.
- M166: skip reason unsupported; criteriu: explicit.
- M167: skip reason read-only constraints; criteriu: explicit.
- M168: include skip reasons in counters; criteriu: counts exacte.
- M169: fingerprint include metadata structurala necesara; criteriu: context complet.
- M170: fingerprint nu include PII brut persistabil; criteriu: privacy.
- M171: provenance source existent; criteriu: validator.
- M172: canonical obligatoriu pentru tipurile canonice; criteriu: validator.
- M173: exact un displayName final; criteriu: validator.
- M174: blocheaza field bogat neconservabil de gateway; criteriu: no data loss.
- M175: UI afiseaza campurile care s-ar pierde si blocheaza destructive merge; criteriu: blocker vizibil.

## M176-M210 - Restore/undo robust - P0/P1

- M176: leaga RestoreController in bootstrap; criteriu: provider unic.
- M177: acelasi ContactBackupService protejat ca BackupController; criteriu: DI shared.
- M178: OperationHistoryRepository comun; criteriu: DI shared.
- M179: ruta restore din backup; criteriu: navigabila.
- M180: ruta undo din history; criteriu: navigabila.
- M181: preview restore fara PII in logs; criteriu: count/status only.
- M182: valideaza target IDs inainte de preview; criteriu: malformed respins.
- M183: targeted restore respinge set gol; criteriu: invalid request.
- M184: full restore cere confirmare distincta; criteriu: explicit consent.
- M185: revalideaza source backup imediat inainte de create; criteriu: TOCTOU closed.
- M186: verifica safety backup content, nu doar isValid; criteriu: content validation.
- M187: leaga safety backup de operation history; criteriu: undo dependency.
- M188: nu sterge safety backup cat timp undo posibil; criteriu: protection.
- M189: captureaza create ID per restore item; criteriu: rollback exact.
- M190: verifica contact recreat prin ID nou; criteriu: readback.
- M191: fingerprint restore fara nativeId original; criteriu: content equality.
- M192: separa identity fingerprint de content fingerprint; criteriu: model explicit.
- M193: rollback sterge doar ID-uri create in operatia curenta; criteriu: no collateral delete.
- M194: rollback verifica absenta fiecarui ID creat; criteriu: verified rollback.
- M195: timeout create => reconcile, nu rollback presupus; criteriu: unknown state.
- M196: timeout delete rollback => reconcile; criteriu: unknown state.
- M197: jurnal restore inainte de prima mutatie; criteriu: crash safety.
- M198: checkpoint dupa fiecare create verificat; criteriu: precise recovery.
- M199: crash restore se deschide in reconcile; criteriu: no blind rerun.
- M200: cancellation dezactivata in critical section; criteriu: transaction safety.
- M201: cancellation intre batchuri opreste numai viitorul; criteriu: report partial explicit.
- M202: report distinge restored/skipped/conflict/invalid; criteriu: status counts.
- M203: conflict policy block nu creeaza nimic; criteriu: preflight fail.
- M204: skipExisting nu modifica existing; criteriu: read-only behavior.
- M205: restoreMissingOnly nu suprascrie existing; criteriu: no overwrite.
- M206: reciteste live state dupa permission prompt; criteriu: stale safe.
- M207: detecteaza source state change fata de preview; criteriu: mismatch blocks.
- M208: invalideaza preview dupa backup list change; criteriu: stale cleared.
- M209: invalideaza preview dupa app resume; criteriu: lifecycle safe.
- M210: history entry foloseste timpi reali start/end; criteriu: durata reala.

## M211-M235 - Istoric si undo integrat - P1

- M211: leaga HistoryController in bootstrap; criteriu: provider unic.
- M212: incarca history o singura data la startup; criteriu: no duplicate load.
- M213: adauga ecran history; criteriu: listare functionala.
- M214: afiseaza type/outcome/count fara PII; criteriu: privacy.
- M215: filtru type functional; criteriu: rezultat corect.
- M216: filtru outcome functional; criteriu: rezultat corect.
- M217: filtru undoable functional; criteriu: rezultat corect.
- M218: ruta history fara a mari bottom nav peste 4; criteriu: acces din setari/dashboard.
- M219: refresh history dupa merge; criteriu: intrare apare.
- M220: refresh history dupa restore; criteriu: intrare apare.
- M221: refresh history dupa undo; criteriu: stari actualizate.
- M222: undo cere backup protejat existent; criteriu: no missing dependency.
- M223: undo cere confirmare explicita; criteriu: explicit consent.
- M224: undo foloseste RestoreMode conform operatiei; criteriu: target corect.
- M225: canUndo expira cand backup dispare; criteriu: status corect.
- M226: canUndo se actualizeaza dupa undo reusit; criteriu: no second action.
- M227: previne undo dublu; criteriu: idempotenta.
- M228: pastreaza legatura parent/child opaca; criteriu: lineage fara PII.
- M229: clear history pastreaza undoable implicit; criteriu: protectie.
- M230: delete entry refuza undoable; criteriu: protectie.
- M231: retentia nu elimina dependinta backup activa; criteriu: undo preserved.
- M232: compactarea respecta maxEntries pentru neprotejate; criteriu: bounded storage.
- M233: coruptia unei intrari nu sterge intrarile valide; criteriu: partial recovery.
- M234: coruptia envelope reparata atomic; criteriu: temp+replace.
- M235: storage history compactat inainte de write; criteriu: max bytes.

## M236-M255 - Backup lifecycle si protectia undo - P1

- M236: BackupController primeste protectedBackupIds provider; criteriu: policy shared.
- M237: delete backup protejat blocat; criteriu: error explicit.
- M238: UI explica backup folosit pentru undo; criteriu: badge/text.
- M239: cleanup automat exclude protected; criteriu: no accidental delete.
- M240: retentie backup configurabila local; criteriu: bounded list.
- M241: backup invalid poate fi sters daca history nu il protejeaza; criteriu: cleanup possible.
- M242: safety backup are purpose distinct fara PII; criteriu: metadata.
- M243: merge backup are purpose distinct; criteriu: metadata.
- M244: restore backup are purpose distinct; criteriu: metadata.
- M245: parser verifica purpose enum; criteriu: invalid rejected.
- M246: schema version suporta purpose; criteriu: v2 envelope.
- M247: migrare v1 compatibila; criteriu: existing backups readable.
- M248: create ramane temp+rename atomic acelasi director; criteriu: atomic replace.
- M249: stale temp curatat controlat; criteriu: no orphan accumulation.
- M250: fisiere straine ignorate; criteriu: strict filename.
- M251: symlinkuri nu sunt urmate; criteriu: safe listing/protection.
- M252: iOS exclude numai root + fisiere validate; criteriu: strict path.
- M253: iOS reverifica exclude flag; criteriu: verified true.
- M254: Android allowBackup ramane false; criteriu: manifest audit.
- M255: delete backup confirma absenta fisierului; criteriu: readback file state.

## M256-M270 - Permisiuni, lifecycle, concurenta - P1

- M256: WRITE_CONTACTS cerut numai dupa confirmare merge; criteriu: deferred permission.
- M257: restore cere WRITE numai dupa confirmare; criteriu: deferred permission.
- M258: revenirea din Settings invalideaza permission snapshot; criteriu: resume hook.
- M259: resume invalideaza scan results daca agenda se poate schimba extern; criteriu: stale marker.
- M260: merge running blocheaza scan nou; criteriu: coordinator gate.
- M261: restore running blocheaza scan nou; criteriu: coordinator gate.
- M262: backup create nu ruleaza simultan cu merge mutation; criteriu: gate.
- M263: backup delete nu ruleaza simultan cu restore; criteriu: gate.
- M264: history write nu blocheaza finalizarea nativa; criteriu: operation result retained.
- M265: history failure observabil; criteriu: warning state.
- M266: dispose nu lasa progress callback sa notifice; criteriu: lifecycle safe.
- M267: cancellation token unic per operatie; criteriu: no reuse.
- M268: operation IDs unice local si validate; criteriu: factory.
- M269: scanRevision capturat la prepare si reverificat la confirm; criteriu: mismatch blocks.
- M270: groupRevisionFingerprint reverificat chiar inainte de engine; criteriu: mismatch blocks.

## M271-M285 - UX tehnic si accesibilitate - P1/P2

- M271: semantic label explicit actiune distructiva; criteriu: screen reader.
- M272: confirm dialog anunta surse sterse/read-only pastrate; criteriu: counts exacte.
- M273: progres merge semantics live region; criteriu: announcements.
- M274: reconcile state are actiune clara, nu retry distructiv; criteriu: safe CTA.
- M275: cancel ascuns/dezactivat in critical phase; criteriu: no cancellation unsafe.
- M276: tap targets critice min 44x44; criteriu: constraints.
- M277: text scaling 200% nu taie confirmarea; criteriu: scrollable dialog.
- M278: merge/restore scroll pentru keyboard/text scale; criteriu: no overflow.
- M279: statusurile nu sunt doar culoare; criteriu: icon+text.
- M280: focus order confirmare determinist; criteriu: traversal order.
- M281: screen reader citeste scor+motiv+risc; criteriu: semantic summary.
- M282: read-only badge are text explicit; criteriu: no color-only.
- M283: limited access badge are text explicit; criteriu: no color-only.
- M284: history entry semantic summary fara PII; criteriu: accessibility/privacy.
- M285: reduced motion respectat in progres/transition; criteriu: disableAnimations.

## M286-M300 - Privacy, securitate, release robustness - P1

- M286: cod productie fara print/log cu contact values; criteriu: audit static.
- M287: erori native fara contact ID in message; criteriu: generic message.
- M288: MethodChannel fara account name/email; criteriu: metadata allowlist.
- M289: storage iOS respinge path outside Application Support/contact_backups; criteriu: strict root.
- M290: storage iOS rezolva symlink inainte de check; criteriu: canonical path.
- M291: storage iOS verifica boundary exact, nu lexical prefix; criteriu: separator boundary.
- M292: backup key errors nu expun key material; criteriu: cod generic sigur.
- M293: history nu persista displayName/phone/email; criteriu: schema opaca.
- M294: merge journal nu persista selected values; criteriu: fingerprints/counts only.
- M295: restore journal nu persista contact JSON; criteriu: opaque IDs/counts only.
- M296: fisiere sensibile numai in Application Support intern; criteriu: directory providers interne.
- M297: comportamentul runtime ramane fara upload contacte; criteriu: dependency/network audit.
- M298: fara analytics/crash SDK; criteriu: dependency audit.
- M299: store checklist reflecta comportamentul real merge/restore; criteriu: audit release.
- M300: go/no-go tehnic numai dupa build/test Android+iOS fizic read-only/rollback; criteriu: daca runtime/device lipsesc, ramane blocker raportat, nu se declara ready.

## Criteriu executie

Fiecare ID se marcheaza finalizat numai dupa implementare efectiva si verificare. Daca un punct se dovedeste deja satisfacut integral, este inlocuit cu o problema tehnica reala din aceeasi prioritate, astfel incat totalul final al executiei sa ramana minimum 300.
# Verifica della consegna

## Eseguito nell’ambiente di sviluppo disponibile

- Integrità lessicale: delimitatori, stringhe, commenti e interpolazioni nei file Dart/Kotlin/Gradle.
- Esistenza degli import Dart locali.
- Parsing dei sei XML Android e dei tre file YAML di configurazione.
- Corrispondenza dei nove metodi Dart/Android del MethodChannel.
- Assenza del permesso Internet nel manifest release.
- Permesso di scrittura limitato alle API <= 28.
- Provider di condivisione non esportato e autorizzazione temporanea di lettura.
- Assenza di chiavi private nello ZIP.
- Controllo della sintassi Bash degli script di preparazione/compilazione.
- Revisione manuale di selezioni, intervalli uniti, copie, code di scrittura e calcolo degli spazi.

Il risultato ripetibile dei controlli di integrità è in `source-checks.json`.
Eseguirli nuovamente con `python tool/check_sources.py`, se Python è disponibile.
Questi controlli **non equivalgono a un parser Dart completo o a una compilazione**.

## Non eseguito: richiede Flutter/Android SDK

- `flutter analyze`
- `flutter test`
- `flutter build apk --release`
- Installazione e uso su Samsung/Android
- Verifica visiva dei PNG rasterizzati da Flutter
- Verifica del selettore logo, galleria e condivisione con app reali

Gli SDK non erano installati; la richiesta HTTPS per scaricare Flutter è scaduta
senza connessione. Non è incluso alcun APK né è dichiarata una build riuscita.

## Test predisposti

| File | Casi |
|---|---|
| `test/editor_test.dart` | 150 celle indipendenti, merge reversibile, copia di gruppi/merge/stili, incolla fuori griglia/parziale, undo/redo, eliminazione assi, area usata, duplicazione, limiti, snapshot malformati |
| `test/storage_test.dart` | Ordine delle revisioni, errore disco/riprova, eliminazione senza race con autosave |
| `test/poster_test.dart` | PNG 1080×1920, workout corto/denso, opzionali vuoti, merge, errori su contenuto eccessivo |
| `test/app_test.dart` | Home → template → editor → input → GROUP → autosave → Home |

Il test di rendering scrive `build/qa/short.png` e `build/qa/dense.png`. Devono essere
aperti e ispezionati dopo l’esecuzione. I test Flutter possono usare il font di test
Ahem: per valutare lo stile reale, esportare anche gli esempi da un dispositivo.

## Prova di accettazione su telefono (da effettuare)

1. Avvia in modalità aereo, crea EMPTY: verifica 15×10.
2. Tocca A1, scrivi SQUAT, spostati con tutte le frecce e Next.
3. Seleziona A1:B3, GROUP; verifica bordo esterno, poi UNGROUP e UNDO.
4. Inserisci due testi, MERGE; conferma, poi UNMERGE e verifica entrambi i testi.
5. Copia A1:C4, incolla in E6: confronta testo, bold, merge e gruppi.
6. Verifica riga/colonna/intervallo, long press + drag e pinch to zoom.
7. Ridimensiona colonne e righe. Aggiungi fino a 20×12; verifica i limiti.
8. Elimina una riga interna a un gruppo/merge e verifica UNDO.
9. Digita, attendi SALVATO, chiudi forzatamente e riapri: recupera l’ultima revisione.
10. Duplica un workout: cambia una cella nella copia, verifica che l’originale resti uguale.
11. Carica un PNG trasparente. Riavvia l’app e verifica la permanenza del logo.
12. Genera una grafica senza opzionali e una con titolo lungo, note, reps e difficulty.
13. Controlla un workout 4×3 e uno 14×8, nome lungo incluso; verifica leggibilità e assenza di sovrapposizioni.
14. Genera e premi CLOSE: verifica che non sia comparso un file in galleria.
15. SAVE IMAGE PNG: verifica album YOKAI e dimensioni 1080×1920. Ripeti JPG.
16. SHARE senza SAVE: invia tramite un’app installata; verifica apertura del file e nessun salvataggio aggiunto in galleria.
17. Android 8/9: nega il permesso di salvataggio, verifica l’errore e riprova. Android 10+: nessun permesso generale richiesto.
18. Attiva caratteri grandi e prova con tastiera aperta. Verifica controlli raggiungibili e nessun overflow.
19. Prova disco pieno/errore simulato: RIPROVA deve restare visibile; l’editor non deve fingere SALVATO.
20. Modifica un vecchio workout, cambia data, chiudi e riapri; prova eliminazione con annullamento e conferma.

## Decisioni tecniche

- Persistenza: un JSON versionato per workout, in spazio privato Android, scritto
  con `AtomicFile` su un executor a thread singolo. Lo snapshot viene catturato
  subito a ogni modifica e le scritture sono ordinate. I fallimenti rimangono
  riprovabili; un archivio illeggibile non viene sovrascritto con uno vuoto.
- Il processo può essere terminato prima che un’operazione in corso venga
  confermata: la garanzia di persistenza è sullo stato indicato come SALVATO.
- Merge non distruttivo: il solo contenuto della cella superiore sinistra viene
  disegnato; gli altri contenuti restano nel modello fino a CLEAR o eliminazione.
- Copia/incolla interna mantiene i blocchi; un incolla che taglia una cella unita
  esistente viene rifiutato con spiegazione, prima di applicare modifiche.
- Immagine renderizzata tramite Picture/Canvas con dimensioni fisse, non screenshot.
- Le operazioni specifiche della piattaforma sono isolate per una futura estensione iOS.
- Nessuna immagine d’esempio è stata presentata come screenshot reale dell’app.

## Riferimenti tecnici consultati

- Flutter, Android setup: https://docs.flutter.dev/platform-integration/android/setup
- Flutter, release Android: https://docs.flutter.dev/deployment/android
- Flutter, Picture.toImage: https://api.flutter.dev/flutter/dart-ui/Picture/toImage.html
- Android, media storage: https://developer.android.com/training/data-storage/shared/media
- Android, document picker: https://developer.android.com/training/data-storage/shared/documents-files
- Android, AGP 8.11 / Gradle 8.13 / API 36: https://developer.android.com/build/releases/agp-8-11-0-release-notes

# YOKAI WORKOUT CREATOR

Progetto Flutter/Dart per Android: editor workout offline con griglia libera,
archivio locale e generazione di immagini verticali 1080×1920.

**Stato della consegna:** sorgenti applicativi e integrazioni Android implementati.
In questo ambiente non erano disponibili Flutter, Dart e Android SDK e il download
degli SDK non era raggiungibile. Di conseguenza **non è stato prodotto un APK e
non sono stati eseguiti il compilatore, Flutter Analyze, i test Flutter o prove su
Samsung**. I controlli di integrità disponibili sono passati; il dettaglio si trova
in `docs/VERIFICA.md`. Non considerare questa consegna già collaudata sul telefono.

## Cosa trovi

- Home, editor, storico, impostazioni e anteprima collegati.
- Griglia iniziale 15×10, fino a 20×12: testo libero in tutte le celle.
- Inserimento immediato nel campo CELLA, frecce e Next, zoom e spostamento.
- Selezione singola, rettangolare, di righe e colonne; long press + drag oppure
  intervallo numerico dal menu.
- Bold/normal, allineamento, colori, bordi, group/ungroup, merge/unmerge.
- Copia/incolla con formattazione e blocchi nell’editor; TSV negli appunti Android.
- Undo/redo, larghezze colonne, altezze righe, aggiunta/eliminazione righe/colonne.
- Titolo, data, sottotitolo, totale reps, difficoltà e note opzionali.
- Logo caricato dalle impostazioni e conservato localmente.
- Salvataggio automatico, archivio, apertura, duplicazione ed eliminazione.
- Renderer Canvas/Picture ad alta risoluzione, preview, PNG e JPG qualità 95%.
- Salvataggio in `Pictures/YOKAI` e menu Android di condivisione.
- Sei template: EMPTY, ROUNDS, CIRCUIT, A / B / C, AMRAP, FOR TIME.

Non servono account, Firebase, server o pacchetti Flutter esterni. L’app release
non richiede il permesso Internet. La prima preparazione/compilazione sul PC,
invece, richiede Internet per scaricare gli strumenti di sviluppo.

## 1. Preparare il computer Windows

1. Estrai tutto lo ZIP, per esempio in `C:\YOKAI`. Apri la cartella
   `yokai_workout_creator`: contiene `pubspec.yaml` e questa guida.
2. Installa Git per Windows, se non è presente: <https://git-scm.com/downloads/win>.
3. Scarica Flutter **3.35.7 stable per Windows** dall’archivio ufficiale:
   <https://docs.flutter.dev/install/archive>. È la versione scelta per riprodurre
   la configurazione di questo progetto, non una dichiarazione che sia l’ultima.
   Estrailo in `C:\dev\flutter` e aggiungi `C:\dev\flutter\bin` al PATH di Windows.
   Evita `Program Files`, cartelle con spazi e cartelle sincronizzate per gli SDK.
4. Installa Android Studio: <https://developer.android.com/studio>.
   Completa la procedura iniziale. In **SDK Manager** installa:
   **Android SDK Platform 36**, **Android SDK Build-Tools 35.0.0**,
   **Android SDK Platform-Tools**, **Android SDK Command-line Tools (latest)**.
   Gradle installerà l’NDK richiesto da Flutter se manca e le licenze sono accettate.
5. Apri una nuova finestra PowerShell. Esegui:

   ```powershell
   flutter --version
   flutter doctor --android-licenses
   flutter doctor -v
   ```

   Accetta le licenze con `y`. Android toolchain deve risultare disponibile.
   Visual Studio, Chrome e supporto Windows desktop non sono richiesti.
   La compilazione usa Java 17; una JDK compatibile fornita da Android Studio
   può essere selezionata da Flutter. Se Doctor segnala incompatibilità Java,
   installa JDK 17 e imposta il suo percorso con `flutter config --jdk-dir=...`.

## 2. Creare l’APK

Apri PowerShell **nella cartella che contiene `pubspec.yaml`** ed esegui:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build-apk.ps1
```

`ExecutionPolicy Bypass` vale per questo processo: non cambia permanentemente le
impostazioni del computer. Puoi leggere prima gli script nella cartella `tool`.

Lo script:

1. crea un progetto Flutter temporaneo per ottenere i launcher ufficiali di Gradle;
2. copia solo `gradlew`, `gradlew.bat`, `gradle-wrapper.jar` e le proprietà locali;
3. lascia intatti i sorgenti YOKAI e la configurazione Android;
4. esegue `flutter pub get`, `flutter analyze`, `flutter test`;
5. se i controlli passano, esegue `flutter build apk --release`.

Il primo avvio può richiedere tempo per i download. Se un controllo fallisce,
lo script si ferma e mostra l’errore: non dichiara riuscita una build fallita.

L’APK viene generato qui, relativamente alla cartella del progetto:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Per esempio, con progetto in `C:\YOKAI\yokai_workout_creator`:

```text
C:\YOKAI\yokai_workout_creator\build\app\outputs\flutter-apk\app-release.apk
```

Per eseguire separatamente i passaggi:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\prepare.ps1
flutter analyze
flutter test
flutter build apk --release
```

**Non saltare `prepare.ps1` al primo utilizzo:** i launcher binari generati da
Flutter non sono inclusi nello ZIP perché l’SDK non era disponibile qui.
Dopo la preparazione puoi ricompilare direttamente con `flutter build apk --release`.

Su Linux/macOS, con Flutter e Android SDK pronti:

```bash
bash tool/build-apk.sh
```

La documentazione ufficiale della compilazione Android è:
<https://docs.flutter.dev/deployment/android>.

## 3. Installare sul Samsung

1. Copia `app-release.apk` sul telefono tramite cavo USB, nella cartella Download.
2. Apri **Archivio / My Files → Download** e tocca l’APK.
3. Se richiesto, abilita l’installazione da questa fonte per l’app Archivio.
4. Premi **Installa**, poi apri **YOKAI WORKOUT CREATOR**.

Android minimo: **8.0 / API 26**. Un Samsung Galaxy S9+ rientra nell’intervallo
previsto dal progetto, ma non è stato utilizzato per un test reale in questa consegna.

Con debug USB attivo puoi anche usare `flutter run` da PC. I permessi Internet
nei manifest debug/profile servono soltanto agli strumenti Flutter e non vengono
inclusi nel manifest release dell’applicazione.

## 4. Primo workout

1. **SETTINGS → CARICA LOGO**: scegli preferibilmente il logo YOKAI PNG trasparente.
   In mancanza del file viene usata una scritta YOKAI, non un logo originale inventato.
2. Torna alla Home e scegli **NEW WORKOUT → ROUNDS**.
3. Tocca una cella: il campo CELLA riceve subito il focus. Scrivi e passa alla
   cella successiva con le frecce; Next va sotto. I dati esistenti sono selezionati
   per poterli sostituire rapidamente.
4. Per selezionare più celle, tieni premuto e trascina. In alternativa premi
   **SELEZIONE**, poi l’angolo opposto; oppure usa `⋯ → Seleziona intervallo`.
   I numeri a sinistra selezionano una riga, le lettere in alto una colonna.
5. Premi **GROUP** per creare un bordo esterno rosso. **UNGROUP** è nel menu `⋯`.
6. **MERGE** mostra il testo della cella in alto a sinistra. Gli altri testi
   restano memorizzati e tornano con **UNMERGE**; se vengono nascosti testi viene
   mostrata una conferma. CLEAR cancella i contenuti selezionati, compresi quelli
   temporaneamente nascosti in una cella unita.
7. Usa il pulsante dettagli accanto al titolo oppure la riga sotto la griglia
   per titolo/data/sottotitolo, TOTAL REPS, DIFFICULTY e NOTES. Le modifiche sono
   salvate mentre scrivi; FATTO chiude i dettagli.
8. Chiudi la tastiera e premi **GENERATE IMAGE**.
9. In anteprima puoi ingrandire con due dita. **SAVE IMAGE** salva in galleria;
   **SHARE** apre il menu Android; **EDIT** e **CLOSE** tornano all’editor.

La generazione tiene l’immagine in memoria, senza aggiungerla alla galleria.
SHARE usa un file temporaneo privato, non un salvataggio pubblico; i vecchi file di
condivisione vengono ripuliti dopo sette giorni quando crei una nuova condivisione.

In Android 10 e successivi il salvataggio usa MediaStore senza permessi generali
di lettura della galleria. In Android 8/9 il permesso di scrittura viene richiesto
solo premendo SAVE IMAGE. Il caricamento logo usa il selettore file Android.

## 5. Archivio e duplicazione

I workout si salvano automaticamente, inclusi celle, bordi, gruppi, merge,
dimensioni, metadata e contenuti opzionali. `SALVATO` indica che la coda di
scrittura è stata completata; in caso di errore compare `RIPROVA`.

- **WORKOUTS** mostra gli allenamenti in ordine di ultima modifica.
- Tocca un workout per aprirlo/modificarlo.
- Dal menu scegli **DUPLICATE**: la copia ha un nuovo identificativo e la data odierna.
- **DELETE** chiede conferma. L’eliminazione dell’archivio è definitiva.
- Nell’editor **UNDO / REDO** conserva fino a 60 stati e raggruppa la digitazione
  consecutiva. La cronologia Undo vale per la sessione aperta, non dopo il riavvio.

Il contenuto rimane locale. Disinstallare l’app o cancellarne i dati elimina
l’archivio; il backup cloud Android è disabilitato. Una normale installazione di
aggiornamento con la stessa firma mantiene i dati.

## 6. Rendering e limiti dichiarati

Il renderer usa le celle effettivamente occupate e include anche merge, gruppi e
bordi/sfondi espliciti. Le righe/colonne vuote interne vengono mantenute perché
possono essere separatori intenzionali; quelle finali inutilizzate sono rimosse.
Le guide grigie dell’editor non sono bordi stampati automaticamente.

Le larghezze impostate vengono normalizzate nello spazio disponibile. Il font e
le altezze vengono calcolati sulla quantità reale di testo, anche per celle unite.
Una tabella corta riceve più spazio; una densa riduce il font. I campi opzionali
vuoti non riservano sezioni. Il totale reps è manuale e può contenere testo libero.

Non si può garantire la leggibilità di una quantità illimitata di testo in 1080×1920:
se non entra neppure al font minimo il renderer ferma l’esportazione e propone di
ridurre testo/colonne o dividere il workout. Per tabelle dense segnala di controllare
la leggibilità in anteprima. L’editor può mostrare testo molto lungo in piccolo;
il campo CELLA permette sempre di leggerlo e modificarlo interamente.

Le impostazioni di logo/colori/formato sono globali: una successiva esportazione di
un vecchio workout usa il branding corrente. Non esiste un calcolo automatico delle
reps, dato che tutte le celle sono libere. Copia/incolla da altre app usa TSV
semplice, senza interpretare formule o celle con tab/newline interni.

iOS non è una piattaforma completata: modelli, editor e renderer sono Dart
riutilizzabili; storage, scelta logo, JPG, galleria e condivisione richiedono
l’adattatore nativo iOS equivalente a `PlatformBridge`.

## 7. Firma e aggiornamenti

Per consentire la compilazione personale immediata, in assenza di
`android/key.properties` la build release usa il certificato debug locale
creato dagli strumenti Android. L’APK è destinato all’installazione manuale;
questa non è la configurazione per pubblicare sul Play Store.

Per aggiornamenti continuativi conserva la stessa chiave. Puoi configurare una
chiave release personale: crea `android/key.properties` a partire da
`docs/key.properties.example` e genera/conserva il tuo keystore secondo la guida
ufficiale Flutter. Non caricare chiavi e password in repository pubblici.
Se cambi certificato, Android rifiuta l’aggiornamento dell’app già installata.

## 8. Compilazione GitHub opzionale

Il progetto contiene anche un workflow avviabile manualmente da GitHub Actions.
Non è stato pubblicato né eseguito in questa consegna. Per usarlo carica il contenuto
del progetto nella radice di un tuo repository, apri Actions, scegli
**Build Android APK → Run workflow** e, se la build riesce, scarica l’artefatto
**YOKAI-APK**. Disponibilità e quote dipendono dal tuo account GitHub.

Il workflow predefinito usa una chiave temporanea del runner: APK generati in run
differenti potrebbero non aggiornarsi tra loro. Per l’uso continuativo configura
la tua chiave tramite i secret del repository, oppure compila sempre sul tuo PC.

## Struttura

| Cartella | Contenuto |
|---|---|
| `lib/models` | Celle, intervalli, workout, impostazioni e serializzazione |
| `lib/services` | Operazioni editor, undo/redo, interfaccia nativa |
| `lib/storage` | Coda autosave e gestione archivio |
| `lib/screens` | Home, editor, storico, impostazioni e preview |
| `lib/widgets` | Griglia interattiva e toolbar |
| `lib/image_generation` | Layout e rendering PNG 1080×1920 |
| `lib/theme` | Tema YOKAI |
| `android/app/src/main/kotlin` | File atomici, selettore logo, MediaStore, JPG, condivisione |
| `test` | Test modello/editor, storage, rendering e percorso UI |
| `tool` | Preparazione e compilazione ripetibili |
| `docs` | Verifiche, prove su dispositivo e firma |

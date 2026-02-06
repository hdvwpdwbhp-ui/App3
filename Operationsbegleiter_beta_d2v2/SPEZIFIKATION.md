# Operationsbegleiter - Technische Spezifikation

## Ziel
Native iOS-Implementierung für Speech-to-Text und Backup-Export in einer WKWebView-App.

## Problem
- Browser-SpeechRecognition funktioniert nicht mit file:// URLs (HTTPS erforderlich)
- Download-Links funktionieren nicht in WKWebView

## Lösung

### Architektur

```
[HTML/JS in WKWebView]
        |
        | postMessage()
        v
[WKScriptMessageHandler]
        |
        +---> [SFSpeechRecognizer + AVAudioEngine] --> Spracherkennung
        |
        +---> [FileManager + UIActivityViewController] --> Backup-Export
        |
        | evaluateJavaScript()
        v
[Callbacks in HTML/JS]
```

### Info.plist Einträge

Schlüssel: NSMicrophoneUsageDescription
Wert: Die App benötigt Mikrofonzugriff für die Spracheingabe.

Schlüssel: NSSpeechRecognitionUsageDescription  
Wert: Die App verwendet Spracherkennung für die Diktatfunktion.

### JavaScript-API

Spracheingabe starten:
window.webkit.messageHandlers.diktat.postMessage({befehl: 'an'})

Spracheingabe stoppen:
window.webkit.messageHandlers.diktat.postMessage({befehl: 'aus'})

Backup exportieren:
window.webkit.messageHandlers.sicherung.postMessage({
    text: 'JSON-String mit Backup-Daten',
    name: 'dateiname.json'
})

### Swift-zu-JavaScript Callbacks

Erkannter Text:
window.dText('der erkannte text')

Aufnahme-Status (true=läuft, false=gestoppt):
window.dStatus(true)
window.dStatus(false)

Export erfolgreich:
window.eOK()

Fehler aufgetreten:
window.eFehler('fehlerbeschreibung')

### Swift-Komponenten

1. UIViewRepresentable-Wrapper für WKWebView
2. Coordinator-Klasse die WKScriptMessageHandler implementiert
3. Spracherkennungs-Manager mit:
   - AVAudioSession Konfiguration
   - AVAudioEngine mit inputNode-Tap
   - SFSpeechRecognizer für de-DE Locale
   - SFSpeechAudioBufferRecognitionRequest
4. Export-Manager mit:
   - FileManager für temporäre Dateien
   - UIActivityViewController für Share-Sheet

### Berechtigungen anfragen

Mikrofon: AVAudioSession.sharedInstance().requestRecordPermission
Spracherkennung: SFSpeechRecognizer.requestAuthorization

### Test-Checkliste

1. [ ] App auf echtem Gerät starten (nicht Simulator)
2. [ ] Mikrofon-Berechtigung erteilen
3. [ ] Spracherkennungs-Berechtigung erteilen
4. [ ] Spracheingabe-Button testen
5. [ ] Erkannter Text erscheint
6. [ ] Stop-Button funktioniert
7. [ ] Backup-Export öffnet Share-Sheet
8. [ ] Datei kann in "Dateien" gespeichert werden

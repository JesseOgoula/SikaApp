---
description: Résoudre les problèmes de build Android avec Gradle (IOException, fichiers verrouillés)
---
# Résolution des problèmes de build Android/Gradle

## Symptômes
- `Gradle task assembleDebug failed with exit code 1`
- `java.io.IOException: Unable to delete directory`
- Build échoue après plusieurs tentatives

## Solution (suivre dans l'ordre)

### 1. Arrêter les daemons Gradle
// turbo
```powershell
cd android; .\gradlew.bat --stop
```

### 2. Tuer les processus Java/Gradle zombies
```powershell
Get-Process | Where-Object {$_.ProcessName -match "java|gradle"} | Stop-Process -Force -ErrorAction SilentlyContinue
```

### 3. Supprimer manuellement le dossier build
// turbo
```powershell
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
```

### 4. Nettoyer Flutter et reconstruire
// turbo
```powershell
flutter clean
```

// turbo
```powershell
flutter pub get
```

### 5. Relancer l'application
```powershell
flutter run -d <device_id>
```

## Note importante
Le problème survient souvent quand:
- Le chemin du projet contient des espaces
- Des processus Gradle/Java restent actifs en arrière-plan
- Le build a été interrompu précédemment

## Prévention
- Éviter d'interrompre les builds en cours
- Toujours utiliser `gradlew --stop` avant de fermer le projet
- Considérer utiliser un chemin sans espaces

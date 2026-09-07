# Fjellfisk

Fjellfisk er en Flutter- og Firebase-app for intern registrering og oppfølging av
produksjon hos Hardanger Fjellfisk. Appen inneholder blant annet oversikt over
anlegg og kar, driftslogg, fôring, dødelighet, vekst, rapporter og roller.

## Kom i gang

Du trenger Flutter SDK, Git og Visual Studio Code med Flutter-utvidelsen.

1. Klon prosjektet og åpne prosjektmappen i Visual Studio Code.
2. Installer avhengighetene:

   ```powershell
   flutter pub get
   ```

3. Kontroller koden:

   ```powershell
   flutter analyze
   ```

4. Kjør appen lokalt i Chrome:

   ```powershell
   flutter run -d chrome
   ```

## Arbeidsflyt for elever

Elever skal aldri arbeide direkte på `main`. Oppdater `develop`, og lag en egen
branch for hver oppgave:

```powershell
git switch develop
git pull
git switch -c student/navn-oppgave
```

Eksempler på branch-navn:

- `student/ola-sprakvalg`
- `student/kari-faq`
- `student/per-mobilvisning`

Etter at endringen er testet:

```powershell
dart format .
flutter analyze
flutter test
git add .
git commit -m "Kort forklaring av endringen"
git push -u origin student/navn-oppgave
```

Opprett deretter en Pull Request mot `develop`. Beskriv hva som er endret og
hvordan det er testet. Max eller Codex må godkjenne endringen før den flettes.
Bare godkjente endringer flyttes senere fra `develop` til `main`.

Les [CONTRIBUTING_STUDENTS.md](CONTRIBUTING_STUDENTS.md) for alle reglene.

## Dette skal elever ikke gjore

- Ikke push passord, API-nøkler, signeringsnøkler eller andre sensitive filer.
- Ikke deploy Firebase eller webappen.
- Ikke bygg eller last opp APK/AAB til Google Play.
- Ikke endre produksjonsdata eller Firestore-regler uten avtale.
- Ikke rør eller koble til OxyGuard/Vigo.
- Ikke push direkte til `main` eller merge egne Pull Requests.

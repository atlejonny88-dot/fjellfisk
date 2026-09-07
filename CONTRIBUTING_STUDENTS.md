# Bidrag fra skoleelever

Takk for at du bidrar til Fjellfisk. Vi starter med små og tydelige oppgaver, slik
at det er enkelt a teste endringen og holde produksjonsappen trygg.

## Regler

1. Arbeid aldri direkte på `main`.
2. Start fra oppdatert `develop` og lag en egen branch for oppgaven.
3. Gjør bare endringer som hører til oppgaven din.
4. Opprett en Pull Request mot `develop` når arbeidet er klart.
5. Max eller Codex må kontrollere og godkjenne Pull Requesten før merge.
6. Ikke merge din egen Pull Request.

Bruk branch-navn som viser hvem og hva oppgaven gjelder:

- `student/navn-oppgave`
- `student/ola-sprakvalg`
- `student/kari-faq`

## Sikkerhet

- Legg aldri inn passord, API-nøkler, Firebase-nøkler, private nøkler eller
  signeringsfiler i Git eller GitHub.
- Ikke endre eller dele `.env`, `key.properties`, `.jks`, `.keystore`, service
  account-filer eller andre lokale hemmeligheter.
- Ikke deploy Firebase eller webappen.
- Ikke bygg eller last opp APK/AAB.
- Ikke publiser noe til Google Play.
- Ikke rør, koble til eller gjør endringer på OxyGuard/Vigo.
- Ikke bruk ekte produksjonsdata i tester, skjermbilder eller dokumentasjon.

Stopp og spør Max dersom du er usikker på om en fil eller verdi er sensitiv.

## Gode startoppgaver

- Språk og tekstforbedringer
- FAQ og hjelpetekster
- UI-forbedringer
- Dokumentasjon
- Mobilvisning
- Små, avgrensede feilrettinger

## For Pull Request

Kjør disse kommandoene lokalt:

```powershell
dart format .
flutter analyze
flutter test
```

Kontroller at appen starter med `flutter run -d chrome`. Forklar deretter kort i
Pull Requesten hva du endret, hvorfor du endret det og hvordan du testet det.

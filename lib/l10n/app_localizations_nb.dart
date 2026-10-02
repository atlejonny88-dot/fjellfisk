// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Norwegian Bokmål (`nb`).
class AppLocalizationsNb extends AppLocalizations {
  AppLocalizationsNb([String locale = 'nb']) : super(locale);

  @override
  String get appTitle => 'Fjellfisk';

  @override
  String get norwegian => 'Norsk';

  @override
  String get english => 'Engelsk';

  @override
  String get polish => 'Polsk';

  @override
  String get language => 'Språk';

  @override
  String get changeLanguage => 'Bytt språk';

  @override
  String get languageSaveFailed =>
      'Språkvalget kunne ikke lagres ennå. Språket brukes likevel i denne økten.';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get refresh => 'Oppdater';

  @override
  String get refreshDashboard => 'Oppdater dashboard';

  @override
  String get updating => 'Oppdaterer';

  @override
  String get logout => 'Logg ut';

  @override
  String get facility => 'Anlegg';

  @override
  String get user => 'Bruker';

  @override
  String get diary => 'Dagbok / Driftslogg';

  @override
  String get productionReport => 'Produksjonsrapport';

  @override
  String get feedInventory => 'Fôrlager';

  @override
  String get excelExport => 'Excel-eksport';

  @override
  String get usersAndAccess => 'Brukere & Tilganger';

  @override
  String get activeTanks => 'Aktive kar';

  @override
  String tanksOfTotal(int count) {
    return 'av $count kar';
  }

  @override
  String emptyTanks(int count) {
    return '$count tomme kar';
  }

  @override
  String get emptyTanksLabel => 'Tomme kar';

  @override
  String get biomass => 'Biomasse';

  @override
  String fishCount(int count) {
    return '$count fisk';
  }

  @override
  String get fish => 'Fisk';

  @override
  String activeAndEmptyTanks(int active, int empty) {
    return '$active aktive / $empty tomme';
  }

  @override
  String get recommendedFeedLabel => 'Anbefalt fôr';

  @override
  String get activeBiomass => 'Aktiv biomasse';

  @override
  String get feedToday => 'Fôr i dag';

  @override
  String get actualRecorded => 'Faktisk registrert';

  @override
  String recommendedFeed(String amount) {
    return 'Anbefalt $amount kg';
  }

  @override
  String get deadToday => 'Døde i dag';

  @override
  String get recordedMortality => 'Registrert dødelighet';

  @override
  String get noneRecordedToday => 'Ingen registrert i dag';

  @override
  String get numberOfFish => 'Antall fisk';

  @override
  String get averageTemperature => 'Snittemperatur';

  @override
  String get recordedMeasurements => 'Registrerte målinger';

  @override
  String get updatedFromTankLogs => 'Oppdatert fra karlogger';

  @override
  String get noData => 'Ingen data';

  @override
  String get notEnoughData => 'Ikke nok data';

  @override
  String get buildings => 'Bygg';

  @override
  String sectionsWithTanks(int sections, int tanks) {
    return '$sections seksjoner med $tanks kar';
  }

  @override
  String get exportFacilityToExcel => 'Eksporter anlegget til Excel';

  @override
  String get operationalTools => 'Driftsverktøy';

  @override
  String get operationalToolsSubtitle => 'Rapporter, lager og administrasjon';

  @override
  String get reportSubtitle => 'Se nøkkeltall for valgt periode';

  @override
  String get feedInventorySubtitle => 'Se beholdning og lagerhistorikk';

  @override
  String get excelSubtitle => 'Eksporter komplett anleggsoversikt';

  @override
  String get accessSubtitle => 'Endre roller og tilgang';

  @override
  String get retry => 'Prøv igjen';

  @override
  String get cancel => 'Avbryt';

  @override
  String get save => 'Lagre';

  @override
  String get create => 'Opprett';

  @override
  String get close => 'Lukk';

  @override
  String get notifications => 'Varsler';

  @override
  String unreadNotifications(int count) {
    return '$count uleste varsler';
  }

  @override
  String get noUnreadNotifications => 'Ingen uleste varsler';

  @override
  String get markAllRead => 'Marker alle som lest';

  @override
  String get marking => 'Markerer...';

  @override
  String get markAsRead => 'Marker som lest';

  @override
  String get closeNotifications => 'Lukk varsler';

  @override
  String get noNotifications => 'Ingen varsler';

  @override
  String get notificationsUnavailable => 'Varsler er ikke tilgjengelige nå';

  @override
  String get notificationsUnavailableDetail =>
      'Resten av Fjellfisk fungerer som normalt. Prøv igjen senere.';

  @override
  String get noNotificationsDetail => 'Nye driftsvarsler vises her.';

  @override
  String todayAt(String time) {
    return 'I dag $time';
  }

  @override
  String yesterdayAt(String time) {
    return 'I går $time';
  }

  @override
  String get couldNotOpenNotification =>
      'Kunne ikke åpne varselet. Prøv igjen.';

  @override
  String get couldNotMarkNotificationRead =>
      'Kunne ikke markere varselet som lest.';

  @override
  String get couldNotMarkAllNotificationsRead =>
      'Kunne ikke markere alle varslene som lest.';

  @override
  String get newVersionAvailable => 'Ny Fjellfisk-versjon tilgjengelig';

  @override
  String get updateWhenSaved =>
      'Oppdater appen når du har lagret eventuelle endringer.';

  @override
  String get highMortality => 'Høy dødelighet';

  @override
  String highMortalityTank(String tank) {
    return 'Høy dødelighet i $tank';
  }

  @override
  String deathsLast7Days(int count) {
    return '$count døde siste 7 dager. Kontroller karet og registreringene.';
  }

  @override
  String get lowFeedStock => 'Lavt fôrlager';

  @override
  String lowFeedStockItem(String feed) {
    return 'Lavt fôrlager: $feed';
  }

  @override
  String feedStockBody(String stock, String threshold) {
    return '$stock kg igjen. Varselgrense er $threshold kg (én sekk).';
  }

  @override
  String newTankNote(String tank) {
    return 'Nytt driftsnotat på $tank';
  }

  @override
  String get newDiaryEntry => 'Nytt innlegg';

  @override
  String newDiaryEntryTitle(String title) {
    return 'Nytt dagbokinnlegg: $title';
  }

  @override
  String get login => 'Logg inn';

  @override
  String get loginTagline => 'Drift. Oversikt. Kontroll.';

  @override
  String get loginContinue => 'Logg inn for å fortsette';

  @override
  String get signingIn => 'Logger inn';

  @override
  String appVersion(String version) {
    return 'Fjellfisk v$version';
  }

  @override
  String get email => 'E-post';

  @override
  String get password => 'Passord';

  @override
  String get forgotPassword => 'Glemt passord?';

  @override
  String get signIn => 'Logg inn';

  @override
  String get enterEmailAndPassword => 'Skriv inn e-post og passord.';

  @override
  String get loginTimeout =>
      'Innlogging tok for lang tid. Lukk Safari helt og prøv igjen.';

  @override
  String get loginFailed => 'Kunne ikke logge inn. Prøv igjen.';

  @override
  String get invalidEmail => 'Ugyldig e-postadresse.';

  @override
  String get invalidCredentials => 'Feil e-post eller passord.';

  @override
  String get userDisabledMessage => 'Brukeren er deaktivert. Kontakt admin.';

  @override
  String get tooManyLoginAttempts =>
      'For mange forsøk. Vent litt og prøv igjen.';

  @override
  String get loginNetworkFailed =>
      'Fikk ikke kontakt med innloggingstjenesten. Sjekk internett.';

  @override
  String get emptyTank => 'Tomt kar';

  @override
  String get notInUse => 'Ikke i bruk';

  @override
  String get sections => 'Seksjoner';

  @override
  String get tank => 'Kar';

  @override
  String get tanks => 'Kar';

  @override
  String get newTank => 'Nytt kar';

  @override
  String get tankName => 'Navn på kar';

  @override
  String get numberOfFishLabel => 'Antall fisk';

  @override
  String get createFirstTank => 'Opprett første kar';

  @override
  String get tankOverview => 'Karoversikt';

  @override
  String tankOverviewTitle(String section) {
    return 'Karoversikt · $section';
  }

  @override
  String get tankOverviewSubtitle =>
      'Oversikt og siste nøkkeltall for alle kar i seksjonen.';

  @override
  String get refreshTankOverview => 'Oppdater karoversikt';

  @override
  String get loadingTanks => 'Laster kar...';

  @override
  String noTanksInSection(String section) {
    return 'Ingen kar i $section ennå';
  }

  @override
  String get searchTanks => 'Søk etter kar...';

  @override
  String get allTanks => 'Alle kar';

  @override
  String get observation => 'Observasjon';

  @override
  String get critical => 'Kritisk';

  @override
  String get criticalPlural => 'Kritiske';

  @override
  String get noMatchingTanks => 'Ingen kar passer med valgt søk eller filter.';

  @override
  String get noValue => 'Ingen';

  @override
  String get noFeed => 'Ingen fôring';

  @override
  String get normalOperation => 'Normal drift';

  @override
  String get missingAverageWeight => 'Mangler snittvekt';

  @override
  String get oldAverageWeight => 'Gammel snittvekt';

  @override
  String highMortalityMessage(int count) {
    return 'Høy dødelighet · $count døde siste 7 dager';
  }

  @override
  String followUpMeasurements(String status) {
    return '$status · følg opp nye målinger';
  }

  @override
  String get emptyTankMessage => 'Ikke i bruk · kan åpnes og fylles senere';

  @override
  String normalMortalityMessage(int count) {
    return 'Normal drift · dødelighet 7d: $count';
  }

  @override
  String get allValuesNormal => 'Alt innen normale verdier';

  @override
  String get feed => 'Fôr';

  @override
  String get mortality => 'Dødelighet';

  @override
  String get averageWeight => 'Snittvekt';

  @override
  String get temperature => 'Temperatur';

  @override
  String get history => 'Historikk';

  @override
  String get tankInfo => 'Kar info';

  @override
  String get weightSamples => 'Vektprøver';

  @override
  String get growthForecast => 'Vekstprognose';

  @override
  String get markReviewed => 'Gjennomgått';

  @override
  String get reviewedThisSession => 'Gjennomgått i denne økten';

  @override
  String get feedLast24Hours => 'Fôr 24t';

  @override
  String get deathsLast7DaysShort => 'Døde 7d';

  @override
  String get moreOptions => 'Flere valg';

  @override
  String get deleteTank => 'Slett kar';

  @override
  String get tankIllustration => 'Illustrasjon av oppdrettskar';

  @override
  String get tankNotesUnavailable => 'Driftsnotater er ikke tilgjengelige';

  @override
  String get saveAndNext => 'Lagre og neste';

  @override
  String get nextTank => 'Neste kar';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get roleEmployee => 'Ansatt';

  @override
  String get roleReader => 'Leser';

  @override
  String get statusActive => 'Aktiv';

  @override
  String get statusDisabled => 'Deaktivert';

  @override
  String get dashboardUpdated => 'Dashboard oppdatert';

  @override
  String get excelExportComplete => 'Excel eksport fullført';

  @override
  String get excelExportFailed => 'Kunne ikke eksportere Excel. Prøv igjen.';

  @override
  String get contentUnavailable =>
      'Det tilhørende innholdet er ikke tilgjengelig nå.';

  @override
  String get loading => 'Laster...';

  @override
  String get period => 'Periode';

  @override
  String get today => 'I dag';

  @override
  String get last7Days => 'Siste 7 dager';

  @override
  String get last30Days => 'Siste 30 dager';

  @override
  String get currentMonth => 'Denne måneden';

  @override
  String get customPeriod => 'Egendefinert periode';

  @override
  String fromDate(String date) {
    return 'Fra $date';
  }

  @override
  String toDate(String date) {
    return 'Til $date';
  }

  @override
  String get reportFor => 'Rapport for';

  @override
  String get entireFacility => 'Hele anlegget';

  @override
  String get buildingOrSection => 'Bygg/seksjon';

  @override
  String get singleTank => 'Enkelt kar';

  @override
  String get selectBuildingOrTank => 'Velg bygg eller kar';

  @override
  String get reportSelectionHint => 'Rapporten vises når valget er komplett.';

  @override
  String get reportCreationFailed => 'Kunne ikke lage rapport';

  @override
  String get reportCreationHint =>
      'Prøv igjen. Kontroller nettverk og tilgang.';

  @override
  String get reportExportFailed =>
      'Kunne ikke eksportere rapporten. Prøv igjen.';

  @override
  String get exportToExcel => 'Eksporter til Excel';

  @override
  String get noRecordsSelectedPeriod => 'Ingen registreringer i valgt periode';

  @override
  String get reportDataAvailability =>
      'Karstatus og siste biomasse vises der datagrunnlag finnes.';

  @override
  String get feedUsed => 'Fôr brukt';

  @override
  String get latestAverageWeight => 'Siste snittvekt';

  @override
  String get weightChange => 'Vektendring';

  @override
  String get fcrUnavailable => 'FCR kan ikke beregnes';

  @override
  String get registrations => 'Registreringer';

  @override
  String get noTanksForFilter => 'Ingen kar funnet for valgt filter';

  @override
  String get section => 'Seksjon';

  @override
  String get dead => 'Død';

  @override
  String get temperatureShort => 'Temp';

  @override
  String historyForTank(String tank) {
    return 'Historikk - $tank';
  }

  @override
  String get noRecordsFound => 'Ingen registreringer funnet';

  @override
  String get changeFilterOrPeriod => 'Prøv å endre filter eller periode.';

  @override
  String get registrationType => 'Type registrering';

  @override
  String get all => 'Alle';

  @override
  String get notes => 'Notater';

  @override
  String get resetFilter => 'Nullstill filter';

  @override
  String get unknownDate => 'Ukjent dato';

  @override
  String mortalityAndFeed(String mortality, String feed) {
    return 'Død: $mortality  •  Fôr: $feed kg';
  }

  @override
  String feedTypeLine(String type) {
    return 'Fôrtype: $type';
  }

  @override
  String pelletLine(String size) {
    return 'Pellet: $size mm';
  }

  @override
  String noteLine(String note) {
    return 'Notat: $note';
  }

  @override
  String tankInfoTitle(String tank) {
    return 'Kar info - $tank';
  }

  @override
  String get couldNotFetchData =>
      'Kunne ikke hente data. Gå tilbake og prøv igjen.';

  @override
  String get calculating => 'Beregner...';

  @override
  String weightSampleForTank(String tank) {
    return 'Vektprøve - $tank';
  }

  @override
  String get readerAccess => 'Lesetilgang';

  @override
  String readOnlyRole(String role) {
    return 'Du er logget inn som $role og kan kun se.';
  }

  @override
  String get emptyTankDescription =>
      'Karet er tomt. Fyll inn fisk først for å registrere vektprøver.';

  @override
  String get simpleAverageWeight => 'Vanlig snittvekt';

  @override
  String get individualWeights => 'Enkeltvekter';

  @override
  String get averageWeightGram => 'Snittvekt (g)';

  @override
  String get averageWeightInputHelp => 'Støtter 250, 250.5 og 250,5';

  @override
  String get saveAverageWeight => 'Lagre snittvekt';

  @override
  String get weightInGrams => 'Vekt i gram';

  @override
  String get weightSampleInputHelp =>
      'Skriv én vekt eller lim inn flere vekter med mellomrom, komma eller linjeskift.';

  @override
  String get add => 'Legg til';

  @override
  String get clearList => 'Tøm liste';

  @override
  String get comment => 'Kommentar';

  @override
  String get optional => 'Valgfritt';

  @override
  String get saveWeightSample => 'Lagre vektprøve';

  @override
  String get weightSamplesUnavailable => 'Vektprøver er ikke tilgjengelige nå.';

  @override
  String get noWeightSamples => 'Ingen vektprøver er registrert ennå.';

  @override
  String get latestWeightSample => 'Siste vektprøve';

  @override
  String get distribution => 'Fordeling';

  @override
  String get noDistribution => 'Ingen fordeling tilgjengelig.';

  @override
  String commentLine(String comment) {
    return 'Kommentar: $comment';
  }

  @override
  String weightGrowthTitle(String tank) {
    return 'Vekst – $tank';
  }

  @override
  String get noWeightRecords => 'Ingen vektregistreringer ennå';

  @override
  String mortalityTitle(String tank) {
    return 'Dødelighet – $tank';
  }

  @override
  String get noMortalityRecords => 'Ingen dødelighetsdata ennå';

  @override
  String get totalMortality => 'Total dødelighet';

  @override
  String get numberOfRegistrations => 'Antall registreringer';

  @override
  String get moveFish => 'Flytt fisk';

  @override
  String get moveFishValidation =>
      'Velg mottakerkar og et antall større enn null.';

  @override
  String get couldNotLoadTanks => 'Kunne ikke hente kar. Prøv igjen.';

  @override
  String get noOtherTanks => 'Ingen andre kar å flytte til';

  @override
  String get fromTank => 'Fra kar';

  @override
  String get moveToTank => 'Flytt til kar';

  @override
  String get fishToMove => 'Antall fisk som skal flyttes';

  @override
  String get fishCountExample => 'F.eks. 2000';

  @override
  String get enterWeightFirst => 'Skriv inn en vekt først.';

  @override
  String invalidValuesNotAdded(String values) {
    return 'Noen verdier ble ikke lagt til: $values';
  }

  @override
  String get invalidAverageWeight => 'Ugyldig snittvekt';

  @override
  String get averageWeightSaved => 'Snittvekt lagret';

  @override
  String get addWeightBeforeSaving => 'Legg til minst én vekt før lagring.';

  @override
  String get weightSampleSaved => 'Vektprøve lagret';

  @override
  String get emptyTankBeforeWeight =>
      'Karet er tomt. Legg inn fisketall før vekt registreres.';

  @override
  String get noWriteAccess => 'Ingen skrivetilgang';

  @override
  String get couldNotSaveWeight =>
      'Kunne ikke lagre vekten. Verdiene er beholdt. Prøv igjen.';

  @override
  String get registerWeight => 'Registrer vekt';

  @override
  String get count => 'Antall';

  @override
  String get average => 'Snitt';

  @override
  String get median => 'Median';

  @override
  String get minimum => 'Min';

  @override
  String get maximum => 'Maks';

  @override
  String get standardDeviation => 'Std.avvik';

  @override
  String get unknownTime => 'Ukjent tidspunkt';

  @override
  String get averageWeightOverTime => 'Snittvekt over tid';

  @override
  String get mortalityPerRegistration => 'Dødelighet per registrering';

  @override
  String get manageUsersSubtitle =>
      'Administrer interne brukere, roller og invitasjoner.';

  @override
  String get inviteUser => 'Inviter bruker';

  @override
  String get couldNotUpdateUser => 'Kunne ikke oppdatere brukeren';

  @override
  String get usersUnavailable => 'Kunne ikke hente brukerne akkurat nå.';

  @override
  String get searchUsers => 'Søk etter bruker...';

  @override
  String get noUsersFound => 'Ingen brukere funnet';

  @override
  String get roleUpdated => 'Rolle oppdatert';

  @override
  String get userDisabled => 'Bruker deaktivert';

  @override
  String get userEnabled => 'Bruker aktivert';

  @override
  String get unknownEmail => 'Ukjent e-post';

  @override
  String get activateUser => 'Aktiver bruker';

  @override
  String get deactivateUser => 'Deaktiver bruker';

  @override
  String get actions => 'Handlinger';

  @override
  String get invitationLinkCopied => 'Invitasjonslenke kopiert';

  @override
  String get revokeInvitationQuestion => 'Trekke tilbake invitasjonen?';

  @override
  String get revokeInvitation => 'Trekk tilbake';

  @override
  String get invitationRevoked => 'Invitasjonen er trukket tilbake';

  @override
  String get couldNotRevokeInvitation => 'Kunne ikke trekke invitasjonen';

  @override
  String get invitationsUnavailable =>
      'Invitasjoner er ikke tilgjengelige ennå.';

  @override
  String get invitations => 'Invitasjoner';

  @override
  String get noInvitations => 'Ingen invitasjoner er opprettet';

  @override
  String get invitationActions => 'Invitasjonshandlinger';

  @override
  String get copyInvitationLink => 'Kopier invitasjonslenke';

  @override
  String get invitePanelTitle => 'Inviter bruker';

  @override
  String get nameOptional => 'Navn (valgfritt)';

  @override
  String get fullNameHint => 'Skriv inn fullt navn';

  @override
  String get emailHint => 'navn@epost.no';

  @override
  String get role => 'Rolle';

  @override
  String get invitationRoleInfo =>
      'Rollen låses til invitasjonen. Lenken er gyldig i 7 dager.';

  @override
  String get createInvitation => 'Opprett invitasjon';

  @override
  String get invitationCreated => 'Invitasjon opprettet';

  @override
  String get couldNotCreateInvitation => 'Kunne ikke opprette invitasjonen';

  @override
  String get invitationReady => 'Invitasjonen er klar til å sendes.';

  @override
  String get copyInvitationText => 'Kopier invitasjonstekst';

  @override
  String get accessDeniedUserAdmin =>
      'Du har ikke tilgang til å administrere brukere';

  @override
  String get notRegistered => 'Ikke registrert';

  @override
  String expiresOn(String date) {
    return 'utløper $date';
  }

  @override
  String adjustBagsForFeed(String feed) {
    return 'Juster $feed';
  }

  @override
  String get bagsToAdjust => 'Antall sekker (+ / -)';

  @override
  String get bagsAdjustHint => 'F.eks. 10 eller -3';

  @override
  String kgPerBagForFeed(String feed) {
    return 'Kg per sekk - $feed';
  }

  @override
  String get kgPerBag => 'Kg per sekk';

  @override
  String get feedType => 'Fôrtype';

  @override
  String get newFeedType => 'Ny fôrtype';

  @override
  String get editFeedType => 'Endre fôrtype';

  @override
  String get feedName => 'Navn';

  @override
  String get pelletSize => 'Pelletstørrelse mm';

  @override
  String get feedNameAndPelletRequired =>
      'Navn og pelletstørrelse må fylles ut.';

  @override
  String get cannotDeactivateFeedWithStock =>
      'Fôrtype med sekker på lager kan ikke deaktiveres.';

  @override
  String get activeFeedInventory => 'Aktivt fôrlager';

  @override
  String readOnlyInventoryRole(String role) {
    return 'Du er logget inn som $role og kan kun se lager.';
  }

  @override
  String get inactiveFeedType => 'Inaktiv fôrtype';

  @override
  String bags(int count) {
    return '$count sekker';
  }

  @override
  String get adjustBags => 'Juster sekker';

  @override
  String get editKgPerBag => 'Endre kg per sekk';

  @override
  String get inventoryHistory => 'Lagerhistorikk';

  @override
  String get noInventoryHistory => 'Ingen lagerhistorikk ennå';

  @override
  String get unknownFeed => 'Ukjent fôr';

  @override
  String get tankCount => 'Nåværende antall fisk';

  @override
  String get adjustFishCount => 'Juster fisketall';

  @override
  String get newFishCount => 'Nytt antall fisk';

  @override
  String get unsavedChanges => 'Ulagrede endringer';

  @override
  String get leaveWithoutSaving =>
      'Gå til neste kar uten å lagre de nye verdiene?';

  @override
  String get newOperationalNote => 'Nytt driftsnotat';

  @override
  String get editOperationalNote => 'Rediger driftsnotat';

  @override
  String get noteHint => 'F.eks. For mye spillfôr';

  @override
  String get operationalNoteSaved => 'Driftsnotat lagret';

  @override
  String get operationalNoteSaveFailed =>
      'Kunne ikke lagre driftsnotatet. Prøv igjen.';

  @override
  String get operationalNoteCompleted => 'Driftsnotat markert som ferdig';

  @override
  String get newNote => 'Nytt notat';

  @override
  String get edit => 'Rediger';

  @override
  String get markCompleted => 'Marker som ferdig';

  @override
  String get createOperationalNote => 'Opprett driftsnotat';

  @override
  String completedNotes(int count) {
    return 'Ferdige notater ($count)';
  }

  @override
  String get otherFeedType => 'Annen fôrtype fra lager';

  @override
  String get otherFeedTypeHint =>
      'Velg dette når en annen type enn den anbefalte er gitt.';

  @override
  String get selectFeedType => 'Velg fôrtype';

  @override
  String get useRecommendedFeedType => 'Bruk anbefalt fôrtype';

  @override
  String get dailyFeedRation => 'Anbefalt daglig fôrrasjon';

  @override
  String get mortalityInput => 'Dødelighet';

  @override
  String get feedKgInput => 'Fôr (kg)';

  @override
  String get averageWeightOptional => 'Snittvekt (g) – valgfritt';

  @override
  String get temperatureInput => 'Temperatur';

  @override
  String get day => 'Dag';

  @override
  String get month => 'Måned';

  @override
  String get year => 'År';

  @override
  String get goToToday => 'Gå til i dag';

  @override
  String get searchEntries => 'Søk i innlegg';

  @override
  String get category => 'Kategori';

  @override
  String get allCategories => 'Alle kategorier';

  @override
  String get printMonth => 'Skriv ut måned';

  @override
  String get printYear => 'Skriv ut år';

  @override
  String get noDiaryEntries => 'Ingen dagbokinnlegg i valgt periode';

  @override
  String get diaryUnavailablePermission =>
      'Driftsloggen er ikke tilgjengelig før tilgangsreglene er oppdatert.';

  @override
  String get diaryLoadFailed =>
      'Driftsloggen kunne ikke lastes akkurat nå. Resten av dashboardet fungerer som normalt.';

  @override
  String get diaryLoadingLong =>
      'Driftsloggen bruker lang tid på å svare. Resten av dashboardet fungerer som normalt.';

  @override
  String get diaryEntrySaved => 'Dagbokinnlegg lagret';

  @override
  String get diaryEntryUpdated => 'Dagbokinnlegg oppdatert';

  @override
  String get diaryEntryArchived => 'Dagbokinnlegg arkivert';

  @override
  String get couldNotSaveDiaryEntry => 'Kunne ikke lagre dagbokinnlegg';

  @override
  String get couldNotUpdateDiaryEntry => 'Kunne ikke oppdatere dagbokinnlegg';

  @override
  String get couldNotArchiveDiaryEntry => 'Kunne ikke arkivere dagbokinnlegg';

  @override
  String get couldNotOpenPrint => 'Kunne ikke åpne utskrift';

  @override
  String get archiveEntryQuestion => 'Arkiver innlegg?';

  @override
  String archiveEntryBody(String title) {
    return '«$title» fjernes fra den aktive dagboken.';
  }

  @override
  String get archive => 'Arkiver';

  @override
  String get editEntry => 'Rediger innlegg';

  @override
  String get entryTitle => 'Tittel';

  @override
  String get entryContent => 'Tekst / innhold';

  @override
  String get entryActions => 'Handlinger for innlegg';

  @override
  String get printEntry => 'Skriv ut innlegg';

  @override
  String diaryEntriesInView(int count) {
    return '$count innlegg i visningen';
  }

  @override
  String moreDiaryEntries(int count) {
    return '$count flere innlegg finnes i full dagbok.';
  }

  @override
  String get couldNotUpdateFeedInventory =>
      'Kunne ikke oppdatere fôrlageret. Prøv igjen.';

  @override
  String get editKgHint => 'Bruk blyanten på kortet for å endre kg per sekk.';

  @override
  String get pelletNotSet => 'Pellet ikke satt';

  @override
  String afterBags(String count) {
    return 'Etter: $count sekker';
  }

  @override
  String get dateTimeSavedAutomatically =>
      'Dato og klokkeslett lagres automatisk.';

  @override
  String get originalDatePreserved =>
      'Opprinnelig dato beholdes. Endringstid lagres automatisk.';

  @override
  String get saving => 'Lagrer…';

  @override
  String get openingNext => 'Åpner neste…';

  @override
  String get growthChart => 'Vekstdiagram';

  @override
  String get mortalityChart => 'Dødelighetsdiagram';

  @override
  String get noActiveOperationalNote => 'Ingen aktivt driftsnotat.';

  @override
  String writtenBy(String email) {
    return 'Skrevet av: $email';
  }

  @override
  String completedAt(String date) {
    return 'Ferdig: $date';
  }

  @override
  String get averageWeightMissingForBiomass =>
      'Registrer snittvekt for å beregne biomasse';

  @override
  String get emptyTankActivateHint =>
      'Ikke i bruk. Legg inn fisketall med blyanten for å aktivere karet.';

  @override
  String get leaveWeightEmptyHint =>
      'La stå tomt hvis fisken ikke er veid i dag';

  @override
  String get feedInventoryLoadFailed => 'Kunne ikke laste fôrlager nå.';

  @override
  String get noActiveFeedUsesRecommended =>
      'Ingen aktive fôrtyper i lager. Anbefalt fôrtype brukes.';

  @override
  String get recommendedFeedUsed => 'Ikke valgt - bruker anbefalt fôrtype';

  @override
  String get selectedFeedDrawnFromInventory =>
      'Valgt fôrtype trekkes fra lager';

  @override
  String get feedSelectionOptionalHint =>
      'Valgfritt. Brukes bare hvis du gir annen type enn anbefalt.';

  @override
  String get recommendedFeedType => 'Anbefalt fôrtype';

  @override
  String get stockLevel => 'Lagerbeholdning';

  @override
  String get checkingStock => 'Sjekker lager...';

  @override
  String get notAvailable => 'Ikke tilgjengelig';

  @override
  String get notFoundInActiveInventory => 'Ikke funnet i aktivt fôrlager';

  @override
  String get recommendedDailyFeedAmount => 'Anbefalt daglig fôrmengde';

  @override
  String get feedPercent => 'Fôrprosent';

  @override
  String get startWeight => 'Startvekt';

  @override
  String get endWeight => 'Sluttvekt';

  @override
  String get biomassGain => 'Biomasseøkning';

  @override
  String get currentAverageWeight => 'Nåværende snittvekt';

  @override
  String forecastDays(int days) {
    return 'Prognose $days dager';
  }

  @override
  String get dataBasis => 'Datagrunnlag';

  @override
  String daysCount(int count) {
    return '$count dager';
  }

  @override
  String get invited => 'Du er invitert';

  @override
  String roleLine(String role) {
    return 'Rolle: $role';
  }

  @override
  String get passwordMinimum => 'Passordet må ha minst 6 tegn';

  @override
  String get passwordsDoNotMatch => 'Passordene er ikke like';

  @override
  String get confirmPassword => 'Gjenta passord';

  @override
  String get showPassword => 'Vis passord';

  @override
  String get hidePassword => 'Skjul passord';

  @override
  String get signInAndAccept => 'Logg inn og godta';

  @override
  String get createAccount => 'Opprett konto';

  @override
  String get needNewAccount => 'Jeg trenger en ny konto';

  @override
  String get alreadyHaveAccount => 'Jeg har allerede konto';

  @override
  String get invalidInvitation => 'Invitasjonen er ugyldig eller utløpt';

  @override
  String get askAdminForInvitation =>
      'Be administrator opprette en ny invitasjon.';

  @override
  String get serviceTimedOut => 'Tjenesten brukte for lang tid. Prøv igjen.';

  @override
  String get couldNotCompleteInvitation => 'Kunne ikke fullføre invitasjonen';

  @override
  String wrongSignedInUser(String email) {
    return 'Du er logget inn som $email. Logg ut for å bruke invitasjonen.';
  }

  @override
  String get logoutQuestion => 'Logg ut?';

  @override
  String get logoutConfirmation => 'Er du sikker på at du vil logge ut?';

  @override
  String get dashboardLoadTimeout =>
      'Det tok for lang tid å hente driftsdata. Kontroller nettet og prøv igjen.';

  @override
  String get dashboardPermissionDenied =>
      'Brukeren mangler tilgang til driftsdata. Kontakt administrator.';

  @override
  String get dashboardUnavailable =>
      'Driftsdata er midlertidig utilgjengelige. Kontroller nettet og prøv igjen.';

  @override
  String get dashboardLoadFailed =>
      'Dashboardet kunne ikke lastes akkurat nå. Prøv igjen.';

  @override
  String get signedInUser => 'Innlogget bruker';

  @override
  String get tankUnavailable => 'Karet finnes ikke lenger i oversikten.';

  @override
  String get unknownTank => 'Ukjent kar';

  @override
  String get tankNameExample => 'F.eks. K1';

  @override
  String get fishCountLargeExample => 'F.eks. 12500';

  @override
  String get operationalNote => 'Driftsnotat';

  @override
  String deleteTankQuestion(String tank) {
    return 'Slette $tank?';
  }

  @override
  String get deleteTankConfirmation =>
      'Karet fjernes fra oversikten. Denne handlingen kan ikke angres.';

  @override
  String get couldNotMoveFish => 'Kunne ikke flytte fisken. Prøv igjen.';

  @override
  String get kgPerBagExample => 'F.eks. 25';

  @override
  String get feedNameExample => 'F.eks. Nutra Olympic 3.0';

  @override
  String get pelletSizeExample => 'F.eks. 3.0';

  @override
  String sampleSummary(String weight, int count) {
    return '$weight g snitt ($count fisk)';
  }

  @override
  String get invitationStatusPending => 'Venter';

  @override
  String get invitationStatusAccepted => 'Godtatt';

  @override
  String get invitationStatusRevoked => 'Trukket tilbake';

  @override
  String get invitationStatusExpired => 'Utløpt';

  @override
  String get enterEntryTitle => 'Skriv inn en tittel';

  @override
  String get enterEntryContent => 'Skriv inn tekst';

  @override
  String get previousPeriod => 'Forrige periode';

  @override
  String get nextPeriod => 'Neste periode';

  @override
  String get dataPermissionDenied =>
      'Du har ikke tilgang til disse dataene. Kontakt administrator.';

  @override
  String get dataLoadFailed =>
      'Kunne ikke hente data. Kontroller nettverket og prøv igjen.';

  @override
  String get noAverageWeightRegistered => 'Ingen snittvekt registrert ennå';

  @override
  String weightUntilFeed(String weight, String feed) {
    return '$weight g igjen til $feed';
  }

  @override
  String get finishFeedLargeFish => 'Sluttfôr / stor fisk';

  @override
  String invalidValue(String label) {
    return 'Ugyldig $label';
  }

  @override
  String get invalidMortality => 'Ugyldig dødelighet';

  @override
  String get enterAtLeastOneRegistration => 'Fyll inn minst én registrering.';

  @override
  String get noRegistrationAccess => 'Du har ikke tilgang til å registrere.';

  @override
  String get tankNoLongerExists => 'Karet finnes ikke lenger.';

  @override
  String get emptyTankBeforeRegistration =>
      'Karet er tomt. Legg inn fisketall før drift registreres.';

  @override
  String get mortalityExceedsFishCount =>
      'Dødelighet kan ikke være større enn fisketallet.';

  @override
  String get selectedFeedTypeMissing => 'Valgt fôrtype finnes ikke.';

  @override
  String insufficientFeedInStock(String amount) {
    return 'Ikke nok fôr på lager. Tilgjengelig: $amount kg.';
  }

  @override
  String get registrationCancelled => 'Registreringen ble avbrutt.';

  @override
  String get registrationSaved => 'Registrering lagret';

  @override
  String get registrationSaveFailed =>
      'Kunne ikke lagre registreringen. Prøv igjen.';

  @override
  String get allTanksReviewed => 'Alle kar i denne seksjonen er gjennomgått.';

  @override
  String get nextTankOpenFailed =>
      'Registreringen er lagret, men neste kar kunne ikke åpnes. Prøv igjen.';

  @override
  String get overview => 'Oversikt';

  @override
  String get tools => 'Verktøy';

  @override
  String latestAverageWeightLine(String weight) {
    return 'Siste snittvekt: $weight';
  }

  @override
  String get registerAverageWeightForFeed =>
      'Registrer snittvekt for å beregne fôrrasjon';

  @override
  String sgrOverDays(String sgr, int days) {
    return 'SGR: $sgr %/dag over $days dager';
  }

  @override
  String get fullName => 'Fullt navn';

  @override
  String get emailAlreadyRegistered =>
      'Denne e-postadressen er allerede registrert.';

  @override
  String get activeInvitationExists =>
      'Det finnes allerede en aktiv invitasjon for denne e-postadressen.';

  @override
  String get invalidRole => 'Ugyldig rolle.';

  @override
  String get inviteServiceUnavailable =>
      'Invitasjonstjenesten er ikke tilgjengelig. Prøv igjen.';

  @override
  String get signInWithInvitedEmail =>
      'Logg inn med e-postadressen invitasjonen ble sendt til.';

  @override
  String get invitationGreeting => 'Hei!';

  @override
  String invitationGreetingNamed(String name) {
    return 'Hei $name!';
  }

  @override
  String invitationCopyBody(String email, String link) {
    return 'Du er invitert til Fjellfisk for Arctic Hardanger.\n\nÅpne lenken og registrer eller logg inn med denne e-postadressen:\n$email\n\nLenke:\n$link\n\nMvh\nArctic Hardanger';
  }

  @override
  String get startingApp => 'Starter Fjellfisk...';

  @override
  String get startupFailedTitle => 'Kunne ikke starte appen';

  @override
  String get startupFailedMessage =>
      'Sjekk internettforbindelsen og prøv igjen. Hvis feilen fortsetter, kontakt administrator.';

  @override
  String get checkingLogin => 'Sjekker innlogging...';

  @override
  String get checkingAccess => 'Sjekker tilgang...';

  @override
  String get loginCheckFailedTitle => 'Kunne ikke sjekke innlogging';

  @override
  String get loginCheckFailedMessage =>
      'Appen fikk ikke kontakt med innloggingstjenesten. Prøv igjen.';

  @override
  String get accessDeniedTitle => 'Ingen tilgang';

  @override
  String get accessDeniedMessage =>
      'Du har ikke tilgang til Fjellfisk. Kontakt administrator.';

  @override
  String get roleCheckFailedTitle => 'Kunne ikke sjekke tilgang';

  @override
  String get roleCheckFailedMessage =>
      'Appen fikk ikke lest brukerrollen din. Kontakt administrator hvis du nylig har fått bruker eller rolle.';

  @override
  String get userDisabledTitle => 'Brukeren er deaktivert';

  @override
  String get userDisabledDetail =>
      'Kontakt administrator hvis du trenger tilgang igjen.';

  @override
  String get excelSheetFacility => 'Anlegg';

  @override
  String get excelSheetTank => 'Kar';

  @override
  String get excelSheetSummary => 'Sammendrag';

  @override
  String get excelSheetTankOverview => 'Karoversikt';

  @override
  String get excelSheetRegistrations => 'Registreringer';

  @override
  String get keyFigures => 'Nøkkeltall';

  @override
  String get productionReportTitle => 'Produksjonsrapport';

  @override
  String get filter => 'Filter';

  @override
  String get value => 'Verdi';

  @override
  String get registeredBiomassKg => 'Registrert biomasse kg';

  @override
  String get latestAverageWeightGram => 'Siste snittvekt g';

  @override
  String get weightChangeGram => 'Vektendring g';

  @override
  String get averageTemperatureLabel => 'Temperatur gjennomsnitt';

  @override
  String get minimumTemperatureLabel => 'Temperatur minimum';

  @override
  String get maximumTemperatureLabel => 'Temperatur maksimum';

  @override
  String get facilityName => 'Anleggsnavn';

  @override
  String get sectionBuilding => 'Seksjon/bygg';

  @override
  String get date => 'Dato';

  @override
  String get feedKg => 'Fôr kg';

  @override
  String get diaryPdfTitle => 'Fjellfisk Dagbok / Driftslogg';

  @override
  String get noDiaryEntriesForPeriod => 'Ingen innlegg i valgt periode.';

  @override
  String get dateMissing => 'Dato mangler';

  @override
  String get unknownUser => 'Ukjent bruker';

  @override
  String get untitled => 'Uten tittel';

  @override
  String pageOf(int current, int total) {
    return 'Side $current av $total';
  }
}

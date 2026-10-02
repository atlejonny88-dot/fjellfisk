// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appTitle => 'Fjellfisk';

  @override
  String get norwegian => 'Norweski';

  @override
  String get english => 'Angielski';

  @override
  String get polish => 'Polski';

  @override
  String get language => 'Język';

  @override
  String get changeLanguage => 'Zmień język';

  @override
  String get languageSaveFailed =>
      'Nie można jeszcze zapisać języka. Będzie on jednak używany w tej sesji.';

  @override
  String get dashboard => 'Panel główny';

  @override
  String get refresh => 'Odśwież';

  @override
  String get refreshDashboard => 'Odśwież panel główny';

  @override
  String get updating => 'Odświeżanie';

  @override
  String get logout => 'Wyloguj';

  @override
  String get facility => 'Obiekt';

  @override
  String get user => 'Użytkownik';

  @override
  String get diary => 'Dziennik / Dziennik operacyjny';

  @override
  String get productionReport => 'Raport produkcyjny';

  @override
  String get feedInventory => 'Magazyn paszy';

  @override
  String get excelExport => 'Eksport do Excel';

  @override
  String get usersAndAccess => 'Użytkownicy i dostęp';

  @override
  String get activeTanks => 'Aktywne zbiorniki';

  @override
  String tanksOfTotal(int count) {
    return 'z $count zbiorników';
  }

  @override
  String emptyTanks(int count) {
    return '$count pustych zbiorników';
  }

  @override
  String get emptyTanksLabel => 'Puste zbiorniki';

  @override
  String get biomass => 'Biomasa';

  @override
  String fishCount(int count) {
    return '$count ryb';
  }

  @override
  String get fish => 'Ryby';

  @override
  String activeAndEmptyTanks(int active, int empty) {
    return '$active aktywne / $empty puste';
  }

  @override
  String get recommendedFeedLabel => 'Zalecana pasza';

  @override
  String get activeBiomass => 'Aktywna biomasa';

  @override
  String get feedToday => 'Pasza dzisiaj';

  @override
  String get actualRecorded => 'Faktycznie zarejestrowano';

  @override
  String recommendedFeed(String amount) {
    return 'Zalecane $amount kg';
  }

  @override
  String get deadToday => 'Śnięcia dzisiaj';

  @override
  String get recordedMortality => 'Zarejestrowana śmiertelność';

  @override
  String get noneRecordedToday => 'Brak rejestracji dzisiaj';

  @override
  String get numberOfFish => 'Liczba ryb';

  @override
  String get averageTemperature => 'Średnia temperatura';

  @override
  String get recordedMeasurements => 'Zarejestrowane pomiary';

  @override
  String get updatedFromTankLogs => 'Zaktualizowano z rejestrów zbiorników';

  @override
  String get noData => 'Brak danych';

  @override
  String get notEnoughData => 'Za mało danych';

  @override
  String get buildings => 'Budynki';

  @override
  String sectionsWithTanks(int sections, int tanks) {
    return '$sections sekcji z $tanks zbiornikami';
  }

  @override
  String get exportFacilityToExcel => 'Eksportuj obiekt do Excel';

  @override
  String get operationalTools => 'Narzędzia operacyjne';

  @override
  String get operationalToolsSubtitle => 'Raporty, magazyn i administracja';

  @override
  String get reportSubtitle => 'Zobacz kluczowe dane dla wybranego okresu';

  @override
  String get feedInventorySubtitle => 'Zobacz stan i historię magazynu';

  @override
  String get excelSubtitle => 'Eksportuj pełny przegląd obiektu';

  @override
  String get accessSubtitle => 'Zmień role i dostęp';

  @override
  String get retry => 'Spróbuj ponownie';

  @override
  String get cancel => 'Anuluj';

  @override
  String get save => 'Zapisz';

  @override
  String get create => 'Utwórz';

  @override
  String get close => 'Zamknij';

  @override
  String get notifications => 'Powiadomienia';

  @override
  String unreadNotifications(int count) {
    return '$count nieprzeczytanych powiadomień';
  }

  @override
  String get noUnreadNotifications => 'Brak nieprzeczytanych powiadomień';

  @override
  String get markAllRead => 'Oznacz wszystkie jako przeczytane';

  @override
  String get marking => 'Oznaczanie...';

  @override
  String get markAsRead => 'Oznacz jako przeczytane';

  @override
  String get closeNotifications => 'Zamknij powiadomienia';

  @override
  String get noNotifications => 'Brak powiadomień';

  @override
  String get notificationsUnavailable => 'Powiadomienia są teraz niedostępne';

  @override
  String get notificationsUnavailableDetail =>
      'Pozostała część Fjellfisk działa normalnie. Spróbuj ponownie później.';

  @override
  String get noNotificationsDetail =>
      'Nowe alerty operacyjne pojawiają się tutaj.';

  @override
  String todayAt(String time) {
    return 'Dzisiaj $time';
  }

  @override
  String yesterdayAt(String time) {
    return 'Wczoraj $time';
  }

  @override
  String get couldNotOpenNotification =>
      'Nie można otworzyć powiadomienia. Spróbuj ponownie.';

  @override
  String get couldNotMarkNotificationRead =>
      'Nie można oznaczyć powiadomienia jako przeczytanego.';

  @override
  String get couldNotMarkAllNotificationsRead =>
      'Nie można oznaczyć wszystkich powiadomień jako przeczytanych.';

  @override
  String get newVersionAvailable => 'Dostępna jest nowa wersja Fjellfisk';

  @override
  String get updateWhenSaved => 'Zaktualizuj aplikację po zapisaniu zmian.';

  @override
  String get highMortality => 'Wysoka śmiertelność';

  @override
  String highMortalityTank(String tank) {
    return 'Wysoka śmiertelność w $tank';
  }

  @override
  String deathsLast7Days(int count) {
    return '$count śnięć w ciągu ostatnich 7 dni. Sprawdź zbiornik i rejestracje.';
  }

  @override
  String get lowFeedStock => 'Niski stan paszy';

  @override
  String lowFeedStockItem(String feed) {
    return 'Niski stan paszy: $feed';
  }

  @override
  String feedStockBody(String stock, String threshold) {
    return 'Pozostało $stock kg. Próg alertu wynosi $threshold kg (jeden worek).';
  }

  @override
  String newTankNote(String tank) {
    return 'Nowa notatka operacyjna dla $tank';
  }

  @override
  String get newDiaryEntry => 'Nowy wpis';

  @override
  String newDiaryEntryTitle(String title) {
    return 'Nowy wpis w dzienniku: $title';
  }

  @override
  String get login => 'Zaloguj się';

  @override
  String get loginTagline => 'Eksploatacja. Przegląd. Kontrola.';

  @override
  String get loginContinue => 'Zaloguj się, aby kontynuować';

  @override
  String get signingIn => 'Logowanie';

  @override
  String appVersion(String version) {
    return 'Fjellfisk v$version';
  }

  @override
  String get email => 'E-mail';

  @override
  String get password => 'Hasło';

  @override
  String get forgotPassword => 'Nie pamiętasz hasła?';

  @override
  String get signIn => 'Zaloguj się';

  @override
  String get enterEmailAndPassword => 'Wpisz e-mail i hasło.';

  @override
  String get loginTimeout =>
      'Logowanie trwało zbyt długo. Zamknij całkowicie Safari i spróbuj ponownie.';

  @override
  String get loginFailed => 'Nie można się zalogować. Spróbuj ponownie.';

  @override
  String get invalidEmail => 'Nieprawidłowy adres e-mail.';

  @override
  String get invalidCredentials => 'Nieprawidłowy e-mail lub hasło.';

  @override
  String get userDisabledMessage =>
      'Ten użytkownik jest wyłączony. Skontaktuj się z administratorem.';

  @override
  String get tooManyLoginAttempts =>
      'Zbyt wiele prób. Poczekaj chwilę i spróbuj ponownie.';

  @override
  String get loginNetworkFailed =>
      'Nie można połączyć się z usługą logowania. Sprawdź internet.';

  @override
  String get emptyTank => 'Pusty zbiornik';

  @override
  String get notInUse => 'Nie jest używany';

  @override
  String get sections => 'Sekcje';

  @override
  String get tank => 'Zbiornik';

  @override
  String get tanks => 'Zbiorniki';

  @override
  String get newTank => 'Nowy zbiornik';

  @override
  String get tankName => 'Nazwa zbiornika';

  @override
  String get numberOfFishLabel => 'Liczba ryb';

  @override
  String get createFirstTank => 'Utwórz pierwszy zbiornik';

  @override
  String get tankOverview => 'Przegląd zbiorników';

  @override
  String tankOverviewTitle(String section) {
    return 'Przegląd zbiorników · $section';
  }

  @override
  String get tankOverviewSubtitle =>
      'Przegląd i najnowsze kluczowe dane dla wszystkich zbiorników w tej sekcji.';

  @override
  String get refreshTankOverview => 'Odśwież przegląd zbiorników';

  @override
  String get loadingTanks => 'Ładowanie zbiorników...';

  @override
  String noTanksInSection(String section) {
    return 'Brak zbiorników w $section';
  }

  @override
  String get searchTanks => 'Szukaj zbiornika...';

  @override
  String get allTanks => 'Wszystkie zbiorniki';

  @override
  String get observation => 'Obserwacja';

  @override
  String get critical => 'Krytyczny';

  @override
  String get criticalPlural => 'Krytyczne';

  @override
  String get noMatchingTanks =>
      'Żadne zbiorniki nie pasują do wybranego wyszukiwania lub filtra.';

  @override
  String get noValue => 'Brak';

  @override
  String get noFeed => 'Brak karmienia';

  @override
  String get normalOperation => 'Normalna praca';

  @override
  String get missingAverageWeight => 'Brak średniej masy';

  @override
  String get oldAverageWeight => 'Nieaktualna średnia masa';

  @override
  String highMortalityMessage(int count) {
    return 'Wysoka śmiertelność · $count śnięć w ostatnich 7 dniach';
  }

  @override
  String followUpMeasurements(String status) {
    return '$status · wykonaj kolejne pomiary';
  }

  @override
  String get emptyTankMessage =>
      'Nie jest używany · można otworzyć i zarybić później';

  @override
  String normalMortalityMessage(int count) {
    return 'Normalna praca · śmiertelność 7d: $count';
  }

  @override
  String get allValuesNormal => 'Wszystkie wartości mieszczą się w normie';

  @override
  String get feed => 'Pasza';

  @override
  String get mortality => 'Śmiertelność';

  @override
  String get averageWeight => 'Średnia masa';

  @override
  String get temperature => 'Temperatura';

  @override
  String get history => 'Historia';

  @override
  String get tankInfo => 'Informacje o zbiorniku';

  @override
  String get weightSamples => 'Próby masy';

  @override
  String get growthForecast => 'Prognoza wzrostu';

  @override
  String get markReviewed => 'Sprawdzone';

  @override
  String get reviewedThisSession => 'Sprawdzone w tej sesji';

  @override
  String get feedLast24Hours => 'Pasza 24h';

  @override
  String get deathsLast7DaysShort => 'Śnięcia 7d';

  @override
  String get moreOptions => 'Więcej opcji';

  @override
  String get deleteTank => 'Usuń zbiornik';

  @override
  String get tankIllustration => 'Ilustracja zbiornika hodowlanego';

  @override
  String get tankNotesUnavailable => 'Notatki operacyjne są niedostępne';

  @override
  String get saveAndNext => 'Zapisz i następny';

  @override
  String get nextTank => 'Następny zbiornik';

  @override
  String get roleAdmin => 'Administrator';

  @override
  String get roleEmployee => 'Pracownik';

  @override
  String get roleReader => 'Podgląd';

  @override
  String get statusActive => 'Aktywny';

  @override
  String get statusDisabled => 'Wyłączony';

  @override
  String get dashboardUpdated => 'Panel główny został odświeżony';

  @override
  String get excelExportComplete => 'Eksport do Excel został ukończony';

  @override
  String get excelExportFailed =>
      'Nie można wyeksportować Excel. Spróbuj ponownie.';

  @override
  String get contentUnavailable =>
      'Powiązana zawartość jest teraz niedostępna.';

  @override
  String get loading => 'Ładowanie...';

  @override
  String get period => 'Okres';

  @override
  String get today => 'Dzisiaj';

  @override
  String get last7Days => 'Ostatnie 7 dni';

  @override
  String get last30Days => 'Ostatnie 30 dni';

  @override
  String get currentMonth => 'Bieżący miesiąc';

  @override
  String get customPeriod => 'Własny okres';

  @override
  String fromDate(String date) {
    return 'Od $date';
  }

  @override
  String toDate(String date) {
    return 'Do $date';
  }

  @override
  String get reportFor => 'Raport dla';

  @override
  String get entireFacility => 'Cały obiekt';

  @override
  String get buildingOrSection => 'Budynek/sekcja';

  @override
  String get singleTank => 'Pojedynczy zbiornik';

  @override
  String get selectBuildingOrTank => 'Wybierz budynek lub zbiornik';

  @override
  String get reportSelectionHint =>
      'Raport jest wyświetlany po zakończeniu wyboru.';

  @override
  String get reportCreationFailed => 'Nie można utworzyć raportu';

  @override
  String get reportCreationHint => 'Spróbuj ponownie. Sprawdź sieć i dostęp.';

  @override
  String get reportExportFailed =>
      'Nie można wyeksportować raportu. Spróbuj ponownie.';

  @override
  String get exportToExcel => 'Eksportuj do Excel';

  @override
  String get noRecordsSelectedPeriod => 'Brak rejestracji w wybranym okresie';

  @override
  String get reportDataAvailability =>
      'Status zbiornika i najnowsza biomasa są wyświetlane, gdy dane są dostępne.';

  @override
  String get feedUsed => 'Zużyta pasza';

  @override
  String get latestAverageWeight => 'Najnowsza średnia masa';

  @override
  String get weightChange => 'Zmiana masy';

  @override
  String get fcrUnavailable => 'Nie można obliczyć FCR';

  @override
  String get registrations => 'Rejestracje';

  @override
  String get noTanksForFilter =>
      'Nie znaleziono zbiorników dla wybranego filtra';

  @override
  String get section => 'Sekcja';

  @override
  String get dead => 'Śnięcia';

  @override
  String get temperatureShort => 'Temp.';

  @override
  String historyForTank(String tank) {
    return 'Historia - $tank';
  }

  @override
  String get noRecordsFound => 'Nie znaleziono rejestracji';

  @override
  String get changeFilterOrPeriod => 'Spróbuj zmienić filtr lub okres.';

  @override
  String get registrationType => 'Typ rejestracji';

  @override
  String get all => 'Wszystkie';

  @override
  String get notes => 'Notatki';

  @override
  String get resetFilter => 'Wyczyść filtr';

  @override
  String get unknownDate => 'Nieznana data';

  @override
  String mortalityAndFeed(String mortality, String feed) {
    return 'Śnięcia: $mortality  •  Pasza: $feed kg';
  }

  @override
  String feedTypeLine(String type) {
    return 'Typ paszy: $type';
  }

  @override
  String pelletLine(String size) {
    return 'Granulat: $size mm';
  }

  @override
  String noteLine(String note) {
    return 'Notatka: $note';
  }

  @override
  String tankInfoTitle(String tank) {
    return 'Informacje o zbiorniku - $tank';
  }

  @override
  String get couldNotFetchData =>
      'Nie można pobrać danych. Wróć i spróbuj ponownie.';

  @override
  String get calculating => 'Obliczanie...';

  @override
  String weightSampleForTank(String tank) {
    return 'Próba masy - $tank';
  }

  @override
  String get readerAccess => 'Dostęp tylko do odczytu';

  @override
  String readOnlyRole(String role) {
    return 'Jesteś zalogowany jako $role i możesz tylko przeglądać.';
  }

  @override
  String get emptyTankDescription =>
      'Zbiornik jest pusty. Dodaj ryby przed rejestracją prób masy.';

  @override
  String get simpleAverageWeight => 'Zwykła średnia masa';

  @override
  String get individualWeights => 'Pojedyncze masy';

  @override
  String get averageWeightGram => 'Średnia masa (g)';

  @override
  String get averageWeightInputHelp => 'Obsługuje 250, 250.5 i 250,5';

  @override
  String get saveAverageWeight => 'Zapisz średnią masę';

  @override
  String get weightInGrams => 'Masa w gramach';

  @override
  String get weightSampleInputHelp =>
      'Wpisz jedną masę lub wklej kilka mas oddzielonych spacjami, przecinkami lub nowymi wierszami.';

  @override
  String get add => 'Dodaj';

  @override
  String get clearList => 'Wyczyść listę';

  @override
  String get comment => 'Komentarz';

  @override
  String get optional => 'Opcjonalnie';

  @override
  String get saveWeightSample => 'Zapisz próbę masy';

  @override
  String get weightSamplesUnavailable => 'Próby masy są teraz niedostępne.';

  @override
  String get noWeightSamples => 'Nie zarejestrowano jeszcze prób masy.';

  @override
  String get latestWeightSample => 'Najnowsza próba masy';

  @override
  String get distribution => 'Rozkład';

  @override
  String get noDistribution => 'Brak dostępnego rozkładu.';

  @override
  String commentLine(String comment) {
    return 'Komentarz: $comment';
  }

  @override
  String weightGrowthTitle(String tank) {
    return 'Wzrost - $tank';
  }

  @override
  String get noWeightRecords => 'Brak rejestracji masy';

  @override
  String mortalityTitle(String tank) {
    return 'Śmiertelność - $tank';
  }

  @override
  String get noMortalityRecords => 'Brak danych o śmiertelności';

  @override
  String get totalMortality => 'Całkowita śmiertelność';

  @override
  String get numberOfRegistrations => 'Liczba rejestracji';

  @override
  String get moveFish => 'Przenieś ryby';

  @override
  String get moveFishValidation =>
      'Wybierz zbiornik docelowy i liczbę większą niż zero.';

  @override
  String get couldNotLoadTanks =>
      'Nie można pobrać zbiorników. Spróbuj ponownie.';

  @override
  String get noOtherTanks =>
      'Brak innych zbiorników, do których można przenieść ryby';

  @override
  String get fromTank => 'Ze zbiornika';

  @override
  String get moveToTank => 'Przenieś do zbiornika';

  @override
  String get fishToMove => 'Liczba ryb do przeniesienia';

  @override
  String get fishCountExample => 'Na przykład 2000';

  @override
  String get enterWeightFirst => 'Najpierw wpisz masę.';

  @override
  String invalidValuesNotAdded(String values) {
    return 'Nie dodano niektórych wartości: $values';
  }

  @override
  String get invalidAverageWeight => 'Nieprawidłowa średnia masa';

  @override
  String get averageWeightSaved => 'Średnia masa została zapisana';

  @override
  String get addWeightBeforeSaving =>
      'Dodaj co najmniej jedną masę przed zapisaniem.';

  @override
  String get weightSampleSaved => 'Próba masy została zapisana';

  @override
  String get emptyTankBeforeWeight =>
      'Zbiornik jest pusty. Dodaj liczbę ryb przed rejestracją masy.';

  @override
  String get noWriteAccess => 'Brak dostępu do zapisu';

  @override
  String get couldNotSaveWeight =>
      'Nie można zapisać masy. Wartości zostały zachowane. Spróbuj ponownie.';

  @override
  String get registerWeight => 'Zarejestruj masę';

  @override
  String get count => 'Liczba';

  @override
  String get average => 'Średnia';

  @override
  String get median => 'Mediana';

  @override
  String get minimum => 'Min.';

  @override
  String get maximum => 'Maks.';

  @override
  String get standardDeviation => 'Odch. std.';

  @override
  String get unknownTime => 'Nieznany czas';

  @override
  String get averageWeightOverTime => 'Średnia masa w czasie';

  @override
  String get mortalityPerRegistration => 'Śmiertelność na rejestrację';

  @override
  String get manageUsersSubtitle =>
      'Zarządzaj użytkownikami wewnętrznymi, rolami i zaproszeniami.';

  @override
  String get inviteUser => 'Zaproś użytkownika';

  @override
  String get couldNotUpdateUser => 'Nie można zaktualizować użytkownika';

  @override
  String get usersUnavailable => 'Nie można teraz pobrać użytkowników.';

  @override
  String get searchUsers => 'Szukaj użytkownika...';

  @override
  String get noUsersFound => 'Nie znaleziono użytkowników';

  @override
  String get roleUpdated => 'Rola została zaktualizowana';

  @override
  String get userDisabled => 'Użytkownik wyłączony';

  @override
  String get userEnabled => 'Użytkownik aktywowany';

  @override
  String get unknownEmail => 'Nieznany e-mail';

  @override
  String get activateUser => 'Aktywuj użytkownika';

  @override
  String get deactivateUser => 'Dezaktywuj użytkownika';

  @override
  String get actions => 'Działania';

  @override
  String get invitationLinkCopied => 'Link zaproszenia skopiowany';

  @override
  String get revokeInvitationQuestion => 'Cofnąć zaproszenie?';

  @override
  String get revokeInvitation => 'Cofnij';

  @override
  String get invitationRevoked => 'Zaproszenie zostało cofnięte';

  @override
  String get couldNotRevokeInvitation => 'Nie można cofnąć zaproszenia';

  @override
  String get invitationsUnavailable => 'Zaproszenia nie są jeszcze dostępne.';

  @override
  String get invitations => 'Zaproszenia';

  @override
  String get noInvitations => 'Nie utworzono jeszcze zaproszeń';

  @override
  String get invitationActions => 'Działania zaproszenia';

  @override
  String get copyInvitationLink => 'Kopiuj link zaproszenia';

  @override
  String get invitePanelTitle => 'Zaproś użytkownika';

  @override
  String get nameOptional => 'Imię i nazwisko (opcjonalnie)';

  @override
  String get fullNameHint => 'Wpisz pełne imię i nazwisko';

  @override
  String get emailHint => 'nazwa@poczta.pl';

  @override
  String get role => 'Rola';

  @override
  String get invitationRoleInfo =>
      'Rola jest przypisana do zaproszenia. Link jest ważny przez 7 dni.';

  @override
  String get createInvitation => 'Utwórz zaproszenie';

  @override
  String get invitationCreated => 'Zaproszenie utworzone';

  @override
  String get couldNotCreateInvitation => 'Nie można utworzyć zaproszenia';

  @override
  String get invitationReady => 'Zaproszenie jest gotowe do wysłania.';

  @override
  String get copyInvitationText => 'Kopiuj tekst zaproszenia';

  @override
  String get accessDeniedUserAdmin =>
      'Nie masz dostępu do zarządzania użytkownikami';

  @override
  String get notRegistered => 'Nie zarejestrowano';

  @override
  String expiresOn(String date) {
    return 'wygasa $date';
  }

  @override
  String adjustBagsForFeed(String feed) {
    return 'Dostosuj $feed';
  }

  @override
  String get bagsToAdjust => 'Liczba worków (+ / -)';

  @override
  String get bagsAdjustHint => 'Na przykład 10 lub -3';

  @override
  String kgPerBagForFeed(String feed) {
    return 'Kg na worek - $feed';
  }

  @override
  String get kgPerBag => 'Kg na worek';

  @override
  String get feedType => 'Typ paszy';

  @override
  String get newFeedType => 'Nowy typ paszy';

  @override
  String get editFeedType => 'Edytuj typ paszy';

  @override
  String get feedName => 'Nazwa';

  @override
  String get pelletSize => 'Rozmiar granulatu mm';

  @override
  String get feedNameAndPelletRequired =>
      'Nazwa i rozmiar granulatu są wymagane.';

  @override
  String get cannotDeactivateFeedWithStock =>
      'Nie można dezaktywować typu paszy z workami w magazynie.';

  @override
  String get activeFeedInventory => 'Aktywny magazyn paszy';

  @override
  String readOnlyInventoryRole(String role) {
    return 'Jesteś zalogowany jako $role i możesz tylko przeglądać magazyn.';
  }

  @override
  String get inactiveFeedType => 'Nieaktywny typ paszy';

  @override
  String bags(int count) {
    return '$count worków';
  }

  @override
  String get adjustBags => 'Dostosuj worki';

  @override
  String get editKgPerBag => 'Edytuj kg na worek';

  @override
  String get inventoryHistory => 'Historia magazynu';

  @override
  String get noInventoryHistory => 'Brak historii magazynu';

  @override
  String get unknownFeed => 'Nieznana pasza';

  @override
  String get tankCount => 'Aktualna liczba ryb';

  @override
  String get adjustFishCount => 'Dostosuj liczbę ryb';

  @override
  String get newFishCount => 'Nowa liczba ryb';

  @override
  String get unsavedChanges => 'Niezapisane zmiany';

  @override
  String get leaveWithoutSaving =>
      'Przejść do następnego zbiornika bez zapisywania nowych wartości?';

  @override
  String get newOperationalNote => 'Nowa notatka operacyjna';

  @override
  String get editOperationalNote => 'Edytuj notatkę operacyjną';

  @override
  String get noteHint => 'Na przykład: zbyt dużo strat paszy';

  @override
  String get operationalNoteSaved => 'Notatka operacyjna zapisana';

  @override
  String get operationalNoteSaveFailed =>
      'Nie można zapisać notatki operacyjnej. Spróbuj ponownie.';

  @override
  String get operationalNoteCompleted =>
      'Notatka operacyjna oznaczona jako ukończona';

  @override
  String get newNote => 'Nowa notatka';

  @override
  String get edit => 'Edytuj';

  @override
  String get markCompleted => 'Oznacz jako ukończone';

  @override
  String get createOperationalNote => 'Utwórz notatkę operacyjną';

  @override
  String completedNotes(int count) {
    return 'Ukończone notatki ($count)';
  }

  @override
  String get otherFeedType => 'Inny typ paszy z magazynu';

  @override
  String get otherFeedTypeHint =>
      'Wybierz, gdy podano inną paszę niż zalecana.';

  @override
  String get selectFeedType => 'Wybierz typ paszy';

  @override
  String get useRecommendedFeedType => 'Użyj zalecanego typu paszy';

  @override
  String get dailyFeedRation => 'Zalecana dzienna racja paszy';

  @override
  String get mortalityInput => 'Śmiertelność';

  @override
  String get feedKgInput => 'Pasza (kg)';

  @override
  String get averageWeightOptional => 'Średnia masa (g) – opcjonalnie';

  @override
  String get temperatureInput => 'Temperatura';

  @override
  String get day => 'Dzień';

  @override
  String get month => 'Miesiąc';

  @override
  String get year => 'Rok';

  @override
  String get goToToday => 'Przejdź do dzisiaj';

  @override
  String get searchEntries => 'Szukaj wpisów';

  @override
  String get category => 'Kategoria';

  @override
  String get allCategories => 'Wszystkie kategorie';

  @override
  String get printMonth => 'Drukuj miesiąc';

  @override
  String get printYear => 'Drukuj rok';

  @override
  String get noDiaryEntries => 'Brak wpisów w dzienniku w wybranym okresie';

  @override
  String get diaryUnavailablePermission =>
      'Dziennik operacyjny jest niedostępny, dopóki reguły dostępu nie zostaną zaktualizowane.';

  @override
  String get diaryLoadFailed =>
      'Nie można teraz załadować dziennika operacyjnego. Reszta panelu działa normalnie.';

  @override
  String get diaryLoadingLong =>
      'Dziennik operacyjny długo odpowiada. Reszta panelu działa normalnie.';

  @override
  String get diaryEntrySaved => 'Wpis w dzienniku zapisany';

  @override
  String get diaryEntryUpdated => 'Wpis w dzienniku zaktualizowany';

  @override
  String get diaryEntryArchived => 'Wpis w dzienniku zarchiwizowany';

  @override
  String get couldNotSaveDiaryEntry => 'Nie można zapisać wpisu w dzienniku';

  @override
  String get couldNotUpdateDiaryEntry =>
      'Nie można zaktualizować wpisu w dzienniku';

  @override
  String get couldNotArchiveDiaryEntry =>
      'Nie można zarchiwizować wpisu w dzienniku';

  @override
  String get couldNotOpenPrint => 'Nie można otworzyć podglądu wydruku';

  @override
  String get archiveEntryQuestion => 'Archiwizować wpis?';

  @override
  String archiveEntryBody(String title) {
    return '„$title” zostanie usunięty z aktywnego dziennika.';
  }

  @override
  String get archive => 'Archiwizuj';

  @override
  String get editEntry => 'Edytuj wpis';

  @override
  String get entryTitle => 'Tytuł';

  @override
  String get entryContent => 'Tekst / treść';

  @override
  String get entryActions => 'Działania wpisu';

  @override
  String get printEntry => 'Drukuj wpis';

  @override
  String diaryEntriesInView(int count) {
    return '$count wpisów w tym widoku';
  }

  @override
  String moreDiaryEntries(int count) {
    return '$count więcej wpisów jest dostępnych w pełnym dzienniku.';
  }

  @override
  String get couldNotUpdateFeedInventory =>
      'Nie można zaktualizować magazynu paszy. Spróbuj ponownie.';

  @override
  String get editKgHint => 'Użyj ołówka na karcie, aby zmienić kg na worek.';

  @override
  String get pelletNotSet => 'Rozmiar granulatu nieustawiony';

  @override
  String afterBags(String count) {
    return 'Po: $count worków';
  }

  @override
  String get dateTimeSavedAutomatically =>
      'Data i godzina są zapisywane automatycznie.';

  @override
  String get originalDatePreserved =>
      'Pierwotna data zostaje zachowana. Czas zmiany jest zapisywany automatycznie.';

  @override
  String get saving => 'Zapisywanie…';

  @override
  String get openingNext => 'Otwieranie następnego…';

  @override
  String get growthChart => 'Wykres wzrostu';

  @override
  String get mortalityChart => 'Wykres śmiertelności';

  @override
  String get noActiveOperationalNote => 'Brak aktywnej notatki operacyjnej.';

  @override
  String writtenBy(String email) {
    return 'Napisał: $email';
  }

  @override
  String completedAt(String date) {
    return 'Ukończono: $date';
  }

  @override
  String get averageWeightMissingForBiomass =>
      'Zarejestruj średnią masę, aby obliczyć biomasę';

  @override
  String get emptyTankActivateHint =>
      'Nie jest używany. Użyj ołówka, aby dodać liczbę ryb i aktywować zbiornik.';

  @override
  String get leaveWeightEmptyHint =>
      'Pozostaw puste, jeśli ryby nie były dziś ważone';

  @override
  String get feedInventoryLoadFailed =>
      'Nie można teraz załadować magazynu paszy.';

  @override
  String get noActiveFeedUsesRecommended =>
      'Brak aktywnych typów paszy w magazynie. Używana jest zalecana pasza.';

  @override
  String get recommendedFeedUsed => 'Nie wybrano - używany zalecany typ paszy';

  @override
  String get selectedFeedDrawnFromInventory =>
      'Wybrany typ paszy zostanie odjęty z magazynu';

  @override
  String get feedSelectionOptionalHint =>
      'Opcjonalne. Używane tylko, gdy podajesz paszę inną niż zalecana.';

  @override
  String get recommendedFeedType => 'Zalecany typ paszy';

  @override
  String get stockLevel => 'Stan magazynowy';

  @override
  String get checkingStock => 'Sprawdzanie magazynu...';

  @override
  String get notAvailable => 'Niedostępne';

  @override
  String get notFoundInActiveInventory =>
      'Nie znaleziono w aktywnym magazynie paszy';

  @override
  String get recommendedDailyFeedAmount => 'Zalecana dzienna ilość paszy';

  @override
  String get feedPercent => 'Procent paszy';

  @override
  String get startWeight => 'Masa początkowa';

  @override
  String get endWeight => 'Masa końcowa';

  @override
  String get biomassGain => 'Przyrost biomasy';

  @override
  String get currentAverageWeight => 'Aktualna średnia masa';

  @override
  String forecastDays(int days) {
    return 'Prognoza na $days dni';
  }

  @override
  String get dataBasis => 'Podstawa danych';

  @override
  String daysCount(int count) {
    return '$count dni';
  }

  @override
  String get invited => 'Zostałeś zaproszony';

  @override
  String roleLine(String role) {
    return 'Rola: $role';
  }

  @override
  String get passwordMinimum => 'Hasło musi mieć co najmniej 6 znaków';

  @override
  String get passwordsDoNotMatch => 'Hasła nie są takie same';

  @override
  String get confirmPassword => 'Powtórz hasło';

  @override
  String get showPassword => 'Pokaż hasło';

  @override
  String get hidePassword => 'Ukryj hasło';

  @override
  String get signInAndAccept => 'Zaloguj się i zaakceptuj';

  @override
  String get createAccount => 'Utwórz konto';

  @override
  String get needNewAccount => 'Potrzebuję nowego konta';

  @override
  String get alreadyHaveAccount => 'Mam już konto';

  @override
  String get invalidInvitation => 'Zaproszenie jest nieprawidłowe lub wygasło';

  @override
  String get askAdminForInvitation =>
      'Poproś administratora o utworzenie nowego zaproszenia.';

  @override
  String get serviceTimedOut =>
      'Usługa odpowiadała zbyt długo. Spróbuj ponownie.';

  @override
  String get couldNotCompleteInvitation => 'Nie można ukończyć zaproszenia';

  @override
  String wrongSignedInUser(String email) {
    return 'Jesteś zalogowany jako $email. Wyloguj się, aby użyć tego zaproszenia.';
  }

  @override
  String get logoutQuestion => 'Wylogować się?';

  @override
  String get logoutConfirmation => 'Czy na pewno chcesz się wylogować?';

  @override
  String get dashboardLoadTimeout =>
      'Ładowanie danych operacyjnych trwało zbyt długo. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get dashboardPermissionDenied =>
      'Użytkownik nie ma dostępu do danych operacyjnych. Skontaktuj się z administratorem.';

  @override
  String get dashboardUnavailable =>
      'Dane operacyjne są tymczasowo niedostępne. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get dashboardLoadFailed =>
      'Nie można teraz załadować panelu głównego. Spróbuj ponownie.';

  @override
  String get signedInUser => 'Zalogowany użytkownik';

  @override
  String get tankUnavailable => 'Zbiornik nie jest już dostępny w przeglądzie.';

  @override
  String get unknownTank => 'Nieznany zbiornik';

  @override
  String get tankNameExample => 'Np. K1';

  @override
  String get fishCountLargeExample => 'Np. 12500';

  @override
  String get operationalNote => 'Notatka operacyjna';

  @override
  String deleteTankQuestion(String tank) {
    return 'Usunąć $tank?';
  }

  @override
  String get deleteTankConfirmation =>
      'Zbiornik zostanie usunięty z przeglądu. Tej czynności nie można cofnąć.';

  @override
  String get couldNotMoveFish => 'Nie można przenieść ryb. Spróbuj ponownie.';

  @override
  String get kgPerBagExample => 'Np. 25';

  @override
  String get feedNameExample => 'Np. Nutra Olympic 3.0';

  @override
  String get pelletSizeExample => 'Np. 3.0';

  @override
  String sampleSummary(String weight, int count) {
    return 'średnio $weight g ($count ryb)';
  }

  @override
  String get invitationStatusPending => 'Oczekuje';

  @override
  String get invitationStatusAccepted => 'Zaakceptowano';

  @override
  String get invitationStatusRevoked => 'Cofnięto';

  @override
  String get invitationStatusExpired => 'Wygasło';

  @override
  String get enterEntryTitle => 'Wpisz tytuł';

  @override
  String get enterEntryContent => 'Wpisz tekst';

  @override
  String get previousPeriod => 'Poprzedni okres';

  @override
  String get nextPeriod => 'Następny okres';

  @override
  String get dataPermissionDenied =>
      'Nie masz dostępu do tych danych. Skontaktuj się z administratorem.';

  @override
  String get dataLoadFailed =>
      'Nie można pobrać danych. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get noAverageWeightRegistered =>
      'Nie zarejestrowano jeszcze średniej masy';

  @override
  String weightUntilFeed(String weight, String feed) {
    return 'Do $feed pozostało $weight g';
  }

  @override
  String get finishFeedLargeFish => 'Pasza końcowa / duże ryby';

  @override
  String invalidValue(String label) {
    return 'Nieprawidłowe: $label';
  }

  @override
  String get invalidMortality => 'Nieprawidłowa śmiertelność';

  @override
  String get enterAtLeastOneRegistration =>
      'Wprowadź co najmniej jedną rejestrację.';

  @override
  String get noRegistrationAccess => 'Nie masz uprawnień do rejestrowania.';

  @override
  String get tankNoLongerExists => 'Ten zbiornik już nie istnieje.';

  @override
  String get emptyTankBeforeRegistration =>
      'Zbiornik jest pusty. Wprowadź liczbę ryb przed rejestracją działań.';

  @override
  String get mortalityExceedsFishCount =>
      'Śmiertelność nie może być większa niż liczba ryb.';

  @override
  String get selectedFeedTypeMissing => 'Wybrany typ paszy nie istnieje.';

  @override
  String insufficientFeedInStock(String amount) {
    return 'Za mało paszy w magazynie. Dostępne: $amount kg.';
  }

  @override
  String get registrationCancelled => 'Rejestracja została anulowana.';

  @override
  String get registrationSaved => 'Rejestracja zapisana';

  @override
  String get registrationSaveFailed =>
      'Nie można zapisać rejestracji. Spróbuj ponownie.';

  @override
  String get allTanksReviewed =>
      'Wszystkie zbiorniki w tej sekcji zostały sprawdzone.';

  @override
  String get nextTankOpenFailed =>
      'Rejestracja została zapisana, ale nie można było otworzyć następnego zbiornika. Spróbuj ponownie.';

  @override
  String get overview => 'Przegląd';

  @override
  String get tools => 'Narzędzia';

  @override
  String latestAverageWeightLine(String weight) {
    return 'Ostatnia średnia masa: $weight';
  }

  @override
  String get registerAverageWeightForFeed =>
      'Zarejestruj średnią masę, aby obliczyć dawkę paszy';

  @override
  String sgrOverDays(String sgr, int days) {
    return 'SGR: $sgr %/dzień przez $days dni';
  }

  @override
  String get fullName => 'Imię i nazwisko';

  @override
  String get emailAlreadyRegistered =>
      'Ten adres e-mail jest już zarejestrowany.';

  @override
  String get activeInvitationExists =>
      'Dla tego adresu e-mail istnieje już aktywne zaproszenie.';

  @override
  String get invalidRole => 'Nieprawidłowa rola.';

  @override
  String get inviteServiceUnavailable =>
      'Usługa zaproszeń jest niedostępna. Spróbuj ponownie.';

  @override
  String get signInWithInvitedEmail =>
      'Zaloguj się adresem e-mail, na który wysłano zaproszenie.';

  @override
  String get invitationGreeting => 'Witaj!';

  @override
  String invitationGreetingNamed(String name) {
    return 'Witaj, $name!';
  }

  @override
  String invitationCopyBody(String email, String link) {
    return 'Zostałeś zaproszony do Fjellfisk dla Arctic Hardanger.\n\nOtwórz link i zarejestruj się lub zaloguj tym adresem e-mail:\n$email\n\nLink:\n$link\n\nPozdrawiamy\nArctic Hardanger';
  }

  @override
  String get startingApp => 'Uruchamianie Fjellfisk...';

  @override
  String get startupFailedTitle => 'Nie można uruchomić aplikacji';

  @override
  String get startupFailedMessage =>
      'Sprawdź połączenie z internetem i spróbuj ponownie. Jeśli problem będzie się powtarzał, skontaktuj się z administratorem.';

  @override
  String get checkingLogin => 'Sprawdzanie logowania...';

  @override
  String get checkingAccess => 'Sprawdzanie dostępu...';

  @override
  String get loginCheckFailedTitle => 'Nie można sprawdzić logowania';

  @override
  String get loginCheckFailedMessage =>
      'Aplikacja nie może połączyć się z usługą logowania. Spróbuj ponownie.';

  @override
  String get accessDeniedTitle => 'Brak dostępu';

  @override
  String get accessDeniedMessage =>
      'Nie masz dostępu do Fjellfisk. Skontaktuj się z administratorem.';

  @override
  String get roleCheckFailedTitle => 'Nie można sprawdzić dostępu';

  @override
  String get roleCheckFailedMessage =>
      'Aplikacja nie może odczytać Twojej roli. Skontaktuj się z administratorem, jeśli niedawno otrzymałeś konto lub rolę.';

  @override
  String get userDisabledTitle => 'Użytkownik jest wyłączony';

  @override
  String get userDisabledDetail =>
      'Skontaktuj się z administratorem, jeśli ponownie potrzebujesz dostępu.';

  @override
  String get excelSheetFacility => 'Obiekt';

  @override
  String get excelSheetTank => 'Zbiornik';

  @override
  String get excelSheetSummary => 'Podsumowanie';

  @override
  String get excelSheetTankOverview => 'Przegląd zbiorników';

  @override
  String get excelSheetRegistrations => 'Rejestracje';

  @override
  String get keyFigures => 'Kluczowe dane';

  @override
  String get productionReportTitle => 'Raport produkcyjny';

  @override
  String get filter => 'Filtr';

  @override
  String get value => 'Wartość';

  @override
  String get registeredBiomassKg => 'Zarejestrowana biomasa kg';

  @override
  String get latestAverageWeightGram => 'Ostatnia średnia masa g';

  @override
  String get weightChangeGram => 'Zmiana masy g';

  @override
  String get averageTemperatureLabel => 'Średnia temperatura';

  @override
  String get minimumTemperatureLabel => 'Temperatura minimalna';

  @override
  String get maximumTemperatureLabel => 'Temperatura maksymalna';

  @override
  String get facilityName => 'Nazwa obiektu';

  @override
  String get sectionBuilding => 'Sekcja/budynek';

  @override
  String get date => 'Data';

  @override
  String get feedKg => 'Pasza kg';

  @override
  String get diaryPdfTitle => 'Fjellfisk Dziennik / Dziennik operacyjny';

  @override
  String get noDiaryEntriesForPeriod => 'Brak wpisów w wybranym okresie.';

  @override
  String get dateMissing => 'Brak daty';

  @override
  String get unknownUser => 'Nieznany użytkownik';

  @override
  String get untitled => 'Bez tytułu';

  @override
  String pageOf(int current, int total) {
    return 'Strona $current z $total';
  }
}

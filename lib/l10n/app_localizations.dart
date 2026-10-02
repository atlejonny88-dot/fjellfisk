import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_nb.dart';
import 'app_localizations_pl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('nb'),
    Locale('pl')
  ];

  /// No description provided for @appTitle.
  ///
  /// In nb, this message translates to:
  /// **'Fjellfisk'**
  String get appTitle;

  /// No description provided for @norwegian.
  ///
  /// In nb, this message translates to:
  /// **'Norsk'**
  String get norwegian;

  /// No description provided for @english.
  ///
  /// In nb, this message translates to:
  /// **'Engelsk'**
  String get english;

  /// No description provided for @polish.
  ///
  /// In nb, this message translates to:
  /// **'Polsk'**
  String get polish;

  /// No description provided for @language.
  ///
  /// In nb, this message translates to:
  /// **'Språk'**
  String get language;

  /// No description provided for @changeLanguage.
  ///
  /// In nb, this message translates to:
  /// **'Bytt språk'**
  String get changeLanguage;

  /// No description provided for @languageSaveFailed.
  ///
  /// In nb, this message translates to:
  /// **'Språkvalget kunne ikke lagres ennå. Språket brukes likevel i denne økten.'**
  String get languageSaveFailed;

  /// No description provided for @dashboard.
  ///
  /// In nb, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @refresh.
  ///
  /// In nb, this message translates to:
  /// **'Oppdater'**
  String get refresh;

  /// No description provided for @refreshDashboard.
  ///
  /// In nb, this message translates to:
  /// **'Oppdater dashboard'**
  String get refreshDashboard;

  /// No description provided for @updating.
  ///
  /// In nb, this message translates to:
  /// **'Oppdaterer'**
  String get updating;

  /// No description provided for @logout.
  ///
  /// In nb, this message translates to:
  /// **'Logg ut'**
  String get logout;

  /// No description provided for @facility.
  ///
  /// In nb, this message translates to:
  /// **'Anlegg'**
  String get facility;

  /// No description provided for @user.
  ///
  /// In nb, this message translates to:
  /// **'Bruker'**
  String get user;

  /// No description provided for @diary.
  ///
  /// In nb, this message translates to:
  /// **'Dagbok / Driftslogg'**
  String get diary;

  /// No description provided for @productionReport.
  ///
  /// In nb, this message translates to:
  /// **'Produksjonsrapport'**
  String get productionReport;

  /// No description provided for @feedInventory.
  ///
  /// In nb, this message translates to:
  /// **'Fôrlager'**
  String get feedInventory;

  /// No description provided for @excelExport.
  ///
  /// In nb, this message translates to:
  /// **'Excel-eksport'**
  String get excelExport;

  /// No description provided for @usersAndAccess.
  ///
  /// In nb, this message translates to:
  /// **'Brukere & Tilganger'**
  String get usersAndAccess;

  /// No description provided for @activeTanks.
  ///
  /// In nb, this message translates to:
  /// **'Aktive kar'**
  String get activeTanks;

  /// No description provided for @tanksOfTotal.
  ///
  /// In nb, this message translates to:
  /// **'av {count} kar'**
  String tanksOfTotal(int count);

  /// No description provided for @emptyTanks.
  ///
  /// In nb, this message translates to:
  /// **'{count} tomme kar'**
  String emptyTanks(int count);

  /// No description provided for @emptyTanksLabel.
  ///
  /// In nb, this message translates to:
  /// **'Tomme kar'**
  String get emptyTanksLabel;

  /// No description provided for @biomass.
  ///
  /// In nb, this message translates to:
  /// **'Biomasse'**
  String get biomass;

  /// No description provided for @fishCount.
  ///
  /// In nb, this message translates to:
  /// **'{count} fisk'**
  String fishCount(int count);

  /// No description provided for @fish.
  ///
  /// In nb, this message translates to:
  /// **'Fisk'**
  String get fish;

  /// No description provided for @activeAndEmptyTanks.
  ///
  /// In nb, this message translates to:
  /// **'{active} aktive / {empty} tomme'**
  String activeAndEmptyTanks(int active, int empty);

  /// No description provided for @recommendedFeedLabel.
  ///
  /// In nb, this message translates to:
  /// **'Anbefalt fôr'**
  String get recommendedFeedLabel;

  /// No description provided for @activeBiomass.
  ///
  /// In nb, this message translates to:
  /// **'Aktiv biomasse'**
  String get activeBiomass;

  /// No description provided for @feedToday.
  ///
  /// In nb, this message translates to:
  /// **'Fôr i dag'**
  String get feedToday;

  /// No description provided for @actualRecorded.
  ///
  /// In nb, this message translates to:
  /// **'Faktisk registrert'**
  String get actualRecorded;

  /// No description provided for @recommendedFeed.
  ///
  /// In nb, this message translates to:
  /// **'Anbefalt {amount} kg'**
  String recommendedFeed(String amount);

  /// No description provided for @deadToday.
  ///
  /// In nb, this message translates to:
  /// **'Døde i dag'**
  String get deadToday;

  /// No description provided for @recordedMortality.
  ///
  /// In nb, this message translates to:
  /// **'Registrert dødelighet'**
  String get recordedMortality;

  /// No description provided for @noneRecordedToday.
  ///
  /// In nb, this message translates to:
  /// **'Ingen registrert i dag'**
  String get noneRecordedToday;

  /// No description provided for @numberOfFish.
  ///
  /// In nb, this message translates to:
  /// **'Antall fisk'**
  String get numberOfFish;

  /// No description provided for @averageTemperature.
  ///
  /// In nb, this message translates to:
  /// **'Snittemperatur'**
  String get averageTemperature;

  /// No description provided for @recordedMeasurements.
  ///
  /// In nb, this message translates to:
  /// **'Registrerte målinger'**
  String get recordedMeasurements;

  /// No description provided for @updatedFromTankLogs.
  ///
  /// In nb, this message translates to:
  /// **'Oppdatert fra karlogger'**
  String get updatedFromTankLogs;

  /// No description provided for @noData.
  ///
  /// In nb, this message translates to:
  /// **'Ingen data'**
  String get noData;

  /// No description provided for @notEnoughData.
  ///
  /// In nb, this message translates to:
  /// **'Ikke nok data'**
  String get notEnoughData;

  /// No description provided for @buildings.
  ///
  /// In nb, this message translates to:
  /// **'Bygg'**
  String get buildings;

  /// No description provided for @sectionsWithTanks.
  ///
  /// In nb, this message translates to:
  /// **'{sections} seksjoner med {tanks} kar'**
  String sectionsWithTanks(int sections, int tanks);

  /// No description provided for @exportFacilityToExcel.
  ///
  /// In nb, this message translates to:
  /// **'Eksporter anlegget til Excel'**
  String get exportFacilityToExcel;

  /// No description provided for @operationalTools.
  ///
  /// In nb, this message translates to:
  /// **'Driftsverktøy'**
  String get operationalTools;

  /// No description provided for @operationalToolsSubtitle.
  ///
  /// In nb, this message translates to:
  /// **'Rapporter, lager og administrasjon'**
  String get operationalToolsSubtitle;

  /// No description provided for @reportSubtitle.
  ///
  /// In nb, this message translates to:
  /// **'Se nøkkeltall for valgt periode'**
  String get reportSubtitle;

  /// No description provided for @feedInventorySubtitle.
  ///
  /// In nb, this message translates to:
  /// **'Se beholdning og lagerhistorikk'**
  String get feedInventorySubtitle;

  /// No description provided for @excelSubtitle.
  ///
  /// In nb, this message translates to:
  /// **'Eksporter komplett anleggsoversikt'**
  String get excelSubtitle;

  /// No description provided for @accessSubtitle.
  ///
  /// In nb, this message translates to:
  /// **'Endre roller og tilgang'**
  String get accessSubtitle;

  /// No description provided for @retry.
  ///
  /// In nb, this message translates to:
  /// **'Prøv igjen'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In nb, this message translates to:
  /// **'Avbryt'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In nb, this message translates to:
  /// **'Lagre'**
  String get save;

  /// No description provided for @create.
  ///
  /// In nb, this message translates to:
  /// **'Opprett'**
  String get create;

  /// No description provided for @close.
  ///
  /// In nb, this message translates to:
  /// **'Lukk'**
  String get close;

  /// No description provided for @notifications.
  ///
  /// In nb, this message translates to:
  /// **'Varsler'**
  String get notifications;

  /// No description provided for @unreadNotifications.
  ///
  /// In nb, this message translates to:
  /// **'{count} uleste varsler'**
  String unreadNotifications(int count);

  /// No description provided for @noUnreadNotifications.
  ///
  /// In nb, this message translates to:
  /// **'Ingen uleste varsler'**
  String get noUnreadNotifications;

  /// No description provided for @markAllRead.
  ///
  /// In nb, this message translates to:
  /// **'Marker alle som lest'**
  String get markAllRead;

  /// No description provided for @marking.
  ///
  /// In nb, this message translates to:
  /// **'Markerer...'**
  String get marking;

  /// No description provided for @markAsRead.
  ///
  /// In nb, this message translates to:
  /// **'Marker som lest'**
  String get markAsRead;

  /// No description provided for @closeNotifications.
  ///
  /// In nb, this message translates to:
  /// **'Lukk varsler'**
  String get closeNotifications;

  /// No description provided for @noNotifications.
  ///
  /// In nb, this message translates to:
  /// **'Ingen varsler'**
  String get noNotifications;

  /// No description provided for @notificationsUnavailable.
  ///
  /// In nb, this message translates to:
  /// **'Varsler er ikke tilgjengelige nå'**
  String get notificationsUnavailable;

  /// No description provided for @notificationsUnavailableDetail.
  ///
  /// In nb, this message translates to:
  /// **'Resten av Fjellfisk fungerer som normalt. Prøv igjen senere.'**
  String get notificationsUnavailableDetail;

  /// No description provided for @noNotificationsDetail.
  ///
  /// In nb, this message translates to:
  /// **'Nye driftsvarsler vises her.'**
  String get noNotificationsDetail;

  /// No description provided for @todayAt.
  ///
  /// In nb, this message translates to:
  /// **'I dag {time}'**
  String todayAt(String time);

  /// No description provided for @yesterdayAt.
  ///
  /// In nb, this message translates to:
  /// **'I går {time}'**
  String yesterdayAt(String time);

  /// No description provided for @couldNotOpenNotification.
  ///
  /// In nb, this message translates to:
  /// **'Kunne ikke åpne varselet. Prøv igjen.'**
  String get couldNotOpenNotification;

  /// No description provided for @couldNotMarkNotificationRead.
  ///
  /// In nb, this message translates to:
  /// **'Kunne ikke markere varselet som lest.'**
  String get couldNotMarkNotificationRead;

  /// No description provided for @couldNotMarkAllNotificationsRead.
  ///
  /// In nb, this message translates to:
  /// **'Kunne ikke markere alle varslene som lest.'**
  String get couldNotMarkAllNotificationsRead;

  /// No description provided for @newVersionAvailable.
  ///
  /// In nb, this message translates to:
  /// **'Ny Fjellfisk-versjon tilgjengelig'**
  String get newVersionAvailable;

  /// No description provided for @updateWhenSaved.
  ///
  /// In nb, this message translates to:
  /// **'Oppdater appen når du har lagret eventuelle endringer.'**
  String get updateWhenSaved;

  /// No description provided for @highMortality.
  ///
  /// In nb, this message translates to:
  /// **'Høy dødelighet'**
  String get highMortality;

  /// No description provided for @highMortalityTank.
  ///
  /// In nb, this message translates to:
  /// **'Høy dødelighet i {tank}'**
  String highMortalityTank(String tank);

  /// No description provided for @deathsLast7Days.
  ///
  /// In nb, this message translates to:
  /// **'{count} døde siste 7 dager. Kontroller karet og registreringene.'**
  String deathsLast7Days(int count);

  /// No description provided for @lowFeedStock.
  ///
  /// In nb, this message translates to:
  /// **'Lavt fôrlager'**
  String get lowFeedStock;

  /// No description provided for @lowFeedStockItem.
  ///
  /// In nb, this message translates to:
  /// **'Lavt fôrlager: {feed}'**
  String lowFeedStockItem(String feed);

  /// No description provided for @feedStockBody.
  ///
  /// In nb, this message translates to:
  /// **'{stock} kg igjen. Varselgrense er {threshold} kg (én sekk).'**
  String feedStockBody(String stock, String threshold);

  /// No description provided for @newTankNote.
  ///
  /// In nb, this message translates to:
  /// **'Nytt driftsnotat på {tank}'**
  String newTankNote(String tank);

  /// No description provided for @newDiaryEntry.
  ///
  /// In nb, this message translates to:
  /// **'Nytt innlegg'**
  String get newDiaryEntry;

  /// No description provided for @newDiaryEntryTitle.
  ///
  /// In nb, this message translates to:
  /// **'Nytt dagbokinnlegg: {title}'**
  String newDiaryEntryTitle(String title);

  /// No description provided for @login.
  ///
  /// In nb, this message translates to:
  /// **'Logg inn'**
  String get login;

  /// No description provided for @loginTagline.
  ///
  /// In nb, this message translates to:
  /// **'Drift. Oversikt. Kontroll.'**
  String get loginTagline;

  /// No description provided for @loginContinue.
  ///
  /// In nb, this message translates to:
  /// **'Logg inn for å fortsette'**
  String get loginContinue;

  /// No description provided for @signingIn.
  ///
  /// In nb, this message translates to:
  /// **'Logger inn'**
  String get signingIn;

  /// No description provided for @appVersion.
  ///
  /// In nb, this message translates to:
  /// **'Fjellfisk v{version}'**
  String appVersion(String version);

  /// No description provided for @email.
  ///
  /// In nb, this message translates to:
  /// **'E-post'**
  String get email;

  /// No description provided for @password.
  ///
  /// In nb, this message translates to:
  /// **'Passord'**
  String get password;

  /// No description provided for @forgotPassword.
  ///
  /// In nb, this message translates to:
  /// **'Glemt passord?'**
  String get forgotPassword;

  /// No description provided for @signIn.
  ///
  /// In nb, this message translates to:
  /// **'Logg inn'**
  String get signIn;

  /// No description provided for @enterEmailAndPassword.
  ///
  /// In nb, this message translates to:
  /// **'Skriv inn e-post og passord.'**
  String get enterEmailAndPassword;

  /// No description provided for @loginTimeout.
  ///
  /// In nb, this message translates to:
  /// **'Innlogging tok for lang tid. Lukk Safari helt og prøv igjen.'**
  String get loginTimeout;

  /// No description provided for @loginFailed.
  ///
  /// In nb, this message translates to:
  /// **'Kunne ikke logge inn. Prøv igjen.'**
  String get loginFailed;

  /// No description provided for @invalidEmail.
  ///
  /// In nb, this message translates to:
  /// **'Ugyldig e-postadresse.'**
  String get invalidEmail;

  /// No description provided for @invalidCredentials.
  ///
  /// In nb, this message translates to:
  /// **'Feil e-post eller passord.'**
  String get invalidCredentials;

  /// No description provided for @userDisabledMessage.
  ///
  /// In nb, this message translates to:
  /// **'Brukeren er deaktivert. Kontakt admin.'**
  String get userDisabledMessage;

  /// No description provided for @tooManyLoginAttempts.
  ///
  /// In nb, this message translates to:
  /// **'For mange forsøk. Vent litt og prøv igjen.'**
  String get tooManyLoginAttempts;

  /// No description provided for @loginNetworkFailed.
  ///
  /// In nb, this message translates to:
  /// **'Fikk ikke kontakt med innloggingstjenesten. Sjekk internett.'**
  String get loginNetworkFailed;

  /// No description provided for @emptyTank.
  ///
  /// In nb, this message translates to:
  /// **'Tomt kar'**
  String get emptyTank;

  /// No description provided for @notInUse.
  ///
  /// In nb, this message translates to:
  /// **'Ikke i bruk'**
  String get notInUse;

  /// No description provided for @sections.
  ///
  /// In nb, this message translates to:
  /// **'Seksjoner'**
  String get sections;

  /// No description provided for @tank.
  ///
  /// In nb, this message translates to:
  /// **'Kar'**
  String get tank;

  /// No description provided for @tanks.
  ///
  /// In nb, this message translates to:
  /// **'Kar'**
  String get tanks;

  /// No description provided for @newTank.
  ///
  /// In nb, this message translates to:
  /// **'Nytt kar'**
  String get newTank;

  /// No description provided for @tankName.
  ///
  /// In nb, this message translates to:
  /// **'Navn på kar'**
  String get tankName;

  /// No description provided for @numberOfFishLabel.
  ///
  /// In nb, this message translates to:
  /// **'Antall fisk'**
  String get numberOfFishLabel;

  /// No description provided for @createFirstTank.
  ///
  /// In nb, this message translates to:
  /// **'Opprett første kar'**
  String get createFirstTank;

  /// No description provided for @tankOverview.
  ///
  /// In nb, this message translates to:
  /// **'Karoversikt'**
  String get tankOverview;

  /// No description provided for @tankOverviewTitle.
  ///
  /// In nb, this message translates to:
  /// **'Karoversikt · {section}'**
  String tankOverviewTitle(String section);

  /// No description provided for @tankOverviewSubtitle.
  ///
  /// In nb, this message translates to:
  /// **'Oversikt og siste nøkkeltall for alle kar i seksjonen.'**
  String get tankOverviewSubtitle;

  /// No description provided for @refreshTankOverview.
  ///
  /// In nb, this message translates to:
  /// **'Oppdater karoversikt'**
  String get refreshTankOverview;

  /// No description provided for @loadingTanks.
  ///
  /// In nb, this message translates to:
  /// **'Laster kar...'**
  String get loadingTanks;

  /// No description provided for @noTanksInSection.
  ///
  /// In nb, this message translates to:
  /// **'Ingen kar i {section} ennå'**
  String noTanksInSection(String section);

  /// No description provided for @searchTanks.
  ///
  /// In nb, this message translates to:
  /// **'Søk etter kar...'**
  String get searchTanks;

  /// No description provided for @allTanks.
  ///
  /// In nb, this message translates to:
  /// **'Alle kar'**
  String get allTanks;

  /// No description provided for @observation.
  ///
  /// In nb, this message translates to:
  /// **'Observasjon'**
  String get observation;

  /// No description provided for @critical.
  ///
  /// In nb, this message translates to:
  /// **'Kritisk'**
  String get critical;

  /// No description provided for @criticalPlural.
  ///
  /// In nb, this message translates to:
  /// **'Kritiske'**
  String get criticalPlural;

  /// No description provided for @noMatchingTanks.
  ///
  /// In nb, this message translates to:
  /// **'Ingen kar passer med valgt søk eller filter.'**
  String get noMatchingTanks;

  /// No description provided for @noValue.
  ///
  /// In nb, this message translates to:
  /// **'Ingen'**
  String get noValue;

  /// No description provided for @noFeed.
  ///
  /// In nb, this message translates to:
  /// **'Ingen fôring'**
  String get noFeed;

  /// No description provided for @normalOperation.
  ///
  /// In nb, this message translates to:
  /// **'Normal drift'**
  String get normalOperation;

  /// No description provided for @missingAverageWeight.
  ///
  /// In nb, this message translates to:
  /// **'Mangler snittvekt'**
  String get missingAverageWeight;

  /// No description provided for @oldAverageWeight.
  ///
  /// In nb, this message translates to:
  /// **'Gammel snittvekt'**
  String get oldAverageWeight;

  /// No description provided for @highMortalityMessage.
  ///
  /// In nb, this message translates to:
  /// **'Høy dødelighet · {count} døde siste 7 dager'**
  String highMortalityMessage(int count);

  /// No description provided for @followUpMeasurements.
  ///
  /// In nb, this message translates to:
  /// **'{status} · følg opp nye målinger'**
  String followUpMeasurements(String status);

  /// No description provided for @emptyTankMessage.
  ///
  /// In nb, this message translates to:
  /// **'Ikke i bruk · kan åpnes og fylles senere'**
  String get emptyTankMessage;

  /// No description provided for @normalMortalityMessage.
  ///
  /// In nb, this message translates to:
  /// **'Normal drift · dødelighet 7d: {count}'**
  String normalMortalityMessage(int count);

  /// No description provided for @allValuesNormal.
  ///
  /// In nb, this message translates to:
  /// **'Alt innen normale verdier'**
  String get allValuesNormal;

  /// No description provided for @feed.
  ///
  /// In nb, this message translates to:
  /// **'Fôr'**
  String get feed;

  /// No description provided for @mortality.
  ///
  /// In nb, this message translates to:
  /// **'Dødelighet'**
  String get mortality;

  /// No description provided for @averageWeight.
  ///
  /// In nb, this message translates to:
  /// **'Snittvekt'**
  String get averageWeight;

  /// No description provided for @temperature.
  ///
  /// In nb, this message translates to:
  /// **'Temperatur'**
  String get temperature;

  /// No description provided for @history.
  ///
  /// In nb, this message translates to:
  /// **'Historikk'**
  String get history;

  /// No description provided for @tankInfo.
  ///
  /// In nb, this message translates to:
  /// **'Kar info'**
  String get tankInfo;

  /// No description provided for @weightSamples.
  ///
  /// In nb, this message translates to:
  /// **'Vektprøver'**
  String get weightSamples;

  /// No description provided for @growthForecast.
  ///
  /// In nb, this message translates to:
  /// **'Vekstprognose'**
  String get growthForecast;

  /// No description provided for @markReviewed.
  ///
  /// In nb, this message translates to:
  /// **'Gjennomgått'**
  String get markReviewed;

  /// No description provided for @reviewedThisSession.
  ///
  /// In nb, this message translates to:
  /// **'Gjennomgått i denne økten'**
  String get reviewedThisSession;

  /// No description provided for @feedLast24Hours.
  ///
  /// In nb, this message translates to:
  /// **'Fôr 24t'**
  String get feedLast24Hours;

  /// No description provided for @deathsLast7DaysShort.
  ///
  /// In nb, this message translates to:
  /// **'Døde 7d'**
  String get deathsLast7DaysShort;

  /// No description provided for @moreOptions.
  ///
  /// In nb, this message translates to:
  /// **'Flere valg'**
  String get moreOptions;

  /// No description provided for @deleteTank.
  ///
  /// In nb, this message translates to:
  /// **'Slett kar'**
  String get deleteTank;

  /// No description provided for @tankIllustration.
  ///
  /// In nb, this message translates to:
  /// **'Illustrasjon av oppdrettskar'**
  String get tankIllustration;

  /// No description provided for @tankNotesUnavailable.
  ///
  /// In nb, this message translates to:
  /// **'Driftsnotater er ikke tilgjengelige'**
  String get tankNotesUnavailable;

  /// No description provided for @saveAndNext.
  ///
  /// In nb, this message translates to:
  /// **'Lagre og neste'**
  String get saveAndNext;

  /// No description provided for @nextTank.
  ///
  /// In nb, this message translates to:
  /// **'Neste kar'**
  String get nextTank;

  /// No description provided for @roleAdmin.
  ///
  /// In nb, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @roleEmployee.
  ///
  /// In nb, this message translates to:
  /// **'Ansatt'**
  String get roleEmployee;

  /// No description provided for @roleReader.
  ///
  /// In nb, this message translates to:
  /// **'Leser'**
  String get roleReader;

  /// No description provided for @statusActive.
  ///
  /// In nb, this message translates to:
  /// **'Aktiv'**
  String get statusActive;

  /// No description provided for @statusDisabled.
  ///
  /// In nb, this message translates to:
  /// **'Deaktivert'**
  String get statusDisabled;

  /// No description provided for @dashboardUpdated.
  ///
  /// In nb, this message translates to:
  /// **'Dashboard oppdatert'**
  String get dashboardUpdated;

  /// No description provided for @excelExportComplete.
  ///
  /// In nb, this message translates to:
  /// **'Excel eksport fullført'**
  String get excelExportComplete;

  /// No description provided for @excelExportFailed.
  ///
  /// In nb, this message translates to:
  /// **'Kunne ikke eksportere Excel. Prøv igjen.'**
  String get excelExportFailed;

  /// No description provided for @contentUnavailable.
  ///
  /// In nb, this message translates to:
  /// **'Det tilhørende innholdet er ikke tilgjengelig nå.'**
  String get contentUnavailable;

  /// No description provided for @loading.
  ///
  /// In nb, this message translates to:
  /// **'Laster...'**
  String get loading;

  /// No description provided for @period.
  ///
  /// In nb, this message translates to:
  /// **'Periode'**
  String get period;

  /// No description provided for @today.
  ///
  /// In nb, this message translates to:
  /// **'I dag'**
  String get today;

  /// No description provided for @last7Days.
  ///
  /// In nb, this message translates to:
  /// **'Siste 7 dager'**
  String get last7Days;

  /// No description provided for @last30Days.
  ///
  /// In nb, this message translates to:
  /// **'Siste 30 dager'**
  String get last30Days;

  /// No description provided for @currentMonth.
  ///
  /// In nb, this message translates to:
  /// **'Denne måneden'**
  String get currentMonth;

  /// No description provided for @customPeriod.
  ///
  /// In nb, this message translates to:
  /// **'Egendefinert periode'**
  String get customPeriod;

  /// No description provided for @fromDate.
  ///
  /// In nb, this message translates to:
  /// **'Fra {date}'**
  String fromDate(String date);

  /// No description provided for @toDate.
  ///
  /// In nb, this message translates to:
  /// **'Til {date}'**
  String toDate(String date);

  /// No description provided for @reportFor.
  ///
  /// In nb, this message translates to:
  /// **'Rapport for'**
  String get reportFor;

  /// No description provided for @entireFacility.
  ///
  /// In nb, this message translates to:
  /// **'Hele anlegget'**
  String get entireFacility;

  /// No description provided for @buildingOrSection.
  ///
  /// In nb, this message translates to:
  /// **'Bygg/seksjon'**
  String get buildingOrSection;

  /// No description provided for @singleTank.
  ///
  /// In nb, this message translates to:
  /// **'Enkelt kar'**
  String get singleTank;

  /// No description provided for @selectBuildingOrTank.
  ///
  /// In nb, this message translates to:
  /// **'Velg bygg eller kar'**
  String get selectBuildingOrTank;

  /// No description provided for @reportSelectionHint.
  ///
  /// In nb, this message translates to:
  /// **'Rapporten vises når valget er komplett.'**
  String get reportSelectionHint;

  /// No description provided for @reportCreationFailed.
  ///
  /// In nb, this message translates to:
  /// **'Kunne ikke lage rapport'**
  String get reportCreationFailed;

  /// No description provided for @reportCreationHint.
  ///
  /// In nb, this message translates to:
  /// **'Prøv igjen. Kontroller nettverk og tilgang.'**
  String get reportCreationHint;

  /// No description provided for @reportExportFailed.
  ///
  /// In nb, this message translates to:
  /// **'Kunne ikke eksportere rapporten. Prøv igjen.'**
  String get reportExportFailed;

  /// No description provided for @exportToExcel.
  ///
  /// In nb, this message translates to:
  /// **'Eksporter til Excel'**
  String get exportToExcel;

  /// No description provided for @noRecordsSelectedPeriod.
  ///
  /// In nb, this message translates to:
  /// **'Ingen registreringer i valgt periode'**
  String get noRecordsSelectedPeriod;

  /// No description provided for @reportDataAvailability.
  ///
  /// In nb, this message translates to:
  /// **'Karstatus og siste biomasse vises der datagrunnlag finnes.'**
  String get reportDataAvailability;

  /// No description provided for @feedUsed.
  ///
  /// In nb, this message translates to:
  /// **'Fôr brukt'**
  String get feedUsed;

  /// No description provided for @latestAverageWeight.
  ///
  /// In nb, this message translates to:
  /// **'Siste snittvekt'**
  String get latestAverageWeight;

  /// No description provided for @weightChange.
  ///
  /// In nb, this message translates to:
  /// **'Vektendring'**
  String get weightChange;

  /// No description provided for @fcrUnavailable.
  ///
  /// In nb, this message translates to:
  /// **'FCR kan ikke beregnes'**
  String get fcrUnavailable;

  /// No description provided for @registrations.
  ///
  /// In nb, this message translates to:
  /// **'Registreringer'**
  String get registrations;

  /// No description provided for @noTanksForFilter.
  ///
  /// In nb, this message translates to:
  /// **'Ingen kar funnet for valgt filter'**
  String get noTanksForFilter;

  /// No description provided for @section.
  ///
  /// In nb, this message translates to:
  /// **'Seksjon'**
  String get section;

  /// No description provided for @dead.
  ///
  /// In nb, this message translates to:
  /// **'Død'**
  String get dead;

  /// No description provided for @temperatureShort.
  ///
  /// In nb, this message translates to:
  /// **'Temp'**
  String get temperatureShort;

  /// No description provided for @historyForTank.
  ///
  /// In nb, this message translates to:
  /// **'Historikk - {tank}'**
  String historyForTank(String tank);

  /// No description provided for @noRecordsFound.
  ///
  /// In nb, this message translates to:
  /// **'Ingen registreringer funnet'**
  String get noRecordsFound;

  /// No description provided for @changeFilterOrPeriod.
  ///
  /// In nb, this message translates to:
  /// **'Prøv å endre filter eller periode.'**
  String get changeFilterOrPeriod;

  /// No description provided for @registrationType.
  ///
  /// In nb, this message translates to:
  /// **'Type registrering'**
  String get registrationType;

  /// No description provided for @all.
  ///
  /// In nb, this message translates to:
  /// **'Alle'**
  String get all;

  /// No description provided for @notes.
  ///
  /// In nb, this message translates to:
  /// **'Notater'**
  String get notes;

  /// No description provided for @resetFilter.
  ///
  /// In nb, this message translates to:
  /// **'Nullstill filter'**
  String get resetFilter;

  /// No description provided for @unknownDate.
  ///
  /// In nb, this message translates to:
  /// **'Ukjent dato'**
  String get unknownDate;

  /// No description provided for @mortalityAndFeed.
  ///
  /// In nb, this message translates to:
  /// **'Død: {mortality}  •  Fôr: {feed} kg'**
  String mortalityAndFeed(String mortality, String feed);

  /// No description provided for @feedTypeLine.
  ///
  /// In nb, this message translates to:
  /// **'Fôrtype: {type}'**
  String feedTypeLine(String type);

  /// No description provided for @pelletLine.
  ///
  /// In nb, this message translates to:
  /// **'Pellet: {size} mm'**
  String pelletLine(String size);

  /// No description provided for @noteLine.
  ///
  /// In nb, this message translates to:
  /// **'Notat: {note}'**
  String noteLine(String note);

  /// No description provided for @tankInfoTitle.
  ///
  /// In nb, this message translates to:
  /// **'Kar info - {tank}'**
  String tankInfoTitle(String tank);

  /// No description provided for @couldNotFetchData.
  ///
  /// In nb, this message translates to:
  /// **'Kunne ikke hente data. Gå tilbake og prøv igjen.'**
  String get couldNotFetchData;

  /// No description provided for @calculating.
  ///
  /// In nb, this message translates to:
  /// **'Beregner...'**
  String get calculating;

  /// No description provided for @weightSampleForTank.
  ///
  /// In nb, this message translates to:
  /// **'Vektprøve - {tank}'**
  String weightSampleForTank(String tank);

  /// No description provided for @readerAccess.
  ///
  /// In nb, this message translates to:
  /// **'Lesetilgang'**
  String get readerAccess;

  /// No description provided for @readOnlyRole.
  ///
  /// In nb, this message translates to:
  /// **'Du er logget inn som {role} og kan kun se.'**
  String readOnlyRole(String role);

  /// No description provided for @emptyTankDescription.
  ///
  /// In nb, this message translates to:
  /// **'Karet er tomt. Fyll inn fisk først for å registrere vektprøver.'**
  String get emptyTankDescription;

  /// No description provided for @simpleAverageWeight.
  ///
  /// In nb, this message translates to:
  /// **'Vanlig snittvekt'**
  String get simpleAverageWeight;

  /// No description provided for @individualWeights.
  ///
  /// In nb, this message translates to:
  /// **'Enkeltvekter'**
  String get individualWeights;

  /// No description provided for @averageWeightGram.
  ///
  /// In nb, this message translates to:
  /// **'Snittvekt (g)'**
  String get averageWeightGram;

  /// No description provided for @averageWeightInputHelp.
  ///
  /// In nb, this message translates to:
  /// **'Støtter 250, 250.5 og 250,5'**
  String get averageWeightInputHelp;

  /// No description provided for @saveAverageWeight.
  ///
  /// In nb, this message translates to:
  /// **'Lagre snittvekt'**
  String get saveAverageWeight;

  /// No description provided for @weightInGrams.
  ///
  /// In nb, this message translates to:
  /// **'Vekt i gram'**
  String get weightInGrams;

  /// No description provided for @weightSampleInputHelp.
  ///
  /// In nb, this message translates to:
  /// **'Skriv én vekt eller lim inn flere vekter med mellomrom, komma eller linjeskift.'**
  String get weightSampleInputHelp;

  /// No description provided for @add.
  ///
  /// In nb, this message translates to:
  /// **'Legg til'**
  String get add;

  /// No description provided for @clearList.
  ///
  /// In nb, this message translates to:
  /// **'Tøm liste'**
  String get clearList;

  /// No description provided for @comment.
  ///
  /// In nb, this message translates to:
  /// **'Kommentar'**
  String get comment;

  /// No description provided for @optional.
  ///
  /// In nb, this message translates to:
  /// **'Valgfritt'**
  String get optional;

  /// No description provided for @saveWeightSample.
  ///
  /// In nb, this message translates to:
  /// **'Lagre vektprøve'**
  String get saveWeightSample;

  /// No description provided for @weightSamplesUnavailable.
  ///
  /// In nb, this message translates to:
  /// **'Vektprøver er ikke tilgjengelige nå.'**
  String get weightSamplesUnavailable;

  /// No description provided for @noWeightSamples.
  ///
  /// In nb, this message translates to:
  /// **'Ingen vektprøver er registrert ennå.'**
  String get noWeightSamples;

  /// No description provided for @latestWeightSample.
  ///
  /// In nb, this message translates to:
  /// **'Siste vektprøve'**
  String get latestWeightSample;

  /// No description provided for @distribution.
  ///
  /// In nb, this message translates to:
  /// **'Fordeling'**
  String get distribution;

  /// No description provided for @noDistribution.
  ///
  /// In nb, this message translates to:
  /// **'Ingen fordeling tilgjengelig.'**
  String get noDistribution;

  /// No description provided for @commentLine.
  ///
  /// In nb, this message translates to:
  /// **'Kommentar: {comment}'**
  String commentLine(String comment);

  /// No description provided for @weightGrowthTitle.
  ///
  /// In nb, this message translates to:
  /// **'Vekst – {tank}'**
  String weightGrowthTitle(String tank);

  /// No description provided for @noWeightRecords.
  ///
  /// In nb, this message translates to:
  /// **'Ingen vektregistreringer ennå'**
  String get noWeightRecords;

  /// No description provided for @mortalityTitle.
  ///
  /// In nb, this message translates to:
  /// **'Dødelighet – {tank}'**
  String mortalityTitle(String tank);

  /// No description provided for @noMortalityRecords.
  ///
  /// In nb, this message translates to:
  /// **'Ingen dødelighetsdata ennå'**
  String get noMortalityRecords;

  /// No description provided for @totalMortality.
  ///
  /// In nb, this message translates to:
  /// **'Total dødelighet'**
  String get totalMortality;

  /// No description provided for @numberOfRegistrations.
  ///
  /// In nb, this message translates to:
  /// **'Antall registreringer'**
  String get numberOfRegistrations;

  /// No description provided for @moveFish.
  ///
  /// In nb, this message translates to:
  /// **'Flytt fisk'**
  String get moveFish;

  /// No description provided for @moveFishValidation.
  ///
  /// In nb, this message translates to:
  /// **'Velg mottakerkar og et antall større enn null.'**
  String get moveFishValidation;

  /// No description provided for @couldNotLoadTanks.
  ///
  /// In nb, this message translates to:
  /// **'Kunne ikke hente kar. Prøv igjen.'**
  String get couldNotLoadTanks;

  /// No description provided for @noOtherTanks.
  ///
  /// In nb, this message translates to:
  /// **'Ingen andre kar å flytte til'**
  String get noOtherTanks;

  /// No description provided for @fromTank.
  ///
  /// In nb, this message translates to:
  /// **'Fra kar'**
  String get fromTank;

  /// No description provided for @moveToTank.
  ///
  /// In nb, this message translates to:
  /// **'Flytt til kar'**
  String get moveToTank;

  /// No description provided for @fishToMove.
  ///
  /// In nb, this message translates to:
  /// **'Antall fisk som skal flyttes'**
  String get fishToMove;

  /// No description provided for @fishCountExample.
  ///
  /// In nb, this message translates to:
  /// **'F.eks. 2000'**
  String get fishCountExample;

  /// No description provided for @enterWeightFirst.
  ///
  /// In nb, this message translates to:
  /// **'Skriv inn en vekt først.'**
  String get enterWeightFirst;

  /// No description provided for @invalidValuesNotAdded.
  ///
  /// In nb, this message translates to:
  /// **'Noen verdier ble ikke lagt til: {values}'**
  String invalidValuesNotAdded(String values);

  /// No description provided for @invalidAverageWeight.
  ///
  /// In nb, this message translates to:
  /// **'Ugyldig snittvekt'**
  String get invalidAverageWeight;

  /// No description provided for @averageWeightSaved.
  ///
  /// In nb, this message translates to:
  /// **'Snittvekt lagret'**
  String get averageWeightSaved;

  /// No description provided for @addWeightBeforeSaving.
  ///
  /// In nb, this message translates to:
  /// **'Legg til minst én vekt før lagring.'**
  String get addWeightBeforeSaving;

  /// No description provided for @weightSampleSaved.
  ///
  /// In nb, this message translates to:
  /// **'Vektprøve lagret'**
  String get weightSampleSaved;

  /// No description provided for @emptyTankBeforeWeight.
  ///
  /// In nb, this message translates to:
  /// **'Karet er tomt. Legg inn fisketall før vekt registreres.'**
  String get emptyTankBeforeWeight;

  /// No description provided for @noWriteAccess.
  ///
  /// In nb, this message translates to:
  /// **'Ingen skrivetilgang'**
  String get noWriteAccess;

  /// No description provided for @couldNotSaveWeight.
  ///
  /// In nb, this message translates to:
  /// **'Kunne ikke lagre vekten. Verdiene er beholdt. Prøv igjen.'**
  String get couldNotSaveWeight;

  /// No description provided for @registerWeight.
  ///
  /// In nb, this message translates to:
  /// **'Registrer vekt'**
  String get registerWeight;

  /// No description provided for @count.
  ///
  /// In nb, this message translates to:
  /// **'Antall'**
  String get count;

  /// No description provided for @average.
  ///
  /// In nb, this message translates to:
  /// **'Snitt'**
  String get average;

  /// No description provided for @median.
  ///
  /// In nb, this message translates to:
  /// **'Median'**
  String get median;

  /// No description provided for @minimum.
  ///
  /// In nb, this message translates to:
  /// **'Min'**
  String get minimum;

  /// No description provided for @maximum.
  ///
  /// In nb, this message translates to:
  /// **'Maks'**
  String get maximum;

  /// No description provided for @standardDeviation.
  ///
  /// In nb, this message translates to:
  /// **'Std.avvik'**
  String get standardDeviation;

  /// No description provided for @unknownTime.
  ///
  /// In nb, this message translates to:
  /// **'Ukjent tidspunkt'**
  String get unknownTime;

  /// No description provided for @averageWeightOverTime.
  ///
  /// In nb, this message translates to:
  /// **'Snittvekt over tid'**
  String get averageWeightOverTime;

  /// No description provided for @mortalityPerRegistration.
  ///
  /// In nb, this message translates to:
  /// **'Dødelighet per registrering'**
  String get mortalityPerRegistration;

  /// No description provided for @manageUsersSubtitle.
  ///
  /// In nb, this message translates to:
  /// **'Administrer interne brukere, roller og invitasjoner.'**
  String get manageUsersSubtitle;

  /// No description provided for @inviteUser.
  ///
  /// In nb, this message translates to:
  /// **'Inviter bruker'**
  String get inviteUser;

  /// No description provided for @couldNotUpdateUser.
  ///
  /// In nb, this message translates to:
  /// **'Kunne ikke oppdatere brukeren'**
  String get couldNotUpdateUser;

  /// No description provided for @usersUnavailable.
  ///
  /// In nb, this message translates to:
  /// **'Kunne ikke hente brukerne akkurat nå.'**
  String get usersUnavailable;

  /// No description provided for @searchUsers.
  ///
  /// In nb, this message translates to:
  /// **'Søk etter bruker...'**
  String get searchUsers;

  /// No description provided for @noUsersFound.
  ///
  /// In nb, this message translates to:
  /// **'Ingen brukere funnet'**
  String get noUsersFound;

  /// No description provided for @roleUpdated.
  ///
  /// In nb, this message translates to:
  /// **'Rolle oppdatert'**
  String get roleUpdated;

  /// No description provided for @userDisabled.
  ///
  /// In nb, this message translates to:
  /// **'Bruker deaktivert'**
  String get userDisabled;

  /// No description provided for @userEnabled.
  ///
  /// In nb, this message translates to:
  /// **'Bruker aktivert'**
  String get userEnabled;

  /// No description provided for @unknownEmail.
  ///
  /// In nb, this message translates to:
  /// **'Ukjent e-post'**
  String get unknownEmail;

  /// No description provided for @activateUser.
  ///
  /// In nb, this message translates to:
  /// **'Aktiver bruker'**
  String get activateUser;

  /// No description provided for @deactivateUser.
  ///
  /// In nb, this message translates to:
  /// **'Deaktiver bruker'**
  String get deactivateUser;

  /// No description provided for @actions.
  ///
  /// In nb, this message translates to:
  /// **'Handlinger'**
  String get actions;

  /// No description provided for @invitationLinkCopied.
  ///
  /// In nb, this message translates to:
  /// **'Invitasjonslenke kopiert'**
  String get invitationLinkCopied;

  /// No description provided for @revokeInvitationQuestion.
  ///
  /// In nb, this message translates to:
  /// **'Trekke tilbake invitasjonen?'**
  String get revokeInvitationQuestion;

  /// No description provided for @revokeInvitation.
  ///
  /// In nb, this message translates to:
  /// **'Trekk tilbake'**
  String get revokeInvitation;

  /// No description provided for @invitationRevoked.
  ///
  /// In nb, this message translates to:
  /// **'Invitasjonen er trukket tilbake'**
  String get invitationRevoked;

  /// No description provided for @couldNotRevokeInvitation.
  ///
  /// In nb, this message translates to:
  /// **'Kunne ikke trekke invitasjonen'**
  String get couldNotRevokeInvitation;

  /// No description provided for @invitationsUnavailable.
  ///
  /// In nb, this message translates to:
  /// **'Invitasjoner er ikke tilgjengelige ennå.'**
  String get invitationsUnavailable;

  /// No description provided for @invitations.
  ///
  /// In nb, this message translates to:
  /// **'Invitasjoner'**
  String get invitations;

  /// No description provided for @noInvitations.
  ///
  /// In nb, this message translates to:
  /// **'Ingen invitasjoner er opprettet'**
  String get noInvitations;

  /// No description provided for @invitationActions.
  ///
  /// In nb, this message translates to:
  /// **'Invitasjonshandlinger'**
  String get invitationActions;

  /// No description provided for @copyInvitationLink.
  ///
  /// In nb, this message translates to:
  /// **'Kopier invitasjonslenke'**
  String get copyInvitationLink;

  /// No description provided for @invitePanelTitle.
  ///
  /// In nb, this message translates to:
  /// **'Inviter bruker'**
  String get invitePanelTitle;

  /// No description provided for @nameOptional.
  ///
  /// In nb, this message translates to:
  /// **'Navn (valgfritt)'**
  String get nameOptional;

  /// No description provided for @fullNameHint.
  ///
  /// In nb, this message translates to:
  /// **'Skriv inn fullt navn'**
  String get fullNameHint;

  /// No description provided for @emailHint.
  ///
  /// In nb, this message translates to:
  /// **'navn@epost.no'**
  String get emailHint;

  /// No description provided for @role.
  ///
  /// In nb, this message translates to:
  /// **'Rolle'**
  String get role;

  /// No description provided for @invitationRoleInfo.
  ///
  /// In nb, this message translates to:
  /// **'Rollen låses til invitasjonen. Lenken er gyldig i 7 dager.'**
  String get invitationRoleInfo;

  /// No description provided for @createInvitation.
  ///
  /// In nb, this message translates to:
  /// **'Opprett invitasjon'**
  String get createInvitation;

  /// No description provided for @invitationCreated.
  ///
  /// In nb, this message translates to:
  /// **'Invitasjon opprettet'**
  String get invitationCreated;

  /// No description provided for @couldNotCreateInvitation.
  ///
  /// In nb, this message translates to:
  /// **'Kunne ikke opprette invitasjonen'**
  String get couldNotCreateInvitation;

  /// No description provided for @invitationReady.
  ///
  /// In nb, this message translates to:
  /// **'Invitasjonen er klar til å sendes.'**
  String get invitationReady;

  /// No description provided for @copyInvitationText.
  ///
  /// In nb, this message translates to:
  /// **'Kopier invitasjonstekst'**
  String get copyInvitationText;

  /// No description provided for @accessDeniedUserAdmin.
  ///
  /// In nb, this message translates to:
  /// **'Du har ikke tilgang til å administrere brukere'**
  String get accessDeniedUserAdmin;

  /// No description provided for @notRegistered.
  ///
  /// In nb, this message translates to:
  /// **'Ikke registrert'**
  String get notRegistered;

  /// No description provided for @expiresOn.
  ///
  /// In nb, this message translates to:
  /// **'utløper {date}'**
  String expiresOn(String date);

  /// No description provided for @adjustBagsForFeed.
  ///
  /// In nb, this message translates to:
  /// **'Juster {feed}'**
  String adjustBagsForFeed(String feed);

  /// No description provided for @bagsToAdjust.
  ///
  /// In nb, this message translates to:
  /// **'Antall sekker (+ / -)'**
  String get bagsToAdjust;

  /// No description provided for @bagsAdjustHint.
  ///
  /// In nb, this message translates to:
  /// **'F.eks. 10 eller -3'**
  String get bagsAdjustHint;

  /// No description provided for @kgPerBagForFeed.
  ///
  /// In nb, this message translates to:
  /// **'Kg per sekk - {feed}'**
  String kgPerBagForFeed(String feed);

  /// No description provided for @kgPerBag.
  ///
  /// In nb, this message translates to:
  /// **'Kg per sekk'**
  String get kgPerBag;

  /// No description provided for @feedType.
  ///
  /// In nb, this message translates to:
  /// **'Fôrtype'**
  String get feedType;

  /// No description provided for @newFeedType.
  ///
  /// In nb, this message translates to:
  /// **'Ny fôrtype'**
  String get newFeedType;

  /// No description provided for @editFeedType.
  ///
  /// In nb, this message translates to:
  /// **'Endre fôrtype'**
  String get editFeedType;

  /// No description provided for @feedName.
  ///
  /// In nb, this message translates to:
  /// **'Navn'**
  String get feedName;

  /// No description provided for @pelletSize.
  ///
  /// In nb, this message translates to:
  /// **'Pelletstørrelse mm'**
  String get pelletSize;

  /// No description provided for @feedNameAndPelletRequired.
  ///
  /// In nb, this message translates to:
  /// **'Navn og pelletstørrelse må fylles ut.'**
  String get feedNameAndPelletRequired;

  /// No description provided for @cannotDeactivateFeedWithStock.
  ///
  /// In nb, this message translates to:
  /// **'Fôrtype med sekker på lager kan ikke deaktiveres.'**
  String get cannotDeactivateFeedWithStock;

  /// No description provided for @activeFeedInventory.
  ///
  /// In nb, this message translates to:
  /// **'Aktivt fôrlager'**
  String get activeFeedInventory;

  /// No description provided for @readOnlyInventoryRole.
  ///
  /// In nb, this message translates to:
  /// **'Du er logget inn som {role} og kan kun se lager.'**
  String readOnlyInventoryRole(String role);

  /// No description provided for @inactiveFeedType.
  ///
  /// In nb, this message translates to:
  /// **'Inaktiv fôrtype'**
  String get inactiveFeedType;

  /// No description provided for @bags.
  ///
  /// In nb, this message translates to:
  /// **'{count} sekker'**
  String bags(int count);

  /// No description provided for @adjustBags.
  ///
  /// In nb, this message translates to:
  /// **'Juster sekker'**
  String get adjustBags;

  /// No description provided for @editKgPerBag.
  ///
  /// In nb, this message translates to:
  /// **'Endre kg per sekk'**
  String get editKgPerBag;

  /// No description provided for @inventoryHistory.
  ///
  /// In nb, this message translates to:
  /// **'Lagerhistorikk'**
  String get inventoryHistory;

  /// No description provided for @noInventoryHistory.
  ///
  /// In nb, this message translates to:
  /// **'Ingen lagerhistorikk ennå'**
  String get noInventoryHistory;

  /// No description provided for @unknownFeed.
  ///
  /// In nb, this message translates to:
  /// **'Ukjent fôr'**
  String get unknownFeed;

  /// No description provided for @tankCount.
  ///
  /// In nb, this message translates to:
  /// **'Nåværende antall fisk'**
  String get tankCount;

  /// No description provided for @adjustFishCount.
  ///
  /// In nb, this message translates to:
  /// **'Juster fisketall'**
  String get adjustFishCount;

  /// No description provided for @newFishCount.
  ///
  /// In nb, this message translates to:
  /// **'Nytt antall fisk'**
  String get newFishCount;

  /// No description provided for @unsavedChanges.
  ///
  /// In nb, this message translates to:
  /// **'Ulagrede endringer'**
  String get unsavedChanges;

  /// No description provided for @leaveWithoutSaving.
  ///
  /// In nb, this message translates to:
  /// **'Gå til neste kar uten å lagre de nye verdiene?'**
  String get leaveWithoutSaving;

  /// No description provided for @newOperationalNote.
  ///
  /// In nb, this message translates to:
  /// **'Nytt driftsnotat'**
  String get newOperationalNote;

  /// No description provided for @editOperationalNote.
  ///
  /// In nb, this message translates to:
  /// **'Rediger driftsnotat'**
  String get editOperationalNote;

  /// No description provided for @noteHint.
  ///
  /// In nb, this message translates to:
  /// **'F.eks. For mye spillfôr'**
  String get noteHint;

  /// No description provided for @operationalNoteSaved.
  ///
  /// In nb, this message translates to:
  /// **'Driftsnotat lagret'**
  String get operationalNoteSaved;

  /// No description provided for @operationalNoteSaveFailed.
  ///
  /// In nb, this message translates to:
  /// **'Kunne ikke lagre driftsnotatet. Prøv igjen.'**
  String get operationalNoteSaveFailed;

  /// No description provided for @operationalNoteCompleted.
  ///
  /// In nb, this message translates to:
  /// **'Driftsnotat markert som ferdig'**
  String get operationalNoteCompleted;

  /// No description provided for @newNote.
  ///
  /// In nb, this message translates to:
  /// **'Nytt notat'**
  String get newNote;

  /// No description provided for @edit.
  ///
  /// In nb, this message translates to:
  /// **'Rediger'**
  String get edit;

  /// No description provided for @markCompleted.
  ///
  /// In nb, this message translates to:
  /// **'Marker som ferdig'**
  String get markCompleted;

  /// No description provided for @createOperationalNote.
  ///
  /// In nb, this message translates to:
  /// **'Opprett driftsnotat'**
  String get createOperationalNote;

  /// No description provided for @completedNotes.
  ///
  /// In nb, this message translates to:
  /// **'Ferdige notater ({count})'**
  String completedNotes(int count);

  /// No description provided for @otherFeedType.
  ///
  /// In nb, this message translates to:
  /// **'Annen fôrtype fra lager'**
  String get otherFeedType;

  /// No description provided for @otherFeedTypeHint.
  ///
  /// In nb, this message translates to:
  /// **'Velg dette når en annen type enn den anbefalte er gitt.'**
  String get otherFeedTypeHint;

  /// No description provided for @selectFeedType.
  ///
  /// In nb, this message translates to:
  /// **'Velg fôrtype'**
  String get selectFeedType;

  /// No description provided for @useRecommendedFeedType.
  ///
  /// In nb, this message translates to:
  /// **'Bruk anbefalt fôrtype'**
  String get useRecommendedFeedType;

  /// No description provided for @dailyFeedRation.
  ///
  /// In nb, this message translates to:
  /// **'Anbefalt daglig fôrrasjon'**
  String get dailyFeedRation;

  /// No description provided for @mortalityInput.
  ///
  /// In nb, this message translates to:
  /// **'Dødelighet'**
  String get mortalityInput;

  /// No description provided for @feedKgInput.
  ///
  /// In nb, this message translates to:
  /// **'Fôr (kg)'**
  String get feedKgInput;

  /// No description provided for @averageWeightOptional.
  ///
  /// In nb, this message translates to:
  /// **'Snittvekt (g) – valgfritt'**
  String get averageWeightOptional;

  /// No description provided for @temperatureInput.
  ///
  /// In nb, this message translates to:
  /// **'Temperatur'**
  String get temperatureInput;

  /// No description provided for @day.
  ///
  /// In nb, this message translates to:
  /// **'Dag'**
  String get day;

  /// No description provided for @month.
  ///
  /// In nb, this message translates to:
  /// **'Måned'**
  String get month;

  /// No description provided for @year.
  ///
  /// In nb, this message translates to:
  /// **'År'**
  String get year;

  /// No description provided for @goToToday.
  ///
  /// In nb, this message translates to:
  /// **'Gå til i dag'**
  String get goToToday;

  /// No description provided for @searchEntries.
  ///
  /// In nb, this message translates to:
  /// **'Søk i innlegg'**
  String get searchEntries;

  /// No description provided for @category.
  ///
  /// In nb, this message translates to:
  /// **'Kategori'**
  String get category;

  /// No description provided for @allCategories.
  ///
  /// In nb, this message translates to:
  /// **'Alle kategorier'**
  String get allCategories;

  /// No description provided for @printMonth.
  ///
  /// In nb, this message translates to:
  /// **'Skriv ut måned'**
  String get printMonth;

  /// No description provided for @printYear.
  ///
  /// In nb, this message translates to:
  /// **'Skriv ut år'**
  String get printYear;

  /// No description provided for @noDiaryEntries.
  ///
  /// In nb, this message translates to:
  /// **'Ingen dagbokinnlegg i valgt periode'**
  String get noDiaryEntries;

  /// No description provided for @diaryUnavailablePermission.
  ///
  /// In nb, this message translates to:
  /// **'Driftsloggen er ikke tilgjengelig før tilgangsreglene er oppdatert.'**
  String get diaryUnavailablePermission;

  /// No description provided for @diaryLoadFailed.
  ///
  /// In nb, this message translates to:
  /// **'Driftsloggen kunne ikke lastes akkurat nå. Resten av dashboardet fungerer som normalt.'**
  String get diaryLoadFailed;

  /// No description provided for @diaryLoadingLong.
  ///
  /// In nb, this message translates to:
  /// **'Driftsloggen bruker lang tid på å svare. Resten av dashboardet fungerer som normalt.'**
  String get diaryLoadingLong;

  /// No description provided for @diaryEntrySaved.
  ///
  /// In nb, this message translates to:
  /// **'Dagbokinnlegg lagret'**
  String get diaryEntrySaved;

  /// No description provided for @diaryEntryUpdated.
  ///
  /// In nb, this message translates to:
  /// **'Dagbokinnlegg oppdatert'**
  String get diaryEntryUpdated;

  /// No description provided for @diaryEntryArchived.
  ///
  /// In nb, this message translates to:
  /// **'Dagbokinnlegg arkivert'**
  String get diaryEntryArchived;

  /// No description provided for @couldNotSaveDiaryEntry.
  ///
  /// In nb, this message translates to:
  /// **'Kunne ikke lagre dagbokinnlegg'**
  String get couldNotSaveDiaryEntry;

  /// No description provided for @couldNotUpdateDiaryEntry.
  ///
  /// In nb, this message translates to:
  /// **'Kunne ikke oppdatere dagbokinnlegg'**
  String get couldNotUpdateDiaryEntry;

  /// No description provided for @couldNotArchiveDiaryEntry.
  ///
  /// In nb, this message translates to:
  /// **'Kunne ikke arkivere dagbokinnlegg'**
  String get couldNotArchiveDiaryEntry;

  /// No description provided for @couldNotOpenPrint.
  ///
  /// In nb, this message translates to:
  /// **'Kunne ikke åpne utskrift'**
  String get couldNotOpenPrint;

  /// No description provided for @archiveEntryQuestion.
  ///
  /// In nb, this message translates to:
  /// **'Arkiver innlegg?'**
  String get archiveEntryQuestion;

  /// No description provided for @archiveEntryBody.
  ///
  /// In nb, this message translates to:
  /// **'«{title}» fjernes fra den aktive dagboken.'**
  String archiveEntryBody(String title);

  /// No description provided for @archive.
  ///
  /// In nb, this message translates to:
  /// **'Arkiver'**
  String get archive;

  /// No description provided for @editEntry.
  ///
  /// In nb, this message translates to:
  /// **'Rediger innlegg'**
  String get editEntry;

  /// No description provided for @entryTitle.
  ///
  /// In nb, this message translates to:
  /// **'Tittel'**
  String get entryTitle;

  /// No description provided for @entryContent.
  ///
  /// In nb, this message translates to:
  /// **'Tekst / innhold'**
  String get entryContent;

  /// No description provided for @entryActions.
  ///
  /// In nb, this message translates to:
  /// **'Handlinger for innlegg'**
  String get entryActions;

  /// No description provided for @printEntry.
  ///
  /// In nb, this message translates to:
  /// **'Skriv ut innlegg'**
  String get printEntry;

  /// No description provided for @diaryEntriesInView.
  ///
  /// In nb, this message translates to:
  /// **'{count} innlegg i visningen'**
  String diaryEntriesInView(int count);

  /// No description provided for @moreDiaryEntries.
  ///
  /// In nb, this message translates to:
  /// **'{count} flere innlegg finnes i full dagbok.'**
  String moreDiaryEntries(int count);

  /// No description provided for @couldNotUpdateFeedInventory.
  ///
  /// In nb, this message translates to:
  /// **'Kunne ikke oppdatere fôrlageret. Prøv igjen.'**
  String get couldNotUpdateFeedInventory;

  /// No description provided for @editKgHint.
  ///
  /// In nb, this message translates to:
  /// **'Bruk blyanten på kortet for å endre kg per sekk.'**
  String get editKgHint;

  /// No description provided for @pelletNotSet.
  ///
  /// In nb, this message translates to:
  /// **'Pellet ikke satt'**
  String get pelletNotSet;

  /// No description provided for @afterBags.
  ///
  /// In nb, this message translates to:
  /// **'Etter: {count} sekker'**
  String afterBags(String count);

  /// No description provided for @dateTimeSavedAutomatically.
  ///
  /// In nb, this message translates to:
  /// **'Dato og klokkeslett lagres automatisk.'**
  String get dateTimeSavedAutomatically;

  /// No description provided for @originalDatePreserved.
  ///
  /// In nb, this message translates to:
  /// **'Opprinnelig dato beholdes. Endringstid lagres automatisk.'**
  String get originalDatePreserved;

  /// No description provided for @saving.
  ///
  /// In nb, this message translates to:
  /// **'Lagrer…'**
  String get saving;

  /// No description provided for @openingNext.
  ///
  /// In nb, this message translates to:
  /// **'Åpner neste…'**
  String get openingNext;

  /// No description provided for @growthChart.
  ///
  /// In nb, this message translates to:
  /// **'Vekstdiagram'**
  String get growthChart;

  /// No description provided for @mortalityChart.
  ///
  /// In nb, this message translates to:
  /// **'Dødelighetsdiagram'**
  String get mortalityChart;

  /// No description provided for @noActiveOperationalNote.
  ///
  /// In nb, this message translates to:
  /// **'Ingen aktivt driftsnotat.'**
  String get noActiveOperationalNote;

  /// No description provided for @writtenBy.
  ///
  /// In nb, this message translates to:
  /// **'Skrevet av: {email}'**
  String writtenBy(String email);

  /// No description provided for @completedAt.
  ///
  /// In nb, this message translates to:
  /// **'Ferdig: {date}'**
  String completedAt(String date);

  /// No description provided for @averageWeightMissingForBiomass.
  ///
  /// In nb, this message translates to:
  /// **'Registrer snittvekt for å beregne biomasse'**
  String get averageWeightMissingForBiomass;

  /// No description provided for @emptyTankActivateHint.
  ///
  /// In nb, this message translates to:
  /// **'Ikke i bruk. Legg inn fisketall med blyanten for å aktivere karet.'**
  String get emptyTankActivateHint;

  /// No description provided for @leaveWeightEmptyHint.
  ///
  /// In nb, this message translates to:
  /// **'La stå tomt hvis fisken ikke er veid i dag'**
  String get leaveWeightEmptyHint;

  /// No description provided for @feedInventoryLoadFailed.
  ///
  /// In nb, this message translates to:
  /// **'Kunne ikke laste fôrlager nå.'**
  String get feedInventoryLoadFailed;

  /// No description provided for @noActiveFeedUsesRecommended.
  ///
  /// In nb, this message translates to:
  /// **'Ingen aktive fôrtyper i lager. Anbefalt fôrtype brukes.'**
  String get noActiveFeedUsesRecommended;

  /// No description provided for @recommendedFeedUsed.
  ///
  /// In nb, this message translates to:
  /// **'Ikke valgt - bruker anbefalt fôrtype'**
  String get recommendedFeedUsed;

  /// No description provided for @selectedFeedDrawnFromInventory.
  ///
  /// In nb, this message translates to:
  /// **'Valgt fôrtype trekkes fra lager'**
  String get selectedFeedDrawnFromInventory;

  /// No description provided for @feedSelectionOptionalHint.
  ///
  /// In nb, this message translates to:
  /// **'Valgfritt. Brukes bare hvis du gir annen type enn anbefalt.'**
  String get feedSelectionOptionalHint;

  /// No description provided for @recommendedFeedType.
  ///
  /// In nb, this message translates to:
  /// **'Anbefalt fôrtype'**
  String get recommendedFeedType;

  /// No description provided for @stockLevel.
  ///
  /// In nb, this message translates to:
  /// **'Lagerbeholdning'**
  String get stockLevel;

  /// No description provided for @checkingStock.
  ///
  /// In nb, this message translates to:
  /// **'Sjekker lager...'**
  String get checkingStock;

  /// No description provided for @notAvailable.
  ///
  /// In nb, this message translates to:
  /// **'Ikke tilgjengelig'**
  String get notAvailable;

  /// No description provided for @notFoundInActiveInventory.
  ///
  /// In nb, this message translates to:
  /// **'Ikke funnet i aktivt fôrlager'**
  String get notFoundInActiveInventory;

  /// No description provided for @recommendedDailyFeedAmount.
  ///
  /// In nb, this message translates to:
  /// **'Anbefalt daglig fôrmengde'**
  String get recommendedDailyFeedAmount;

  /// No description provided for @feedPercent.
  ///
  /// In nb, this message translates to:
  /// **'Fôrprosent'**
  String get feedPercent;

  /// No description provided for @startWeight.
  ///
  /// In nb, this message translates to:
  /// **'Startvekt'**
  String get startWeight;

  /// No description provided for @endWeight.
  ///
  /// In nb, this message translates to:
  /// **'Sluttvekt'**
  String get endWeight;

  /// No description provided for @biomassGain.
  ///
  /// In nb, this message translates to:
  /// **'Biomasseøkning'**
  String get biomassGain;

  /// No description provided for @currentAverageWeight.
  ///
  /// In nb, this message translates to:
  /// **'Nåværende snittvekt'**
  String get currentAverageWeight;

  /// No description provided for @forecastDays.
  ///
  /// In nb, this message translates to:
  /// **'Prognose {days} dager'**
  String forecastDays(int days);

  /// No description provided for @dataBasis.
  ///
  /// In nb, this message translates to:
  /// **'Datagrunnlag'**
  String get dataBasis;

  /// No description provided for @daysCount.
  ///
  /// In nb, this message translates to:
  /// **'{count} dager'**
  String daysCount(int count);

  /// No description provided for @invited.
  ///
  /// In nb, this message translates to:
  /// **'Du er invitert'**
  String get invited;

  /// No description provided for @roleLine.
  ///
  /// In nb, this message translates to:
  /// **'Rolle: {role}'**
  String roleLine(String role);

  /// No description provided for @passwordMinimum.
  ///
  /// In nb, this message translates to:
  /// **'Passordet må ha minst 6 tegn'**
  String get passwordMinimum;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In nb, this message translates to:
  /// **'Passordene er ikke like'**
  String get passwordsDoNotMatch;

  /// No description provided for @confirmPassword.
  ///
  /// In nb, this message translates to:
  /// **'Gjenta passord'**
  String get confirmPassword;

  /// No description provided for @showPassword.
  ///
  /// In nb, this message translates to:
  /// **'Vis passord'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In nb, this message translates to:
  /// **'Skjul passord'**
  String get hidePassword;

  /// No description provided for @signInAndAccept.
  ///
  /// In nb, this message translates to:
  /// **'Logg inn og godta'**
  String get signInAndAccept;

  /// No description provided for @createAccount.
  ///
  /// In nb, this message translates to:
  /// **'Opprett konto'**
  String get createAccount;

  /// No description provided for @needNewAccount.
  ///
  /// In nb, this message translates to:
  /// **'Jeg trenger en ny konto'**
  String get needNewAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In nb, this message translates to:
  /// **'Jeg har allerede konto'**
  String get alreadyHaveAccount;

  /// No description provided for @invalidInvitation.
  ///
  /// In nb, this message translates to:
  /// **'Invitasjonen er ugyldig eller utløpt'**
  String get invalidInvitation;

  /// No description provided for @askAdminForInvitation.
  ///
  /// In nb, this message translates to:
  /// **'Be administrator opprette en ny invitasjon.'**
  String get askAdminForInvitation;

  /// No description provided for @serviceTimedOut.
  ///
  /// In nb, this message translates to:
  /// **'Tjenesten brukte for lang tid. Prøv igjen.'**
  String get serviceTimedOut;

  /// No description provided for @couldNotCompleteInvitation.
  ///
  /// In nb, this message translates to:
  /// **'Kunne ikke fullføre invitasjonen'**
  String get couldNotCompleteInvitation;

  /// No description provided for @wrongSignedInUser.
  ///
  /// In nb, this message translates to:
  /// **'Du er logget inn som {email}. Logg ut for å bruke invitasjonen.'**
  String wrongSignedInUser(String email);

  /// No description provided for @logoutQuestion.
  ///
  /// In nb, this message translates to:
  /// **'Logg ut?'**
  String get logoutQuestion;

  /// No description provided for @logoutConfirmation.
  ///
  /// In nb, this message translates to:
  /// **'Er du sikker på at du vil logge ut?'**
  String get logoutConfirmation;

  /// No description provided for @dashboardLoadTimeout.
  ///
  /// In nb, this message translates to:
  /// **'Det tok for lang tid å hente driftsdata. Kontroller nettet og prøv igjen.'**
  String get dashboardLoadTimeout;

  /// No description provided for @dashboardPermissionDenied.
  ///
  /// In nb, this message translates to:
  /// **'Brukeren mangler tilgang til driftsdata. Kontakt administrator.'**
  String get dashboardPermissionDenied;

  /// No description provided for @dashboardUnavailable.
  ///
  /// In nb, this message translates to:
  /// **'Driftsdata er midlertidig utilgjengelige. Kontroller nettet og prøv igjen.'**
  String get dashboardUnavailable;

  /// No description provided for @dashboardLoadFailed.
  ///
  /// In nb, this message translates to:
  /// **'Dashboardet kunne ikke lastes akkurat nå. Prøv igjen.'**
  String get dashboardLoadFailed;

  /// No description provided for @signedInUser.
  ///
  /// In nb, this message translates to:
  /// **'Innlogget bruker'**
  String get signedInUser;

  /// No description provided for @tankUnavailable.
  ///
  /// In nb, this message translates to:
  /// **'Karet finnes ikke lenger i oversikten.'**
  String get tankUnavailable;

  /// No description provided for @unknownTank.
  ///
  /// In nb, this message translates to:
  /// **'Ukjent kar'**
  String get unknownTank;

  /// No description provided for @tankNameExample.
  ///
  /// In nb, this message translates to:
  /// **'F.eks. K1'**
  String get tankNameExample;

  /// No description provided for @fishCountLargeExample.
  ///
  /// In nb, this message translates to:
  /// **'F.eks. 12500'**
  String get fishCountLargeExample;

  /// No description provided for @operationalNote.
  ///
  /// In nb, this message translates to:
  /// **'Driftsnotat'**
  String get operationalNote;

  /// No description provided for @deleteTankQuestion.
  ///
  /// In nb, this message translates to:
  /// **'Slette {tank}?'**
  String deleteTankQuestion(String tank);

  /// No description provided for @deleteTankConfirmation.
  ///
  /// In nb, this message translates to:
  /// **'Karet fjernes fra oversikten. Denne handlingen kan ikke angres.'**
  String get deleteTankConfirmation;

  /// No description provided for @couldNotMoveFish.
  ///
  /// In nb, this message translates to:
  /// **'Kunne ikke flytte fisken. Prøv igjen.'**
  String get couldNotMoveFish;

  /// No description provided for @kgPerBagExample.
  ///
  /// In nb, this message translates to:
  /// **'F.eks. 25'**
  String get kgPerBagExample;

  /// No description provided for @feedNameExample.
  ///
  /// In nb, this message translates to:
  /// **'F.eks. Nutra Olympic 3.0'**
  String get feedNameExample;

  /// No description provided for @pelletSizeExample.
  ///
  /// In nb, this message translates to:
  /// **'F.eks. 3.0'**
  String get pelletSizeExample;

  /// No description provided for @sampleSummary.
  ///
  /// In nb, this message translates to:
  /// **'{weight} g snitt ({count} fisk)'**
  String sampleSummary(String weight, int count);

  /// No description provided for @invitationStatusPending.
  ///
  /// In nb, this message translates to:
  /// **'Venter'**
  String get invitationStatusPending;

  /// No description provided for @invitationStatusAccepted.
  ///
  /// In nb, this message translates to:
  /// **'Godtatt'**
  String get invitationStatusAccepted;

  /// No description provided for @invitationStatusRevoked.
  ///
  /// In nb, this message translates to:
  /// **'Trukket tilbake'**
  String get invitationStatusRevoked;

  /// No description provided for @invitationStatusExpired.
  ///
  /// In nb, this message translates to:
  /// **'Utløpt'**
  String get invitationStatusExpired;

  /// No description provided for @enterEntryTitle.
  ///
  /// In nb, this message translates to:
  /// **'Skriv inn en tittel'**
  String get enterEntryTitle;

  /// No description provided for @enterEntryContent.
  ///
  /// In nb, this message translates to:
  /// **'Skriv inn tekst'**
  String get enterEntryContent;

  /// No description provided for @previousPeriod.
  ///
  /// In nb, this message translates to:
  /// **'Forrige periode'**
  String get previousPeriod;

  /// No description provided for @nextPeriod.
  ///
  /// In nb, this message translates to:
  /// **'Neste periode'**
  String get nextPeriod;

  /// No description provided for @dataPermissionDenied.
  ///
  /// In nb, this message translates to:
  /// **'Du har ikke tilgang til disse dataene. Kontakt administrator.'**
  String get dataPermissionDenied;

  /// No description provided for @dataLoadFailed.
  ///
  /// In nb, this message translates to:
  /// **'Kunne ikke hente data. Kontroller nettverket og prøv igjen.'**
  String get dataLoadFailed;

  /// No description provided for @noAverageWeightRegistered.
  ///
  /// In nb, this message translates to:
  /// **'Ingen snittvekt registrert ennå'**
  String get noAverageWeightRegistered;

  /// No description provided for @weightUntilFeed.
  ///
  /// In nb, this message translates to:
  /// **'{weight} g igjen til {feed}'**
  String weightUntilFeed(String weight, String feed);

  /// No description provided for @finishFeedLargeFish.
  ///
  /// In nb, this message translates to:
  /// **'Sluttfôr / stor fisk'**
  String get finishFeedLargeFish;

  /// No description provided for @invalidValue.
  ///
  /// In nb, this message translates to:
  /// **'Ugyldig {label}'**
  String invalidValue(String label);

  /// No description provided for @invalidMortality.
  ///
  /// In nb, this message translates to:
  /// **'Ugyldig dødelighet'**
  String get invalidMortality;

  /// No description provided for @enterAtLeastOneRegistration.
  ///
  /// In nb, this message translates to:
  /// **'Fyll inn minst én registrering.'**
  String get enterAtLeastOneRegistration;

  /// No description provided for @noRegistrationAccess.
  ///
  /// In nb, this message translates to:
  /// **'Du har ikke tilgang til å registrere.'**
  String get noRegistrationAccess;

  /// No description provided for @tankNoLongerExists.
  ///
  /// In nb, this message translates to:
  /// **'Karet finnes ikke lenger.'**
  String get tankNoLongerExists;

  /// No description provided for @emptyTankBeforeRegistration.
  ///
  /// In nb, this message translates to:
  /// **'Karet er tomt. Legg inn fisketall før drift registreres.'**
  String get emptyTankBeforeRegistration;

  /// No description provided for @mortalityExceedsFishCount.
  ///
  /// In nb, this message translates to:
  /// **'Dødelighet kan ikke være større enn fisketallet.'**
  String get mortalityExceedsFishCount;

  /// No description provided for @selectedFeedTypeMissing.
  ///
  /// In nb, this message translates to:
  /// **'Valgt fôrtype finnes ikke.'**
  String get selectedFeedTypeMissing;

  /// No description provided for @insufficientFeedInStock.
  ///
  /// In nb, this message translates to:
  /// **'Ikke nok fôr på lager. Tilgjengelig: {amount} kg.'**
  String insufficientFeedInStock(String amount);

  /// No description provided for @registrationCancelled.
  ///
  /// In nb, this message translates to:
  /// **'Registreringen ble avbrutt.'**
  String get registrationCancelled;

  /// No description provided for @registrationSaved.
  ///
  /// In nb, this message translates to:
  /// **'Registrering lagret'**
  String get registrationSaved;

  /// No description provided for @registrationSaveFailed.
  ///
  /// In nb, this message translates to:
  /// **'Kunne ikke lagre registreringen. Prøv igjen.'**
  String get registrationSaveFailed;

  /// No description provided for @allTanksReviewed.
  ///
  /// In nb, this message translates to:
  /// **'Alle kar i denne seksjonen er gjennomgått.'**
  String get allTanksReviewed;

  /// No description provided for @nextTankOpenFailed.
  ///
  /// In nb, this message translates to:
  /// **'Registreringen er lagret, men neste kar kunne ikke åpnes. Prøv igjen.'**
  String get nextTankOpenFailed;

  /// No description provided for @overview.
  ///
  /// In nb, this message translates to:
  /// **'Oversikt'**
  String get overview;

  /// No description provided for @tools.
  ///
  /// In nb, this message translates to:
  /// **'Verktøy'**
  String get tools;

  /// No description provided for @latestAverageWeightLine.
  ///
  /// In nb, this message translates to:
  /// **'Siste snittvekt: {weight}'**
  String latestAverageWeightLine(String weight);

  /// No description provided for @registerAverageWeightForFeed.
  ///
  /// In nb, this message translates to:
  /// **'Registrer snittvekt for å beregne fôrrasjon'**
  String get registerAverageWeightForFeed;

  /// No description provided for @sgrOverDays.
  ///
  /// In nb, this message translates to:
  /// **'SGR: {sgr} %/dag over {days} dager'**
  String sgrOverDays(String sgr, int days);

  /// No description provided for @fullName.
  ///
  /// In nb, this message translates to:
  /// **'Fullt navn'**
  String get fullName;

  /// No description provided for @emailAlreadyRegistered.
  ///
  /// In nb, this message translates to:
  /// **'Denne e-postadressen er allerede registrert.'**
  String get emailAlreadyRegistered;

  /// No description provided for @activeInvitationExists.
  ///
  /// In nb, this message translates to:
  /// **'Det finnes allerede en aktiv invitasjon for denne e-postadressen.'**
  String get activeInvitationExists;

  /// No description provided for @invalidRole.
  ///
  /// In nb, this message translates to:
  /// **'Ugyldig rolle.'**
  String get invalidRole;

  /// No description provided for @inviteServiceUnavailable.
  ///
  /// In nb, this message translates to:
  /// **'Invitasjonstjenesten er ikke tilgjengelig. Prøv igjen.'**
  String get inviteServiceUnavailable;

  /// No description provided for @signInWithInvitedEmail.
  ///
  /// In nb, this message translates to:
  /// **'Logg inn med e-postadressen invitasjonen ble sendt til.'**
  String get signInWithInvitedEmail;

  /// No description provided for @invitationGreeting.
  ///
  /// In nb, this message translates to:
  /// **'Hei!'**
  String get invitationGreeting;

  /// No description provided for @invitationGreetingNamed.
  ///
  /// In nb, this message translates to:
  /// **'Hei {name}!'**
  String invitationGreetingNamed(String name);

  /// No description provided for @invitationCopyBody.
  ///
  /// In nb, this message translates to:
  /// **'Du er invitert til Fjellfisk for Arctic Hardanger.\n\nÅpne lenken og registrer eller logg inn med denne e-postadressen:\n{email}\n\nLenke:\n{link}\n\nMvh\nArctic Hardanger'**
  String invitationCopyBody(String email, String link);

  /// No description provided for @startingApp.
  ///
  /// In nb, this message translates to:
  /// **'Starter Fjellfisk...'**
  String get startingApp;

  /// No description provided for @startupFailedTitle.
  ///
  /// In nb, this message translates to:
  /// **'Kunne ikke starte appen'**
  String get startupFailedTitle;

  /// No description provided for @startupFailedMessage.
  ///
  /// In nb, this message translates to:
  /// **'Sjekk internettforbindelsen og prøv igjen. Hvis feilen fortsetter, kontakt administrator.'**
  String get startupFailedMessage;

  /// No description provided for @checkingLogin.
  ///
  /// In nb, this message translates to:
  /// **'Sjekker innlogging...'**
  String get checkingLogin;

  /// No description provided for @checkingAccess.
  ///
  /// In nb, this message translates to:
  /// **'Sjekker tilgang...'**
  String get checkingAccess;

  /// No description provided for @loginCheckFailedTitle.
  ///
  /// In nb, this message translates to:
  /// **'Kunne ikke sjekke innlogging'**
  String get loginCheckFailedTitle;

  /// No description provided for @loginCheckFailedMessage.
  ///
  /// In nb, this message translates to:
  /// **'Appen fikk ikke kontakt med innloggingstjenesten. Prøv igjen.'**
  String get loginCheckFailedMessage;

  /// No description provided for @accessDeniedTitle.
  ///
  /// In nb, this message translates to:
  /// **'Ingen tilgang'**
  String get accessDeniedTitle;

  /// No description provided for @accessDeniedMessage.
  ///
  /// In nb, this message translates to:
  /// **'Du har ikke tilgang til Fjellfisk. Kontakt administrator.'**
  String get accessDeniedMessage;

  /// No description provided for @roleCheckFailedTitle.
  ///
  /// In nb, this message translates to:
  /// **'Kunne ikke sjekke tilgang'**
  String get roleCheckFailedTitle;

  /// No description provided for @roleCheckFailedMessage.
  ///
  /// In nb, this message translates to:
  /// **'Appen fikk ikke lest brukerrollen din. Kontakt administrator hvis du nylig har fått bruker eller rolle.'**
  String get roleCheckFailedMessage;

  /// No description provided for @userDisabledTitle.
  ///
  /// In nb, this message translates to:
  /// **'Brukeren er deaktivert'**
  String get userDisabledTitle;

  /// No description provided for @userDisabledDetail.
  ///
  /// In nb, this message translates to:
  /// **'Kontakt administrator hvis du trenger tilgang igjen.'**
  String get userDisabledDetail;

  /// No description provided for @excelSheetFacility.
  ///
  /// In nb, this message translates to:
  /// **'Anlegg'**
  String get excelSheetFacility;

  /// No description provided for @excelSheetTank.
  ///
  /// In nb, this message translates to:
  /// **'Kar'**
  String get excelSheetTank;

  /// No description provided for @excelSheetSummary.
  ///
  /// In nb, this message translates to:
  /// **'Sammendrag'**
  String get excelSheetSummary;

  /// No description provided for @excelSheetTankOverview.
  ///
  /// In nb, this message translates to:
  /// **'Karoversikt'**
  String get excelSheetTankOverview;

  /// No description provided for @excelSheetRegistrations.
  ///
  /// In nb, this message translates to:
  /// **'Registreringer'**
  String get excelSheetRegistrations;

  /// No description provided for @keyFigures.
  ///
  /// In nb, this message translates to:
  /// **'Nøkkeltall'**
  String get keyFigures;

  /// No description provided for @productionReportTitle.
  ///
  /// In nb, this message translates to:
  /// **'Produksjonsrapport'**
  String get productionReportTitle;

  /// No description provided for @filter.
  ///
  /// In nb, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @value.
  ///
  /// In nb, this message translates to:
  /// **'Verdi'**
  String get value;

  /// No description provided for @registeredBiomassKg.
  ///
  /// In nb, this message translates to:
  /// **'Registrert biomasse kg'**
  String get registeredBiomassKg;

  /// No description provided for @latestAverageWeightGram.
  ///
  /// In nb, this message translates to:
  /// **'Siste snittvekt g'**
  String get latestAverageWeightGram;

  /// No description provided for @weightChangeGram.
  ///
  /// In nb, this message translates to:
  /// **'Vektendring g'**
  String get weightChangeGram;

  /// No description provided for @averageTemperatureLabel.
  ///
  /// In nb, this message translates to:
  /// **'Temperatur gjennomsnitt'**
  String get averageTemperatureLabel;

  /// No description provided for @minimumTemperatureLabel.
  ///
  /// In nb, this message translates to:
  /// **'Temperatur minimum'**
  String get minimumTemperatureLabel;

  /// No description provided for @maximumTemperatureLabel.
  ///
  /// In nb, this message translates to:
  /// **'Temperatur maksimum'**
  String get maximumTemperatureLabel;

  /// No description provided for @facilityName.
  ///
  /// In nb, this message translates to:
  /// **'Anleggsnavn'**
  String get facilityName;

  /// No description provided for @sectionBuilding.
  ///
  /// In nb, this message translates to:
  /// **'Seksjon/bygg'**
  String get sectionBuilding;

  /// No description provided for @date.
  ///
  /// In nb, this message translates to:
  /// **'Dato'**
  String get date;

  /// No description provided for @feedKg.
  ///
  /// In nb, this message translates to:
  /// **'Fôr kg'**
  String get feedKg;

  /// No description provided for @diaryPdfTitle.
  ///
  /// In nb, this message translates to:
  /// **'Fjellfisk Dagbok / Driftslogg'**
  String get diaryPdfTitle;

  /// No description provided for @noDiaryEntriesForPeriod.
  ///
  /// In nb, this message translates to:
  /// **'Ingen innlegg i valgt periode.'**
  String get noDiaryEntriesForPeriod;

  /// No description provided for @dateMissing.
  ///
  /// In nb, this message translates to:
  /// **'Dato mangler'**
  String get dateMissing;

  /// No description provided for @unknownUser.
  ///
  /// In nb, this message translates to:
  /// **'Ukjent bruker'**
  String get unknownUser;

  /// No description provided for @untitled.
  ///
  /// In nb, this message translates to:
  /// **'Uten tittel'**
  String get untitled;

  /// No description provided for @pageOf.
  ///
  /// In nb, this message translates to:
  /// **'Side {current} av {total}'**
  String pageOf(int current, int total);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'nb', 'pl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'nb':
      return AppLocalizationsNb();
    case 'pl':
      return AppLocalizationsPl();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

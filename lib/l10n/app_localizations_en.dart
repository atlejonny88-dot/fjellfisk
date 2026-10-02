// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Fjellfisk';

  @override
  String get norwegian => 'Norwegian';

  @override
  String get english => 'English';

  @override
  String get polish => 'Polish';

  @override
  String get language => 'Language';

  @override
  String get changeLanguage => 'Change language';

  @override
  String get languageSaveFailed =>
      'The language could not be saved yet. It will still be used for this session.';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get refresh => 'Refresh';

  @override
  String get refreshDashboard => 'Refresh dashboard';

  @override
  String get updating => 'Refreshing';

  @override
  String get logout => 'Log out';

  @override
  String get facility => 'Facility';

  @override
  String get user => 'User';

  @override
  String get diary => 'Diary / Operations log';

  @override
  String get productionReport => 'Production report';

  @override
  String get feedInventory => 'Feed inventory';

  @override
  String get excelExport => 'Excel export';

  @override
  String get usersAndAccess => 'Users & Access';

  @override
  String get activeTanks => 'Active tanks';

  @override
  String tanksOfTotal(int count) {
    return 'of $count tanks';
  }

  @override
  String emptyTanks(int count) {
    return '$count empty tanks';
  }

  @override
  String get emptyTanksLabel => 'Empty tanks';

  @override
  String get biomass => 'Biomass';

  @override
  String fishCount(int count) {
    return '$count fish';
  }

  @override
  String get fish => 'Fish';

  @override
  String activeAndEmptyTanks(int active, int empty) {
    return '$active active / $empty empty';
  }

  @override
  String get recommendedFeedLabel => 'Recommended feed';

  @override
  String get activeBiomass => 'Active biomass';

  @override
  String get feedToday => 'Feed today';

  @override
  String get actualRecorded => 'Actually recorded';

  @override
  String recommendedFeed(String amount) {
    return 'Recommended $amount kg';
  }

  @override
  String get deadToday => 'Deaths today';

  @override
  String get recordedMortality => 'Recorded mortality';

  @override
  String get noneRecordedToday => 'None recorded today';

  @override
  String get numberOfFish => 'Number of fish';

  @override
  String get averageTemperature => 'Average temperature';

  @override
  String get recordedMeasurements => 'Recorded measurements';

  @override
  String get updatedFromTankLogs => 'Updated from tank logs';

  @override
  String get noData => 'No data';

  @override
  String get notEnoughData => 'Not enough data';

  @override
  String get buildings => 'Buildings';

  @override
  String sectionsWithTanks(int sections, int tanks) {
    return '$sections sections with $tanks tanks';
  }

  @override
  String get exportFacilityToExcel => 'Export facility to Excel';

  @override
  String get operationalTools => 'Operations tools';

  @override
  String get operationalToolsSubtitle =>
      'Reports, inventory and administration';

  @override
  String get reportSubtitle => 'View key figures for the selected period';

  @override
  String get feedInventorySubtitle => 'View stock and inventory history';

  @override
  String get excelSubtitle => 'Export a complete facility overview';

  @override
  String get accessSubtitle => 'Change roles and access';

  @override
  String get retry => 'Try again';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get create => 'Create';

  @override
  String get close => 'Close';

  @override
  String get notifications => 'Notifications';

  @override
  String unreadNotifications(int count) {
    return '$count unread notifications';
  }

  @override
  String get noUnreadNotifications => 'No unread notifications';

  @override
  String get markAllRead => 'Mark all as read';

  @override
  String get marking => 'Marking...';

  @override
  String get markAsRead => 'Mark as read';

  @override
  String get closeNotifications => 'Close notifications';

  @override
  String get noNotifications => 'No notifications';

  @override
  String get notificationsUnavailable =>
      'Notifications are not available right now';

  @override
  String get notificationsUnavailableDetail =>
      'The rest of Fjellfisk is working normally. Try again later.';

  @override
  String get noNotificationsDetail => 'New operational alerts appear here.';

  @override
  String todayAt(String time) {
    return 'Today $time';
  }

  @override
  String yesterdayAt(String time) {
    return 'Yesterday $time';
  }

  @override
  String get couldNotOpenNotification =>
      'Could not open the notification. Try again.';

  @override
  String get couldNotMarkNotificationRead =>
      'Could not mark the notification as read.';

  @override
  String get couldNotMarkAllNotificationsRead =>
      'Could not mark all notifications as read.';

  @override
  String get newVersionAvailable => 'New Fjellfisk version available';

  @override
  String get updateWhenSaved => 'Update the app after saving any changes.';

  @override
  String get highMortality => 'High mortality';

  @override
  String highMortalityTank(String tank) {
    return 'High mortality in $tank';
  }

  @override
  String deathsLast7Days(int count) {
    return '$count deaths in the last 7 days. Check the tank and registrations.';
  }

  @override
  String get lowFeedStock => 'Low feed stock';

  @override
  String lowFeedStockItem(String feed) {
    return 'Low feed stock: $feed';
  }

  @override
  String feedStockBody(String stock, String threshold) {
    return '$stock kg remaining. Alert threshold is $threshold kg (one bag).';
  }

  @override
  String newTankNote(String tank) {
    return 'New operational note on $tank';
  }

  @override
  String get newDiaryEntry => 'New entry';

  @override
  String newDiaryEntryTitle(String title) {
    return 'New diary entry: $title';
  }

  @override
  String get login => 'Log in';

  @override
  String get loginTagline => 'Operations. Overview. Control.';

  @override
  String get loginContinue => 'Sign in to continue';

  @override
  String get signingIn => 'Signing in';

  @override
  String appVersion(String version) {
    return 'Fjellfisk v$version';
  }

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get signIn => 'Log in';

  @override
  String get enterEmailAndPassword => 'Enter your email and password.';

  @override
  String get loginTimeout =>
      'Signing in took too long. Close Safari completely and try again.';

  @override
  String get loginFailed => 'Could not log in. Try again.';

  @override
  String get invalidEmail => 'Invalid email address.';

  @override
  String get invalidCredentials => 'Incorrect email or password.';

  @override
  String get userDisabledMessage =>
      'This user is disabled. Contact an administrator.';

  @override
  String get tooManyLoginAttempts =>
      'Too many attempts. Wait a moment and try again.';

  @override
  String get loginNetworkFailed =>
      'Could not contact the sign-in service. Check your internet connection.';

  @override
  String get emptyTank => 'Empty tank';

  @override
  String get notInUse => 'Not in use';

  @override
  String get sections => 'Sections';

  @override
  String get tank => 'Tank';

  @override
  String get tanks => 'Tanks';

  @override
  String get newTank => 'New tank';

  @override
  String get tankName => 'Tank name';

  @override
  String get numberOfFishLabel => 'Number of fish';

  @override
  String get createFirstTank => 'Create first tank';

  @override
  String get tankOverview => 'Tank overview';

  @override
  String tankOverviewTitle(String section) {
    return 'Tank overview · $section';
  }

  @override
  String get tankOverviewSubtitle =>
      'Overview and latest key figures for all tanks in this section.';

  @override
  String get refreshTankOverview => 'Refresh tank overview';

  @override
  String get loadingTanks => 'Loading tanks...';

  @override
  String noTanksInSection(String section) {
    return 'No tanks in $section yet';
  }

  @override
  String get searchTanks => 'Search tanks...';

  @override
  String get allTanks => 'All tanks';

  @override
  String get observation => 'Observation';

  @override
  String get critical => 'Critical';

  @override
  String get criticalPlural => 'Critical';

  @override
  String get noMatchingTanks => 'No tanks match the selected search or filter.';

  @override
  String get noValue => 'None';

  @override
  String get noFeed => 'No feeding';

  @override
  String get normalOperation => 'Normal operation';

  @override
  String get missingAverageWeight => 'Average weight missing';

  @override
  String get oldAverageWeight => 'Old average weight';

  @override
  String highMortalityMessage(int count) {
    return 'High mortality · $count deaths in the last 7 days';
  }

  @override
  String followUpMeasurements(String status) {
    return '$status · follow up with new measurements';
  }

  @override
  String get emptyTankMessage => 'Not in use · can be opened and stocked later';

  @override
  String normalMortalityMessage(int count) {
    return 'Normal operation · mortality 7d: $count';
  }

  @override
  String get allValuesNormal => 'All values are within normal limits';

  @override
  String get feed => 'Feed';

  @override
  String get mortality => 'Mortality';

  @override
  String get averageWeight => 'Average weight';

  @override
  String get temperature => 'Temperature';

  @override
  String get history => 'History';

  @override
  String get tankInfo => 'Tank info';

  @override
  String get weightSamples => 'Weight samples';

  @override
  String get growthForecast => 'Growth forecast';

  @override
  String get markReviewed => 'Reviewed';

  @override
  String get reviewedThisSession => 'Reviewed in this session';

  @override
  String get feedLast24Hours => 'Feed 24h';

  @override
  String get deathsLast7DaysShort => 'Deaths 7d';

  @override
  String get moreOptions => 'More options';

  @override
  String get deleteTank => 'Delete tank';

  @override
  String get tankIllustration => 'Aquaculture tank illustration';

  @override
  String get tankNotesUnavailable => 'Operational notes are not available';

  @override
  String get saveAndNext => 'Save and next';

  @override
  String get nextTank => 'Next tank';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get roleEmployee => 'Employee';

  @override
  String get roleReader => 'Viewer';

  @override
  String get statusActive => 'Active';

  @override
  String get statusDisabled => 'Disabled';

  @override
  String get dashboardUpdated => 'Dashboard updated';

  @override
  String get excelExportComplete => 'Excel export completed';

  @override
  String get excelExportFailed => 'Could not export Excel. Try again.';

  @override
  String get contentUnavailable => 'The related content is not available now.';

  @override
  String get loading => 'Loading...';

  @override
  String get period => 'Period';

  @override
  String get today => 'Today';

  @override
  String get last7Days => 'Last 7 days';

  @override
  String get last30Days => 'Last 30 days';

  @override
  String get currentMonth => 'This month';

  @override
  String get customPeriod => 'Custom period';

  @override
  String fromDate(String date) {
    return 'From $date';
  }

  @override
  String toDate(String date) {
    return 'To $date';
  }

  @override
  String get reportFor => 'Report for';

  @override
  String get entireFacility => 'Entire facility';

  @override
  String get buildingOrSection => 'Building/section';

  @override
  String get singleTank => 'Single tank';

  @override
  String get selectBuildingOrTank => 'Select a building or tank';

  @override
  String get reportSelectionHint =>
      'The report is shown when the selection is complete.';

  @override
  String get reportCreationFailed => 'Could not create the report';

  @override
  String get reportCreationHint => 'Try again. Check your network and access.';

  @override
  String get reportExportFailed => 'Could not export the report. Try again.';

  @override
  String get exportToExcel => 'Export to Excel';

  @override
  String get noRecordsSelectedPeriod =>
      'No registrations in the selected period';

  @override
  String get reportDataAvailability =>
      'Tank status and latest biomass are shown where data is available.';

  @override
  String get feedUsed => 'Feed used';

  @override
  String get latestAverageWeight => 'Latest average weight';

  @override
  String get weightChange => 'Weight change';

  @override
  String get fcrUnavailable => 'FCR cannot be calculated';

  @override
  String get registrations => 'Registrations';

  @override
  String get noTanksForFilter => 'No tanks found for the selected filter';

  @override
  String get section => 'Section';

  @override
  String get dead => 'Dead';

  @override
  String get temperatureShort => 'Temp';

  @override
  String historyForTank(String tank) {
    return 'History - $tank';
  }

  @override
  String get noRecordsFound => 'No registrations found';

  @override
  String get changeFilterOrPeriod => 'Try changing the filter or period.';

  @override
  String get registrationType => 'Registration type';

  @override
  String get all => 'All';

  @override
  String get notes => 'Notes';

  @override
  String get resetFilter => 'Reset filter';

  @override
  String get unknownDate => 'Unknown date';

  @override
  String mortalityAndFeed(String mortality, String feed) {
    return 'Deaths: $mortality  •  Feed: $feed kg';
  }

  @override
  String feedTypeLine(String type) {
    return 'Feed type: $type';
  }

  @override
  String pelletLine(String size) {
    return 'Pellet: $size mm';
  }

  @override
  String noteLine(String note) {
    return 'Note: $note';
  }

  @override
  String tankInfoTitle(String tank) {
    return 'Tank info - $tank';
  }

  @override
  String get couldNotFetchData =>
      'Could not fetch data. Go back and try again.';

  @override
  String get calculating => 'Calculating...';

  @override
  String weightSampleForTank(String tank) {
    return 'Weight sample - $tank';
  }

  @override
  String get readerAccess => 'Read-only access';

  @override
  String readOnlyRole(String role) {
    return 'You are signed in as $role and can only view.';
  }

  @override
  String get emptyTankDescription =>
      'The tank is empty. Add fish before registering weight samples.';

  @override
  String get simpleAverageWeight => 'Standard average weight';

  @override
  String get individualWeights => 'Individual weights';

  @override
  String get averageWeightGram => 'Average weight (g)';

  @override
  String get averageWeightInputHelp => 'Supports 250, 250.5 and 250,5';

  @override
  String get saveAverageWeight => 'Save average weight';

  @override
  String get weightInGrams => 'Weight in grams';

  @override
  String get weightSampleInputHelp =>
      'Enter one weight or paste several weights separated by spaces, commas or line breaks.';

  @override
  String get add => 'Add';

  @override
  String get clearList => 'Clear list';

  @override
  String get comment => 'Comment';

  @override
  String get optional => 'Optional';

  @override
  String get saveWeightSample => 'Save weight sample';

  @override
  String get weightSamplesUnavailable =>
      'Weight samples are not available right now.';

  @override
  String get noWeightSamples => 'No weight samples have been registered yet.';

  @override
  String get latestWeightSample => 'Latest weight sample';

  @override
  String get distribution => 'Distribution';

  @override
  String get noDistribution => 'No distribution available.';

  @override
  String commentLine(String comment) {
    return 'Comment: $comment';
  }

  @override
  String weightGrowthTitle(String tank) {
    return 'Growth - $tank';
  }

  @override
  String get noWeightRecords => 'No weight registrations yet';

  @override
  String mortalityTitle(String tank) {
    return 'Mortality - $tank';
  }

  @override
  String get noMortalityRecords => 'No mortality data yet';

  @override
  String get totalMortality => 'Total mortality';

  @override
  String get numberOfRegistrations => 'Number of registrations';

  @override
  String get moveFish => 'Move fish';

  @override
  String get moveFishValidation =>
      'Select a receiving tank and an amount greater than zero.';

  @override
  String get couldNotLoadTanks => 'Could not load tanks. Try again.';

  @override
  String get noOtherTanks => 'No other tanks to move fish to';

  @override
  String get fromTank => 'From tank';

  @override
  String get moveToTank => 'Move to tank';

  @override
  String get fishToMove => 'Number of fish to move';

  @override
  String get fishCountExample => 'For example 2000';

  @override
  String get enterWeightFirst => 'Enter a weight first.';

  @override
  String invalidValuesNotAdded(String values) {
    return 'Some values were not added: $values';
  }

  @override
  String get invalidAverageWeight => 'Invalid average weight';

  @override
  String get averageWeightSaved => 'Average weight saved';

  @override
  String get addWeightBeforeSaving => 'Add at least one weight before saving.';

  @override
  String get weightSampleSaved => 'Weight sample saved';

  @override
  String get emptyTankBeforeWeight =>
      'The tank is empty. Add a fish count before registering weight.';

  @override
  String get noWriteAccess => 'No write access';

  @override
  String get couldNotSaveWeight =>
      'Could not save the weight. The values were retained. Try again.';

  @override
  String get registerWeight => 'Register weight';

  @override
  String get count => 'Count';

  @override
  String get average => 'Average';

  @override
  String get median => 'Median';

  @override
  String get minimum => 'Min';

  @override
  String get maximum => 'Max';

  @override
  String get standardDeviation => 'Std. deviation';

  @override
  String get unknownTime => 'Unknown time';

  @override
  String get averageWeightOverTime => 'Average weight over time';

  @override
  String get mortalityPerRegistration => 'Mortality per registration';

  @override
  String get manageUsersSubtitle =>
      'Manage internal users, roles and invitations.';

  @override
  String get inviteUser => 'Invite user';

  @override
  String get couldNotUpdateUser => 'Could not update the user';

  @override
  String get usersUnavailable => 'Could not load users right now.';

  @override
  String get searchUsers => 'Search for a user...';

  @override
  String get noUsersFound => 'No users found';

  @override
  String get roleUpdated => 'Role updated';

  @override
  String get userDisabled => 'User disabled';

  @override
  String get userEnabled => 'User enabled';

  @override
  String get unknownEmail => 'Unknown email';

  @override
  String get activateUser => 'Enable user';

  @override
  String get deactivateUser => 'Disable user';

  @override
  String get actions => 'Actions';

  @override
  String get invitationLinkCopied => 'Invitation link copied';

  @override
  String get revokeInvitationQuestion => 'Revoke the invitation?';

  @override
  String get revokeInvitation => 'Revoke';

  @override
  String get invitationRevoked => 'Invitation revoked';

  @override
  String get couldNotRevokeInvitation => 'Could not revoke the invitation';

  @override
  String get invitationsUnavailable => 'Invitations are not available yet.';

  @override
  String get invitations => 'Invitations';

  @override
  String get noInvitations => 'No invitations have been created';

  @override
  String get invitationActions => 'Invitation actions';

  @override
  String get copyInvitationLink => 'Copy invitation link';

  @override
  String get invitePanelTitle => 'Invite user';

  @override
  String get nameOptional => 'Name (optional)';

  @override
  String get fullNameHint => 'Enter full name';

  @override
  String get emailHint => 'name@example.com';

  @override
  String get role => 'Role';

  @override
  String get invitationRoleInfo =>
      'The role is locked to the invitation. The link is valid for 7 days.';

  @override
  String get createInvitation => 'Create invitation';

  @override
  String get invitationCreated => 'Invitation created';

  @override
  String get couldNotCreateInvitation => 'Could not create the invitation';

  @override
  String get invitationReady => 'The invitation is ready to send.';

  @override
  String get copyInvitationText => 'Copy invitation text';

  @override
  String get accessDeniedUserAdmin => 'You do not have access to manage users';

  @override
  String get notRegistered => 'Not registered';

  @override
  String expiresOn(String date) {
    return 'expires $date';
  }

  @override
  String adjustBagsForFeed(String feed) {
    return 'Adjust $feed';
  }

  @override
  String get bagsToAdjust => 'Number of bags (+ / -)';

  @override
  String get bagsAdjustHint => 'For example 10 or -3';

  @override
  String kgPerBagForFeed(String feed) {
    return 'Kg per bag - $feed';
  }

  @override
  String get kgPerBag => 'Kg per bag';

  @override
  String get feedType => 'Feed type';

  @override
  String get newFeedType => 'New feed type';

  @override
  String get editFeedType => 'Edit feed type';

  @override
  String get feedName => 'Name';

  @override
  String get pelletSize => 'Pellet size mm';

  @override
  String get feedNameAndPelletRequired => 'Name and pellet size are required.';

  @override
  String get cannotDeactivateFeedWithStock =>
      'A feed type with bags in stock cannot be deactivated.';

  @override
  String get activeFeedInventory => 'Active feed inventory';

  @override
  String readOnlyInventoryRole(String role) {
    return 'You are signed in as $role and can only view inventory.';
  }

  @override
  String get inactiveFeedType => 'Inactive feed type';

  @override
  String bags(int count) {
    return '$count bags';
  }

  @override
  String get adjustBags => 'Adjust bags';

  @override
  String get editKgPerBag => 'Edit kg per bag';

  @override
  String get inventoryHistory => 'Inventory history';

  @override
  String get noInventoryHistory => 'No inventory history yet';

  @override
  String get unknownFeed => 'Unknown feed';

  @override
  String get tankCount => 'Current fish count';

  @override
  String get adjustFishCount => 'Adjust fish count';

  @override
  String get newFishCount => 'New fish count';

  @override
  String get unsavedChanges => 'Unsaved changes';

  @override
  String get leaveWithoutSaving =>
      'Go to the next tank without saving the new values?';

  @override
  String get newOperationalNote => 'New operational note';

  @override
  String get editOperationalNote => 'Edit operational note';

  @override
  String get noteHint => 'For example: too much feed waste';

  @override
  String get operationalNoteSaved => 'Operational note saved';

  @override
  String get operationalNoteSaveFailed =>
      'Could not save the operational note. Try again.';

  @override
  String get operationalNoteCompleted => 'Operational note marked as completed';

  @override
  String get newNote => 'New note';

  @override
  String get edit => 'Edit';

  @override
  String get markCompleted => 'Mark as completed';

  @override
  String get createOperationalNote => 'Create operational note';

  @override
  String completedNotes(int count) {
    return 'Completed notes ($count)';
  }

  @override
  String get otherFeedType => 'Other feed type from inventory';

  @override
  String get otherFeedTypeHint =>
      'Select this when a type other than the recommended one was fed.';

  @override
  String get selectFeedType => 'Select feed type';

  @override
  String get useRecommendedFeedType => 'Use recommended feed type';

  @override
  String get dailyFeedRation => 'Recommended daily feed ration';

  @override
  String get mortalityInput => 'Mortality';

  @override
  String get feedKgInput => 'Feed (kg)';

  @override
  String get averageWeightOptional => 'Average weight (g) – optional';

  @override
  String get temperatureInput => 'Temperature';

  @override
  String get day => 'Day';

  @override
  String get month => 'Month';

  @override
  String get year => 'Year';

  @override
  String get goToToday => 'Go to today';

  @override
  String get searchEntries => 'Search entries';

  @override
  String get category => 'Category';

  @override
  String get allCategories => 'All categories';

  @override
  String get printMonth => 'Print month';

  @override
  String get printYear => 'Print year';

  @override
  String get noDiaryEntries => 'No diary entries in the selected period';

  @override
  String get diaryUnavailablePermission =>
      'The operations log is unavailable until the access rules are updated.';

  @override
  String get diaryLoadFailed =>
      'The operations log could not be loaded right now. The rest of the dashboard works normally.';

  @override
  String get diaryLoadingLong =>
      'The operations log is taking a long time to respond. The rest of the dashboard works normally.';

  @override
  String get diaryEntrySaved => 'Diary entry saved';

  @override
  String get diaryEntryUpdated => 'Diary entry updated';

  @override
  String get diaryEntryArchived => 'Diary entry archived';

  @override
  String get couldNotSaveDiaryEntry => 'Could not save diary entry';

  @override
  String get couldNotUpdateDiaryEntry => 'Could not update diary entry';

  @override
  String get couldNotArchiveDiaryEntry => 'Could not archive diary entry';

  @override
  String get couldNotOpenPrint => 'Could not open print preview';

  @override
  String get archiveEntryQuestion => 'Archive entry?';

  @override
  String archiveEntryBody(String title) {
    return '“$title” is removed from the active diary.';
  }

  @override
  String get archive => 'Archive';

  @override
  String get editEntry => 'Edit entry';

  @override
  String get entryTitle => 'Title';

  @override
  String get entryContent => 'Text / content';

  @override
  String get entryActions => 'Entry actions';

  @override
  String get printEntry => 'Print entry';

  @override
  String diaryEntriesInView(int count) {
    return '$count entries in this view';
  }

  @override
  String moreDiaryEntries(int count) {
    return '$count more entries are available in the full diary.';
  }

  @override
  String get couldNotUpdateFeedInventory =>
      'Could not update the feed inventory. Try again.';

  @override
  String get editKgHint => 'Use the pencil on the card to change kg per bag.';

  @override
  String get pelletNotSet => 'Pellet size not set';

  @override
  String afterBags(String count) {
    return 'After: $count bags';
  }

  @override
  String get dateTimeSavedAutomatically =>
      'The date and time are saved automatically.';

  @override
  String get originalDatePreserved =>
      'The original date is retained. The change time is saved automatically.';

  @override
  String get saving => 'Saving…';

  @override
  String get openingNext => 'Opening next…';

  @override
  String get growthChart => 'Growth chart';

  @override
  String get mortalityChart => 'Mortality chart';

  @override
  String get noActiveOperationalNote => 'No active operational note.';

  @override
  String writtenBy(String email) {
    return 'Written by: $email';
  }

  @override
  String completedAt(String date) {
    return 'Completed: $date';
  }

  @override
  String get averageWeightMissingForBiomass =>
      'Register average weight to calculate biomass';

  @override
  String get emptyTankActivateHint =>
      'Not in use. Use the pencil to add fish count and activate the tank.';

  @override
  String get leaveWeightEmptyHint =>
      'Leave blank if the fish were not weighed today';

  @override
  String get feedInventoryLoadFailed => 'Could not load feed inventory now.';

  @override
  String get noActiveFeedUsesRecommended =>
      'No active feed types in inventory. The recommended feed type is used.';

  @override
  String get recommendedFeedUsed =>
      'Not selected - using recommended feed type';

  @override
  String get selectedFeedDrawnFromInventory =>
      'The selected feed type is deducted from inventory';

  @override
  String get feedSelectionOptionalHint =>
      'Optional. Only used when you feed a type other than the recommended one.';

  @override
  String get recommendedFeedType => 'Recommended feed type';

  @override
  String get stockLevel => 'Stock level';

  @override
  String get checkingStock => 'Checking inventory...';

  @override
  String get notAvailable => 'Not available';

  @override
  String get notFoundInActiveInventory => 'Not found in active feed inventory';

  @override
  String get recommendedDailyFeedAmount => 'Recommended daily feed amount';

  @override
  String get feedPercent => 'Feed percentage';

  @override
  String get startWeight => 'Start weight';

  @override
  String get endWeight => 'End weight';

  @override
  String get biomassGain => 'Biomass gain';

  @override
  String get currentAverageWeight => 'Current average weight';

  @override
  String forecastDays(int days) {
    return '$days-day forecast';
  }

  @override
  String get dataBasis => 'Data basis';

  @override
  String daysCount(int count) {
    return '$count days';
  }

  @override
  String get invited => 'You are invited';

  @override
  String roleLine(String role) {
    return 'Role: $role';
  }

  @override
  String get passwordMinimum => 'Password must have at least 6 characters';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get signInAndAccept => 'Sign in and accept';

  @override
  String get createAccount => 'Create account';

  @override
  String get needNewAccount => 'I need a new account';

  @override
  String get alreadyHaveAccount => 'I already have an account';

  @override
  String get invalidInvitation => 'The invitation is invalid or has expired';

  @override
  String get askAdminForInvitation =>
      'Ask an administrator to create a new invitation.';

  @override
  String get serviceTimedOut => 'The service took too long. Try again.';

  @override
  String get couldNotCompleteInvitation => 'Could not complete the invitation';

  @override
  String wrongSignedInUser(String email) {
    return 'You are signed in as $email. Log out to use this invitation.';
  }

  @override
  String get logoutQuestion => 'Log out?';

  @override
  String get logoutConfirmation => 'Are you sure you want to log out?';

  @override
  String get dashboardLoadTimeout =>
      'It took too long to load operational data. Check your network and try again.';

  @override
  String get dashboardPermissionDenied =>
      'The user does not have access to operational data. Contact an administrator.';

  @override
  String get dashboardUnavailable =>
      'Operational data is temporarily unavailable. Check your network and try again.';

  @override
  String get dashboardLoadFailed =>
      'The dashboard could not be loaded right now. Try again.';

  @override
  String get signedInUser => 'Signed-in user';

  @override
  String get tankUnavailable =>
      'The tank is no longer available in the overview.';

  @override
  String get unknownTank => 'Unknown tank';

  @override
  String get tankNameExample => 'E.g. K1';

  @override
  String get fishCountLargeExample => 'E.g. 12500';

  @override
  String get operationalNote => 'Operational note';

  @override
  String deleteTankQuestion(String tank) {
    return 'Delete $tank?';
  }

  @override
  String get deleteTankConfirmation =>
      'The tank will be removed from the overview. This action cannot be undone.';

  @override
  String get couldNotMoveFish => 'Could not move the fish. Try again.';

  @override
  String get kgPerBagExample => 'E.g. 25';

  @override
  String get feedNameExample => 'E.g. Nutra Olympic 3.0';

  @override
  String get pelletSizeExample => 'E.g. 3.0';

  @override
  String sampleSummary(String weight, int count) {
    return '$weight g average ($count fish)';
  }

  @override
  String get invitationStatusPending => 'Pending';

  @override
  String get invitationStatusAccepted => 'Accepted';

  @override
  String get invitationStatusRevoked => 'Revoked';

  @override
  String get invitationStatusExpired => 'Expired';

  @override
  String get enterEntryTitle => 'Enter a title';

  @override
  String get enterEntryContent => 'Enter text';

  @override
  String get previousPeriod => 'Previous period';

  @override
  String get nextPeriod => 'Next period';

  @override
  String get dataPermissionDenied =>
      'You do not have access to this data. Contact an administrator.';

  @override
  String get dataLoadFailed =>
      'Could not load data. Check your network and try again.';

  @override
  String get noAverageWeightRegistered => 'No average weight recorded yet';

  @override
  String weightUntilFeed(String weight, String feed) {
    return '$weight g remaining until $feed';
  }

  @override
  String get finishFeedLargeFish => 'Finishing feed / large fish';

  @override
  String invalidValue(String label) {
    return 'Invalid $label';
  }

  @override
  String get invalidMortality => 'Invalid mortality';

  @override
  String get enterAtLeastOneRegistration => 'Enter at least one registration.';

  @override
  String get noRegistrationAccess => 'You do not have permission to register.';

  @override
  String get tankNoLongerExists => 'The tank no longer exists.';

  @override
  String get emptyTankBeforeRegistration =>
      'The tank is empty. Enter a fish count before registering operations.';

  @override
  String get mortalityExceedsFishCount =>
      'Mortality cannot exceed the fish count.';

  @override
  String get selectedFeedTypeMissing =>
      'The selected feed type does not exist.';

  @override
  String insufficientFeedInStock(String amount) {
    return 'Not enough feed in stock. Available: $amount kg.';
  }

  @override
  String get registrationCancelled => 'The registration was cancelled.';

  @override
  String get registrationSaved => 'Registration saved';

  @override
  String get registrationSaveFailed =>
      'Could not save the registration. Try again.';

  @override
  String get allTanksReviewed =>
      'All tanks in this section have been reviewed.';

  @override
  String get nextTankOpenFailed =>
      'The registration was saved, but the next tank could not be opened. Try again.';

  @override
  String get overview => 'Overview';

  @override
  String get tools => 'Tools';

  @override
  String latestAverageWeightLine(String weight) {
    return 'Latest average weight: $weight';
  }

  @override
  String get registerAverageWeightForFeed =>
      'Record average weight to calculate the feed ration';

  @override
  String sgrOverDays(String sgr, int days) {
    return 'SGR: $sgr %/day over $days days';
  }

  @override
  String get fullName => 'Full name';

  @override
  String get emailAlreadyRegistered =>
      'This email address is already registered.';

  @override
  String get activeInvitationExists =>
      'There is already an active invitation for this email address.';

  @override
  String get invalidRole => 'Invalid role.';

  @override
  String get inviteServiceUnavailable =>
      'The invitation service is unavailable. Try again.';

  @override
  String get signInWithInvitedEmail =>
      'Sign in with the email address that received the invitation.';

  @override
  String get invitationGreeting => 'Hello!';

  @override
  String invitationGreetingNamed(String name) {
    return 'Hello $name!';
  }

  @override
  String invitationCopyBody(String email, String link) {
    return 'You are invited to Fjellfisk for Arctic Hardanger.\n\nOpen the link and register or sign in with this email address:\n$email\n\nLink:\n$link\n\nRegards\nArctic Hardanger';
  }

  @override
  String get startingApp => 'Starting Fjellfisk...';

  @override
  String get startupFailedTitle => 'Could not start the app';

  @override
  String get startupFailedMessage =>
      'Check your internet connection and try again. If the issue continues, contact an administrator.';

  @override
  String get checkingLogin => 'Checking sign-in...';

  @override
  String get checkingAccess => 'Checking access...';

  @override
  String get loginCheckFailedTitle => 'Could not check sign-in';

  @override
  String get loginCheckFailedMessage =>
      'The app could not contact the sign-in service. Try again.';

  @override
  String get accessDeniedTitle => 'No access';

  @override
  String get accessDeniedMessage =>
      'You do not have access to Fjellfisk. Contact an administrator.';

  @override
  String get roleCheckFailedTitle => 'Could not check access';

  @override
  String get roleCheckFailedMessage =>
      'The app could not read your user role. Contact an administrator if you recently received a user account or role.';

  @override
  String get userDisabledTitle => 'User is disabled';

  @override
  String get userDisabledDetail =>
      'Contact an administrator if you need access again.';

  @override
  String get excelSheetFacility => 'Facility';

  @override
  String get excelSheetTank => 'Tank';

  @override
  String get excelSheetSummary => 'Summary';

  @override
  String get excelSheetTankOverview => 'Tank overview';

  @override
  String get excelSheetRegistrations => 'Registrations';

  @override
  String get keyFigures => 'Key figures';

  @override
  String get productionReportTitle => 'Production report';

  @override
  String get filter => 'Filter';

  @override
  String get value => 'Value';

  @override
  String get registeredBiomassKg => 'Recorded biomass kg';

  @override
  String get latestAverageWeightGram => 'Latest average weight g';

  @override
  String get weightChangeGram => 'Weight change g';

  @override
  String get averageTemperatureLabel => 'Average temperature';

  @override
  String get minimumTemperatureLabel => 'Minimum temperature';

  @override
  String get maximumTemperatureLabel => 'Maximum temperature';

  @override
  String get facilityName => 'Facility name';

  @override
  String get sectionBuilding => 'Section/building';

  @override
  String get date => 'Date';

  @override
  String get feedKg => 'Feed kg';

  @override
  String get diaryPdfTitle => 'Fjellfisk Diary / Operations log';

  @override
  String get noDiaryEntriesForPeriod => 'No entries in the selected period.';

  @override
  String get dateMissing => 'Date missing';

  @override
  String get unknownUser => 'Unknown user';

  @override
  String get untitled => 'Untitled';

  @override
  String pageOf(int current, int total) {
    return 'Page $current of $total';
  }
}

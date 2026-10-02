import 'dart:js_interop';

@JS('window.fjellfiskSaving')
external set _pending(JSBoolean value);

@JS('window.fjellfiskLatestBuild')
external JSString? get _latestBuild;

@JS('window.fjellfiskRequestUpdate')
external void _requestUpdate();

int _pendingOperations = 0;

void setWebSavePending(bool pending) {
  _pendingOperations = pending
      ? _pendingOperations + 1
      : (_pendingOperations - 1).clamp(0, 100000);
  _pending = (_pendingOperations > 0).toJS;
}

String? webUpdateAvailableBuild() => _latestBuild?.toDart;

void requestWebUpdate() {
  if (webUpdateAvailableBuild() == null) return;
  _requestUpdate();
}

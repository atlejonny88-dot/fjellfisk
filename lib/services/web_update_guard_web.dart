import 'dart:js_interop';

@JS('window.fjellfiskSaving')
external set _pending(JSBoolean value);

int _pendingOperations = 0;

void setWebSavePending(bool pending) {
  _pendingOperations = pending
      ? _pendingOperations + 1
      : (_pendingOperations - 1).clamp(0, 100000);
  _pending = (_pendingOperations > 0).toJS;
}

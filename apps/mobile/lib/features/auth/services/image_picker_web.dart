// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';

Future<String?> pickImageAsDataUrl() async {
  final completer = Completer<String?>();
  final uploadInput = html.FileUploadInputElement()..accept = 'image/*';

  StreamSubscription? focusSub;
  StreamSubscription? changeSub;
  Timer? cancelTimer;

  void finish([String? result]) {
    focusSub?.cancel();
    changeSub?.cancel();
    cancelTimer?.cancel();
    if (!completer.isCompleted) {
      completer.complete(result);
    }
  }

  changeSub = uploadInput.onChange.listen((event) {
    cancelTimer?.cancel();
    final files = uploadInput.files;
    if (files != null && files.isNotEmpty) {
      final file = files[0];
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      reader.onLoadEnd.listen((_) {
        final result = reader.result;
        finish(result is String ? result : null);
      });
    } else {
      finish(null);
    }
  });

  // Handle user cancelling the file picker dialog
  focusSub = html.window.onFocus.listen((_) {
    // Delay briefly to allow onChange to fire first if a file was selected
    cancelTimer = Timer(const Duration(milliseconds: 600), () {
      if (!completer.isCompleted) {
        finish(null);
      }
    });
  });

  uploadInput.click();
  return completer.future;
}

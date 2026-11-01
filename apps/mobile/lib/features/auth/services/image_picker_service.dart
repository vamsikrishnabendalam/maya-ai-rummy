import 'image_picker_stub.dart'
    if (dart.library.html) 'image_picker_web.dart' as platform_picker;

class ImagePickerService {
  static Future<String?> pickCustomPhoto() async {
    return platform_picker.pickImageAsDataUrl();
  }
}

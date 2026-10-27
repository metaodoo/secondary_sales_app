import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:secondary_sales/core/services/media_storage_service.dart';
import 'package:secondary_sales/core/widgets/app_camera_capture_dialog.dart';

/// Takes the live photo an outlet GPS update needs, and returns it as base64,
/// or null when the user closed the camera.
///
/// Camera only, never the gallery: the photo shows the person was at the
/// outlet when its saved position was replaced. The server rejects a GPS
/// update without one.
Future<String?> captureOutletGpsPhoto(BuildContext context) async {
  final photo = await AppCameraCaptureDialog.capture(
    context,
    title: 'Outlet Photo',
    helperTip: 'Take a photo of the shop front or signboard',
  );
  if (photo == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Take a photo of the outlet to update its location.'),
        ),
      );
    }
    return null;
  }
  final saved = await MediaStorageService.persistPickedFile(
    photo,
    category: MediaCategory.outlets,
    customPrefix: 'gps_update',
  );
  final bytes = saved != null ? await saved.readAsBytes() : await photo.readAsBytes();
  return base64Encode(bytes);
}

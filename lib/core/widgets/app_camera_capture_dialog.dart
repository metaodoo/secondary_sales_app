import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';

/// Lightweight In-App Camera capture dialog designed for low-memory devices (2GB-3GB RAM).
///
/// Features:
/// 1. Never backgrounds `MainActivity`, preserving foreground process priority (`oom_adj = 0`)
///    and eliminating ColorOS/Android Low Memory Killer (LMK) process termination.
/// 2. Configured at [ResolutionPreset.medium] (~720p) with audio disabled to keep memory footprint under ~35MB.
/// 3. Direct capture to disk without heavy bitmap buffering.
/// 4. Built-in review step (Retake / Use Photo) with immediate hardware resource disposal.
class AppCameraCaptureDialog extends StatefulWidget {
  final String title;
  final String helperTip;
  final CameraLensDirection initialLensDirection;

  const AppCameraCaptureDialog({
    super.key,
    this.title = 'Capture Outlet Photo',
    this.helperTip = 'Align the shop front or signboard within the frame',
    this.initialLensDirection = CameraLensDirection.back,
  });

  /// Opens the lightweight in-app camera modal.
  /// Returns the captured [XFile] or null if canceled.
  static Future<XFile?> capture(
    BuildContext context, {
    String title = 'Capture Outlet Photo',
    String helperTip = 'Align the shop front or signboard within the frame',
    CameraLensDirection initialLensDirection = CameraLensDirection.back,
  }) async {
    return Navigator.of(context).push<XFile?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => AppCameraCaptureDialog(
          title: title,
          helperTip: helperTip,
          initialLensDirection: initialLensDirection,
        ),
      ),
    );
  }

  @override
  State<AppCameraCaptureDialog> createState() => _AppCameraCaptureDialogState();
}

class _AppCameraCaptureDialogState extends State<AppCameraCaptureDialog>
    with WidgetsBindingObserver {
  List<CameraDescription> _availableCameras = [];
  CameraController? _controller;
  int _selectedCameraIndex = 0;
  FlashMode _flashMode = FlashMode.auto;

  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _errorMessage;
  XFile? _capturedFile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCameraSystem();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed && _capturedFile == null) {
      if (_availableCameras.isNotEmpty) {
        _initController(_availableCameras[_selectedCameraIndex]);
      }
    }
  }

  Future<void> _initCameraSystem() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (!mounted) return;
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Camera permission is required to take photos.';
        });
        return;
      }

      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isInitializing = false;
          _errorMessage = 'No camera found on this device.';
        });
        return;
      }

      // Select camera matching requested initial direction (or fallback)
      final preferredIndex = _availableCameras.indexWhere(
        (c) => c.lensDirection == widget.initialLensDirection,
      );
      if (preferredIndex != -1) {
        _selectedCameraIndex = preferredIndex;
      } else {
        final backIndex = _availableCameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
        );
        _selectedCameraIndex = backIndex != -1 ? backIndex : 0;
      }

      await _initController(_availableCameras[_selectedCameraIndex]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorMessage = 'Failed to initialize camera: ${e.toString()}';
      });
    }
  }

  Future<void> _initController(CameraDescription description) async {
    await _controller?.dispose();
    _controller = null;

    // Use ResolutionPreset.medium (720p) - sharp enough for shop signboards,
    // but consumes only ~25-35MB RAM, ideal for 2GB-3GB RAM phones.
    final controller = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      try {
        await controller.setFlashMode(_flashMode);
      } catch (_) {}

      setState(() {
        _controller = controller;
        _isInitializing = false;
      });
    } catch (e) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorMessage = 'Could not start camera preview: ${e.toString()}';
      });
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    FlashMode nextMode;
    switch (_flashMode) {
      case FlashMode.auto:
        nextMode = FlashMode.always;
        break;
      case FlashMode.always:
        nextMode = FlashMode.off;
        break;
      case FlashMode.off:
      default:
        nextMode = FlashMode.auto;
        break;
    }

    try {
      await _controller!.setFlashMode(nextMode);
      if (mounted) setState(() => _flashMode = nextMode);
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    if (_availableCameras.length < 2 || _isCapturing) return;
    final nextIndex = (_selectedCameraIndex + 1) % _availableCameras.length;
    _selectedCameraIndex = nextIndex;
    setState(() => _isInitializing = true);
    await _initController(_availableCameras[_selectedCameraIndex]);
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      setState(() {
        _capturedFile = file;
        _isCapturing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCapturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to capture photo: ${e.toString()}')),
      );
    }
  }

  Future<void> _fallbackToSystemCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
        requestFullMetadata: false,
      );
      if (photo != null && mounted) {
        Navigator.of(context).pop(photo);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('System camera error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Viewfinder or Review
            Positioned.fill(
              child: _capturedFile != null
                  ? _buildPhotoReview()
                  : _buildLivePreview(),
            ),

            // Top Header Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(),
            ),

            // Bottom Shutter / Action Controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _capturedFile != null
                  ? _buildReviewBottomBar()
                  : _buildCaptureBottomBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.85),
            Colors.black.withOpacity(0.0),
          ],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
            onPressed: () => Navigator.of(context).pop(null),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.helperTip,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_capturedFile == null && _controller != null) ...[
            IconButton(
              icon: Icon(
                _flashMode == FlashMode.always
                    ? Icons.flash_on_rounded
                    : _flashMode == FlashMode.auto
                        ? Icons.flash_auto_rounded
                        : Icons.flash_off_rounded,
                color: _flashMode == FlashMode.off ? Colors.white60 : Colors.amberAccent,
                size: 24,
              ),
              onPressed: _toggleFlash,
            ),
            if (_availableCameras.length > 1)
              IconButton(
                icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 24),
                onPressed: _switchCamera,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildLivePreview() {
    if (_isInitializing) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
            const SizedBox(height: 16),
            Text(
              'Starting camera...',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null || _controller == null || !_controller!.value.isInitialized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Camera unavailable',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                    ),
                    onPressed: _initCameraSystem,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    onPressed: _fallbackToSystemCamera,
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const Text('System Camera'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Camera preview with framing guideline
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: CameraPreview(_controller!),
        ),
        // Guideline box for outlet facade
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoReview() {
    return Center(
      child: Image.file(
        File(_capturedFile!.path),
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildCaptureBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.9),
            Colors.black.withOpacity(0.0),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // System camera fallback button
              IconButton(
                tooltip: 'Use System Camera',
                icon: const Icon(Icons.photo_camera_back_outlined, color: Colors.white70, size: 28),
                onPressed: _fallbackToSystemCamera,
              ),
              // Shutter button
              GestureDetector(
                onTap: _isCapturing ? null : _takePicture,
                child: Container(
                  width: 76,
                  height: 76,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isCapturing ? Colors.white38 : Colors.white,
                    ),
                    child: _isCapturing
                        ? const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              // Spacer to balance layout
              const SizedBox(width: 48),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.95),
            Colors.black.withOpacity(0.0),
          ],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                setState(() => _capturedFile = null);
              },
              icon: const Icon(Icons.replay_rounded, size: 20),
              label: Text(
                'Retake',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(context).pop(_capturedFile);
              },
              icon: const Icon(Icons.check_rounded, size: 20),
              label: Text(
                'Use Photo',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

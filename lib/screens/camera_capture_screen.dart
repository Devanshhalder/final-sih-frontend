import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({
    super.key,
    required this.guideText,
    this.title = 'Camera',
  });

  final String guideText;
  final String title;

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  Future<void>? _initializeFuture;
  XFile? _capturedImage;
  bool _capturing = false;
  bool _shutterFlash = false;
  FlashMode _flashMode = FlashMode.off;

  late final AnimationController _previewAnimationController =
      AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) _showError('No camera was found on this device.');
        return;
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      _controller = controller;
      _initializeFuture = controller.initialize();
      await _initializeFuture;
      if (!mounted) return;

      await controller.setFlashMode(_flashMode);
      setState(() {});
    } on CameraException catch (e) {
      if (mounted) _showError(_cameraErrorMessage(e));
    } catch (_) {
      if (mounted) {
        _showError('The camera could not be opened. Please try again.');
      }
    }
  }

  String _cameraErrorMessage(CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
        return 'Camera permission was denied. Allow camera access in Settings and try again.';
      case 'CameraAccessRestricted':
        return 'Camera access is restricted on this device.';
      case 'CameraAccessDeniedWithoutPrompt':
        return 'Camera permission is unavailable. Allow camera access in Settings.';
      default:
        return 'The camera could not be opened. Please try again.';
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final next = switch (_flashMode) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      FlashMode.always => FlashMode.off,
      _ => FlashMode.off,
    };

    try {
      await controller.setFlashMode(next);
      if (mounted) setState(() => _flashMode = next);
    } catch (_) {}
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (_capturing ||
        _capturedImage != null ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    setState(() {
      _capturing = true;
      _shutterFlash = true;
    });

    Future<void>.delayed(const Duration(milliseconds: 90), () {
      if (mounted) setState(() => _shutterFlash = false);
    });

    try {
      final image = await controller.takePicture();
      if (!mounted) return;

      setState(() {
        _capturedImage = image;
        _capturing = false;
      });
      _previewAnimationController.forward(from: 0);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _shutterFlash = false;
      });
      _showError(_cameraErrorMessage(e));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _shutterFlash = false;
      });
      _showError('The photo could not be captured. Please try again.');
    }
  }

  void _retake() {
    if (_capturing) return;
    setState(() => _capturedImage = null);
    _previewAnimationController.reverse();
  }

  void _usePhoto() {
    final image = _capturedImage;
    if (image == null || _capturing) return;
    Navigator.of(context).pop(image);
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _previewAnimationController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final initialized = controller != null && controller.value.isInitialized;
    final showingPreview = _capturedImage != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: showingPreview
                    ? _CapturePreview(
                        key: const ValueKey('capture-preview'),
                        image: _capturedImage!,
                        animation: _previewAnimationController,
                      )
                    : initialized
                        ? _LiveCamera(
                            key: const ValueKey('live-camera'),
                            controller: controller,
                          )
                        : const Center(
                            key: ValueKey('camera-loading'),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.4,
                            ),
                          ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: showingPreview ? 0 : 1,
                  duration: const Duration(milliseconds: 180),
                  child: CustomPaint(painter: _CameraGuidePainter()),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 14,
              right: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CircleButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  if (!showingPreview)
                    _CircleButton(
                      icon: _flashIcon,
                      onTap: _toggleFlash,
                    )
                  else
                    const SizedBox(width: 46, height: 46),
                ],
              ),
            ),
            if (!showingPreview)
              Positioned(
                left: 28,
                right: 28,
                bottom: 30,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(.48),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.guideText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _capture,
                      child: AnimatedScale(
                        scale: _capturing ? .90 : 1,
                        duration: const Duration(milliseconds: 110),
                        child: Container(
                          width: 78,
                          height: 78,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(.95),
                            border: Border.all(
                              color: AppColors.saffron,
                              width: 3,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _capturing
                                  ? AppColors.clay
                                  : AppColors.forest,
                            ),
                            child: _capturing
                                ? const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: 27,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Positioned(
                left: 22,
                right: 22,
                bottom: 24,
                child: Row(
                  children: [
                    Expanded(
                      child: _PreviewButton(
                        label: 'Retake',
                        icon: Icons.refresh_rounded,
                        onTap: _retake,
                        filled: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PreviewButton(
                        label: 'Use Photo',
                        icon: Icons.check_rounded,
                        onTap: _usePhoto,
                        filled: true,
                      ),
                    ),
                  ],
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _shutterFlash ? 1 : 0,
                  duration: const Duration(milliseconds: 70),
                  child: Container(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _flashIcon {
    switch (_flashMode) {
      case FlashMode.auto:
        return Icons.flash_auto_rounded;
      case FlashMode.always:
        return Icons.flash_on_rounded;
      case FlashMode.off:
      default:
        return Icons.flash_off_rounded;
    }
  }
}

class _LiveCamera extends StatelessWidget {
  const _LiveCamera({super.key, required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final sensorAspectRatio = controller.value.aspectRatio;

    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRect(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = width / sensorAspectRatio;
              return FittedBox(
                fit: BoxFit.cover,
                alignment: Alignment.center,
                child: SizedBox(
                  width: width,
                  height: height,
                  child: CameraPreview(controller),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CapturePreview extends StatelessWidget {
  const _CapturePreview({
    super.key,
    required this.image,
    required this.animation,
  });

  final XFile image;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final scale = .94 + (animation.value * .06);
        return Center(
          child: Opacity(
            opacity: animation.value,
            child: Transform.scale(
              scale: scale,
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipRect(
                  child: Image.file(
                    File(image.path),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CameraGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final squareSize = size.width * .84;
    final left = (size.width - squareSize) / 2;
    final top = (size.height - squareSize) / 2;
    final rect = Rect.fromLTWH(left, top, squareSize, squareSize);

    final dimPaint = Paint()
      ..color = Colors.black.withOpacity(.28)
      ..style = PaintingStyle.fill;
    final path = Path()..addRect(Offset.zero & size);
    final hole = Path()
      ..addRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(22)),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, path, hole),
      dimPaint,
    );

    final guidePaint = Paint()
      ..color = Colors.white.withOpacity(.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(22)),
      guidePaint,
    );

    const cornerLength = 24.0;
    final cornerPaint = Paint()
      ..color = AppColors.saffron
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final x = rect.left;
    final y = rect.top;
    final r = rect.right;
    final b = rect.bottom;

    canvas.drawLine(Offset(x, y + cornerLength), Offset(x, y), cornerPaint);
    canvas.drawLine(Offset(x, y), Offset(x + cornerLength, y), cornerPaint);
    canvas.drawLine(Offset(r - cornerLength, y), Offset(r, y), cornerPaint);
    canvas.drawLine(Offset(r, y), Offset(r, y + cornerLength), cornerPaint);
    canvas.drawLine(Offset(x, b - cornerLength), Offset(x, b), cornerPaint);
    canvas.drawLine(Offset(x, b), Offset(x + cornerLength, b), cornerPaint);
    canvas.drawLine(Offset(r - cornerLength, b), Offset(r, b), cornerPaint);
    canvas.drawLine(Offset(r, b - cornerLength), Offset(r, b), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _CameraGuidePainter oldDelegate) => false;
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _PreviewButton extends StatelessWidget {
  const _PreviewButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.filled,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Material(
        color: filled ? AppColors.forest : Colors.black.withOpacity(.48),
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: filled
                    ? Colors.transparent
                    : Colors.white.withOpacity(.38),
              ),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 19),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

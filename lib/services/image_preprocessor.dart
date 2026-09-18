import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

enum ImagePreparationCode {
  fileMissing,
  unsupportedImage,
  imageTooLarge,
  imageTooSmall,
  imageTooDark,
  imageTooBright,
  imageBlurry,
  preparationFailed,
}

class ImagePreparationException implements Exception {
  const ImagePreparationException(this.code, this.details);

  final ImagePreparationCode code;
  final String details;

  @override
  String toString() => 'ImagePreparationException($code): $details';
}

class PreparedImage {
  const PreparedImage({
    required this.path,
    required this.width,
    required this.height,
    required this.bytes,
  });

  final String path;
  final int width;
  final int height;
  final int bytes;
}

/// Prepares a product image for the AI Studio pipeline.
///
/// The input is first compressed safely, then normalized to a square canvas,
/// lightly corrected for exposure/contrast/shadows and flattened onto white
/// when the source contains transparency. Background *segmentation* itself
/// remains an AI operation performed by the existing enhancement backend.
class ImagePreprocessor {
  ImagePreprocessor._();

  static const int _maxDimension = 2048;
  static const int _minDimension = 320;
  static const int _maxUploadBytes = 4 * 1024 * 1024;
  static const int _absoluteInputLimit = 100 * 1024 * 1024;

  static Future<PreparedImage> prepare(String sourcePath) async {
    final source = File(sourcePath);

    if (!await source.exists()) {
      throw const ImagePreparationException(
        ImagePreparationCode.fileMissing,
        'The selected image file does not exist.',
      );
    }

    final sourceLength = await source.length();
    if (sourceLength <= 0) {
      throw const ImagePreparationException(
        ImagePreparationCode.fileMissing,
        'The selected image file is empty.',
      );
    }

    if (sourceLength > _absoluteInputLimit) {
      throw const ImagePreparationException(
        ImagePreparationCode.imageTooLarge,
        'The source image is too large to safely process on this device.',
      );
    }

    final documents = await getApplicationDocumentsDirectory();
    final jobsDirectory = Directory('${documents.path}/karigarkart_ai');
    await jobsDirectory.create(recursive: true);

    final id = DateTime.now().microsecondsSinceEpoch;
    final output = File('${jobsDirectory.path}/input_$id.jpg');

    XFile? compressed;

    const attempts = <({int dimension, int quality})>[
      (dimension: 2048, quality: 84),
      (dimension: 1792, quality: 78),
      (dimension: 1536, quality: 72),
      (dimension: 1280, quality: 66),
    ];

    try {
      for (final attempt in attempts) {
        final candidate =
            '${output.path}.${attempt.dimension}.${attempt.quality}.jpg';

        try {
          compressed = await FlutterImageCompress.compressAndGetFile(
            source.absolute.path,
            candidate,
            minWidth: attempt.dimension,
            minHeight: attempt.dimension,
            quality: attempt.quality,
            format: CompressFormat.jpeg,
            autoCorrectionAngle: true,
            keepExif: false,
          );
        } catch (_) {
          compressed = null;
        }

        if (compressed == null) continue;

        final candidateFile = File(compressed!.path);
        if (!await candidateFile.exists()) continue;
        if (await candidateFile.length() > _maxUploadBytes) continue;

        await _applyStudioProcessing(candidateFile, output);
        await _validatePreparedFile(output);
        await _deleteIfExists(candidateFile);
        return await _readPrepared(output);
      }
    } on ImagePreparationException {
      rethrow;
    } catch (_) {
      // Fall through to the Dart decoder below.
    }

    try {
      final decoded = await img.decodeImageFile(source.absolute.path);
      if (decoded == null) {
        throw const ImagePreparationException(
          ImagePreparationCode.unsupportedImage,
          'No decoder could read the selected image.',
        );
      }

      final resized = _resizeForStudio(decoded);
      final temporary = File('${output.path}.decoded.jpg');
      await temporary.writeAsBytes(
        img.encodeJpg(resized, quality: 82),
        flush: true,
      );

      await _applyStudioProcessing(temporary, output);
      await _deleteIfExists(temporary);
      await _validatePreparedFile(output);

      if (await output.length() > _maxUploadBytes) {
        final decodedOutput = await img.decodeImageFile(output.path);
        if (decodedOutput == null) {
          throw const ImagePreparationException(
            ImagePreparationCode.preparationFailed,
            'The prepared image could not be decoded.',
          );
        }

        final smaller = img.copyResize(
          decodedOutput,
          width: 1280,
          height: 1280,
          maintainAspect: false,
          interpolation: img.Interpolation.average,
        );
        await output.writeAsBytes(
          img.encodeJpg(smaller, quality: 72),
          flush: true,
        );
        await _validatePreparedFile(output);
      }

      return await _readPrepared(output);
    } on ImagePreparationException {
      rethrow;
    } catch (e) {
      throw ImagePreparationException(
        ImagePreparationCode.preparationFailed,
        e.toString(),
      );
    }
  }

  /// Applies the local, deterministic part of the AI Studio pipeline.
  ///
  /// This guarantees a square e-commerce canvas and consistent lighting even
  /// when the network AI service is unavailable. If the AI service returns a
  /// transparent cut-out later, the same white-background flattening logic can
  /// be applied to that output by calling [prepare] on it.
  static Future<void> _applyStudioProcessing(
    File source,
    File target,
  ) async {
    final decoded = await img.decodeImageFile(source.path);
    if (decoded == null) {
      throw const ImagePreparationException(
        ImagePreparationCode.unsupportedImage,
        'The image could not be decoded for studio processing.',
      );
    }

    final resized = _resizeForStudio(decoded);
    final side = math.min(resized.width, resized.height);
    final cropX = (resized.width - side) ~/ 2;
    final cropY = (resized.height - side) ~/ 2;
    final cropped = img.copyCrop(
      resized,
      x: cropX,
      y: cropY,
      width: side,
      height: side,
    );

    final output = img.Image(
      width: side,
      height: side,
      numChannels: 4,
    );

    for (int y = 0; y < side; y++) {
      for (int x = 0; x < side; x++) {
        final pixel = cropped.getPixel(x, y);
        final alpha = pixel.a.toDouble().clamp(0.0, 255.0);
        final red = pixel.r.toDouble();
        final green = pixel.g.toDouble();
        final blue = pixel.b.toDouble();

        final luminance =
            (0.2126 * red + 0.7152 * green + 0.0722 * blue) / 255.0;

        // Gentle e-commerce correction: lift shadows, add a small amount of
        // contrast and recover a little brightness without changing the app's
        // visual identity or aggressively recolouring textiles.
        final shadowLift = (1.0 - (luminance / 0.42)).clamp(0.0, 1.0) * 10.0;

        double correct(double value) {
          var v = ((value - 128.0) * 1.055) + 128.0;
          v = (v * 1.025) + shadowLift;
          return v.clamp(0.0, 255.0);
        }

        final correctedR = correct(red);
        final correctedG = correct(green);
        final correctedB = correct(blue);

        // Flatten transparent pixels onto studio white. Opaque pixels are
        // preserved, so this is harmless for ordinary JPEG camera captures.
        final a = alpha / 255.0;
        final outR = (correctedR * a) + (255.0 * (1.0 - a));
        final outG = (correctedG * a) + (255.0 * (1.0 - a));
        final outB = (correctedB * a) + (255.0 * (1.0 - a));

        output.setPixelRgba(
          x,
          y,
          outR.round().clamp(0, 255),
          outG.round().clamp(0, 255),
          outB.round().clamp(0, 255),
          255,
        );
      }
    }

    await target.writeAsBytes(
      img.encodeJpg(output, quality: 88),
      flush: true,
    );
  }

  static img.Image _resizeForStudio(img.Image image) {
    if (image.width <= _maxDimension && image.height <= _maxDimension) {
      return image;
    }

    return img.copyResize(
      image,
      width: image.width >= image.height ? _maxDimension : null,
      height: image.height > image.width ? _maxDimension : null,
      maintainAspect: true,
      interpolation: img.Interpolation.average,
    );
  }

  static Future<void> _validatePreparedFile(File file) async {
    final decoded = await img.decodeImageFile(file.path);
    if (decoded == null) {
      throw const ImagePreparationException(
        ImagePreparationCode.unsupportedImage,
        'The prepared image could not be decoded.',
      );
    }

    if (decoded.width != decoded.height) {
      throw const ImagePreparationException(
        ImagePreparationCode.preparationFailed,
        'The prepared product image is not square.',
      );
    }

    if (decoded.width < _minDimension || decoded.height < _minDimension) {
      throw const ImagePreparationException(
        ImagePreparationCode.imageTooSmall,
        'The image resolution is too low for reliable product enhancement.',
      );
    }

    final metrics = _qualityMetrics(decoded);

    if (metrics.meanLuminance < 0.055) {
      throw const ImagePreparationException(
        ImagePreparationCode.imageTooDark,
        'The image is too dark for reliable subject detection.',
      );
    }

    if (metrics.meanLuminance > 0.995) {
      throw const ImagePreparationException(
        ImagePreparationCode.imageTooBright,
        'The image is overexposed.',
      );
    }

    if (metrics.edgeEnergy < 1.25 && metrics.luminanceStdDev < 7.0) {
      throw const ImagePreparationException(
        ImagePreparationCode.imageBlurry,
        'The image has very little usable detail.',
      );
    }
  }

  static _QualityMetrics _qualityMetrics(img.Image image) {
    const int targetSamples = 48;
    final int stepX =
        (image.width / targetSamples).ceil().clamp(1, image.width).toInt();
    final int stepY =
        (image.height / targetSamples).ceil().clamp(1, image.height).toInt();

    double sum = 0;
    double sumSquared = 0;
    double edgeSum = 0;
    int count = 0;
    int edgeCount = 0;

    for (int y = 0; y < image.height; y += stepY) {
      for (int x = 0; x < image.width; x += stepX) {
        final pixel = image.getPixel(x, y);
        final luminance = pixel.luminance.toDouble();
        sum += luminance;
        sumSquared += luminance * luminance;
        count++;

        if (x + stepX < image.width) {
          final right = image.getPixel(x + stepX, y);
          edgeSum += (luminance - right.luminance).abs();
          edgeCount++;
        }

        if (y + stepY < image.height) {
          final down = image.getPixel(x, y + stepY);
          edgeSum += (luminance - down.luminance).abs();
          edgeCount++;
        }
      }
    }

    if (count == 0) {
      return const _QualityMetrics(
        meanLuminance: 0,
        luminanceStdDev: 0,
        edgeEnergy: 0,
      );
    }

    final mean = sum / count;
    final variance = (sumSquared / count) - (mean * mean);

    return _QualityMetrics(
      meanLuminance: (mean / 255).clamp(0.0, 1.0),
      luminanceStdDev: variance <= 0 ? 0 : math.sqrt(variance),
      edgeEnergy: edgeCount == 0 ? 0 : edgeSum / edgeCount,
    );
  }

  static Future<void> _deleteIfExists(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  static Future<PreparedImage> _readPrepared(File file) async {
    final decoded = await img.decodeImageFile(file.path);
    if (decoded == null) {
      throw const ImagePreparationException(
        ImagePreparationCode.preparationFailed,
        'The prepared image could not be read back.',
      );
    }

    return PreparedImage(
      path: file.path,
      width: decoded.width,
      height: decoded.height,
      bytes: await file.length(),
    );
  }
}

class _QualityMetrics {
  const _QualityMetrics({
    required this.meanLuminance,
    required this.luminanceStdDev,
    required this.edgeEnergy,
  });

  final double meanLuminance;
  final double luminanceStdDev;
  final double edgeEnergy;
}

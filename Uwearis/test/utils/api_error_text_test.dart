import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/core/services/api_exception.dart';
import 'package:uwearis/core/utils/api_error_text.dart';
import 'package:uwearis/l10n/generated/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('apiErrorMessage', () {
    test('falls back to the caller-supplied message for a non-ApiException '
        'error (timeout, malformed-response check, ...)', () {
      final message = apiErrorMessage(
        l10n,
        Exception('some internal detail'),
        fallback: l10n.garmentSaveFailed,
      );
      expect(message, l10n.garmentSaveFailed);
    });

    test('falls back to the caller-supplied message for an ApiException '
        'with no error_code', () {
      const error = ApiException(statusCode: 500, message: 'boom');
      final message = apiErrorMessage(l10n, error, fallback: l10n.garmentSaveFailed);
      expect(message, l10n.garmentSaveFailed);
    });

    test('falls back to the caller-supplied message for an ApiException '
        'whose error_code has no shared mapping yet', () {
      const error = ApiException(
        statusCode: 404,
        errorCode: 'SOME_FEATURE_SPECIFIC_CODE',
        message: 'boom',
      );
      final message = apiErrorMessage(l10n, error, fallback: l10n.garmentSaveFailed);
      expect(message, l10n.garmentSaveFailed);
    });

    test('never returns the backend-provided message field', () {
      const error = ApiException(
        statusCode: 500,
        message: 'Internal traceback: NullPointerException at line 42',
      );
      final message = apiErrorMessage(l10n, error, fallback: l10n.garmentSaveFailed);
      expect(message, isNot(contains('traceback')));
      expect(message, isNot(contains('NullPointerException')));
    });

    test('maps FACE_REFERENCE_NOT_FOUND to its shared message, regardless '
        'of the caller-supplied fallback', () {
      const error = ApiException(
        statusCode: 404,
        errorCode: 'FACE_REFERENCE_NOT_FOUND',
        message: 'face reference object missing',
      );
      final message = apiErrorMessage(l10n, error, fallback: l10n.failedToGenerateOutfit);
      expect(message, l10n.facePhotoNotFound);
    });

    test('maps BODY_REFERENCE_NOT_FOUND to its shared message', () {
      const error = ApiException(
        statusCode: 404,
        errorCode: 'BODY_REFERENCE_NOT_FOUND',
        message: 'body reference object missing',
      );
      final message = apiErrorMessage(l10n, error, fallback: l10n.failedToGenerateOutfit);
      expect(message, l10n.fullBodyPhotoNotFound);
    });

    test('maps FILE_NOT_FOUND to a generic, GCS-agnostic message', () {
      const error = ApiException(
        statusCode: 404,
        errorCode: 'FILE_NOT_FOUND',
        message: 'gs://uwearis-bucket/objects/abc123.jpg not found',
      );
      final message = apiErrorMessage(l10n, error, fallback: l10n.garmentSaveFailed);
      expect(message, l10n.fileNotFound);
      expect(message, isNot(contains('gs://')));
      expect(message, isNot(contains('bucket')));
    });

    test('OBJECT_NAME_REQUIRED is deliberately not mapped yet — falls back',
        () {
      const error = ApiException(
        statusCode: 400,
        errorCode: 'OBJECT_NAME_REQUIRED',
        message: 'object_name is required',
      );
      final message = apiErrorMessage(l10n, error, fallback: l10n.garmentSaveFailed);
      expect(message, l10n.garmentSaveFailed);
    });

    test('OUTFIT_COPY_FAILED is deliberately not mapped yet — the copy flow '
        'keeps using its own fallback', () {
      const error = ApiException(
        statusCode: 500,
        errorCode: 'OUTFIT_COPY_FAILED',
        message: 'copy failed',
      );
      final message = apiErrorMessage(l10n, error, fallback: l10n.outfitCopyFailed);
      expect(message, l10n.outfitCopyFailed);
    });
  });
}

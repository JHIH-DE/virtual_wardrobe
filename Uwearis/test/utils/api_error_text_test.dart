import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
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
      const error = ApiException(statusCode: 400, message: 'boom');
      final message = apiErrorMessage(
        l10n,
        error,
        fallback: l10n.garmentSaveFailed,
      );
      expect(message, l10n.garmentSaveFailed);
    });

    test('falls back to the caller-supplied message for an ApiException '
        'whose error_code has no shared mapping yet', () {
      const error = ApiException(
        statusCode: 404,
        errorCode: 'SOME_FEATURE_SPECIFIC_CODE',
        message: 'boom',
      );
      final message = apiErrorMessage(
        l10n,
        error,
        fallback: l10n.garmentSaveFailed,
      );
      expect(message, l10n.garmentSaveFailed);
    });

    test('never returns the backend-provided message field', () {
      const error = ApiException(
        statusCode: 500,
        message: 'Internal traceback: NullPointerException at line 42',
      );
      final message = apiErrorMessage(
        l10n,
        error,
        fallback: l10n.garmentSaveFailed,
      );
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
      final message = apiErrorMessage(
        l10n,
        error,
        fallback: l10n.failedToGenerateOutfit,
      );
      expect(message, l10n.facePhotoNotFound);
    });

    test('maps BODY_REFERENCE_NOT_FOUND to its shared message', () {
      const error = ApiException(
        statusCode: 404,
        errorCode: 'BODY_REFERENCE_NOT_FOUND',
        message: 'body reference object missing',
      );
      final message = apiErrorMessage(
        l10n,
        error,
        fallback: l10n.failedToGenerateOutfit,
      );
      expect(message, l10n.fullBodyPhotoNotFound);
    });

    test('maps FILE_NOT_FOUND to a generic, GCS-agnostic message', () {
      const error = ApiException(
        statusCode: 404,
        errorCode: 'FILE_NOT_FOUND',
        message: 'gs://uwearis-bucket/objects/abc123.jpg not found',
      );
      final message = apiErrorMessage(
        l10n,
        error,
        fallback: l10n.garmentSaveFailed,
      );
      expect(message, l10n.fileNotFound);
      expect(message, isNot(contains('gs://')));
      expect(message, isNot(contains('bucket')));
    });

    test(
      'OBJECT_NAME_REQUIRED is deliberately not mapped yet — falls back',
      () {
        const error = ApiException(
          statusCode: 400,
          errorCode: 'OBJECT_NAME_REQUIRED',
          message: 'object_name is required',
        );
        final message = apiErrorMessage(
          l10n,
          error,
          fallback: l10n.garmentSaveFailed,
        );
        expect(message, l10n.garmentSaveFailed);
      },
    );
  });

  group('apiErrorMessage failure classes', () {
    String msg(Object e) =>
        apiErrorMessage(l10n, e, fallback: l10n.garmentSaveFailed);

    test('daily try-on limit names the local reset time', () {
      const error = ApiException(
        statusCode: 429,
        errorCode: 'DAILY_GENERATION_LIMIT_EXCEEDED',
        message: 'limit',
      );
      final reset = nextGenerationQuotaReset(DateTime.now());
      final hhmm =
          '${reset.hour.toString().padLeft(2, '0')}:'
          '${reset.minute.toString().padLeft(2, '0')}';
      expect(msg(error), l10n.dailyGenerationLimitReached(hhmm));
    });

    test('any other 429 is a rate limit', () {
      expect(
        msg(const ApiException(statusCode: 429, message: 'x')),
        l10n.errorTooManyRequests,
      );
    });

    test('5xx and timeouts keep the action-specific fallback', () {
      expect(
        msg(const ApiException(statusCode: 503, message: 'x')),
        l10n.garmentSaveFailed,
      );
      expect(msg(TimeoutException('slow')), l10n.garmentSaveFailed);
    });

    test('socket and client failures read as no connection', () {
      expect(msg(const SocketException('down')), l10n.errorNoConnection);
      expect(msg(http.ClientException('reset')), l10n.errorNoConnection);
    });

    test('a 4xx without a known code keeps the action-specific fallback', () {
      expect(
        msg(const ApiException(statusCode: 422, message: 'x')),
        l10n.garmentSaveFailed,
      );
    });
  });

  group('nextGenerationQuotaReset', () {
    test('is the next 00:00 Taipei (16:00 UTC)', () {
      final reset = nextGenerationQuotaReset(DateTime.utc(2026, 10, 28, 3));
      expect(reset.toUtc(), DateTime.utc(2026, 10, 28, 16));
    });

    test('rolls to the following day once Taipei has passed midnight', () {
      final reset = nextGenerationQuotaReset(DateTime.utc(2026, 10, 28, 16, 1));
      expect(reset.toUtc(), DateTime.utc(2026, 10, 29, 16));
    });

    test('handles month ends', () {
      final reset = nextGenerationQuotaReset(DateTime.utc(2026, 12, 31, 17));
      expect(reset.toUtc(), DateTime.utc(2027, 1, 1, 16));
    });
  });
}

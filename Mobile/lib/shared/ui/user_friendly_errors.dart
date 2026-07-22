import 'dart:io';

import 'package:dio/dio.dart';

/// Turns technical failures into short copy for end users.
String userFriendlyDataLoadMessage(Object error) {
  final s = error.toString();

  if (s.contains('Missing auth token')) {
    return 'Please sign in again to continue.';
  }
  if (s.contains('No internet connection and no cached dashboard')) {
    return 'Connect to the internet once to load your dashboard. '
        'After that, your last sync stays available offline.';
  }
  if (s.contains('No internet connection and no cached activity')) {
    return 'Connect once while online to load charts and goals from the server. '
        'Your phone still counts steps in the background.';
  }

  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The connection timed out. Check your signal and try again.';
      case DioExceptionType.connectionError:
        return 'Could not reach the server. Check Wi‑Fi or mobile data, '
            'and confirm your clinic/backend address is correct.';
      default:
        break;
    }
    final code = error.response?.statusCode;
    if (code == 401) {
      return 'Your session expired. Please sign in again.';
    }
    if (code != null && code >= 500) {
      return 'The server had a problem. Try again in a moment.';
    }
    if (code == 404) {
      return 'That feature is not available on the server yet. '
          'Deploy the latest backend, or switch the app to your local API.';
    }
  }

  if (error is SocketException) {
    return 'No internet connection. Try again when you are online.';
  }

  if (s.contains('Unexpected dashboard response') ||
      s.contains('Unexpected activity response')) {
    return 'We received an unexpected response from the server. Pull to retry.';
  }

  return 'Something went wrong. Check your connection and try again.';
}

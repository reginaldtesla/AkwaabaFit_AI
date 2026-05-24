import 'package:flutter/material.dart';

/// Global messenger so snackbars still show after login navigates away from [AuthScreen].
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

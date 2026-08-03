import 'package:exploding_kittens/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';

// Sin esto, cualquier MaterialApp/MaterialApp.router de un test explota
// apenas un widget llame AppLocalizations.of(context)! — cada test file
// que arma su propio MaterialApp le agrega estos tres parámetros.
//
// testLocale queda fijo en español (no el del SO del entorno de test) para
// que los `find.text('...')` existentes, escritos contra el string en
// español, sigan siendo deterministas.
const testLocale = Locale('es');
const testLocalizationsDelegates = AppLocalizations.localizationsDelegates;
const testSupportedLocales = AppLocalizations.supportedLocales;

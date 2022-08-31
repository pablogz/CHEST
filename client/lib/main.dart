import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:universal_io/io.dart';
import 'package:google_fonts/google_fonts.dart';

import 'managers/map.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  //Idioma app
  static String currentLang = "en";
  static final List<String> langs = ["es", "en"];

  @override
  Widget build(BuildContext context) {
    //Idioma de la aplicación
    String aux = Platform.localeName;
    if (aux.contains("_")) {
      aux = aux.split("_")[0];
    }
    if (langs.contains(aux)) {
      currentLang = aux;
    }
    return MaterialApp(
      title: 'CHEST',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const MyMap(),
      /*theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.red[100],
        textTheme: GoogleFonts.openSansTextTheme(),
        appBarTheme: AppBarTheme(
            color: Colors.red[900],
            iconTheme: const IconThemeData(color: Colors.white)),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.red[900],
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
        ),
      ),*/
      theme: ThemeData(
          useMaterial3: true,
          primarySwatch: Colors.red,
          textTheme: GoogleFonts.openSansTextTheme()),
      darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          textTheme: GoogleFonts.openSansTextTheme()),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
    );
  }
}

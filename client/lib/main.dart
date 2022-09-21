import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:mustache_template/mustache.dart';
import 'package:universal_io/io.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'helpers/auxiliar.dart';
import 'helpers/queries.dart';
import 'helpers/user.dart';
import 'main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseAuth.instance.setLanguageCode(MyApp.currentLang);
  if (FirebaseAuth.instance.currentUser != null &&
      FirebaseAuth.instance.currentUser!.emailVerified &&
      Auxiliar.userCHEST.rol == Rol.guest) {
    //Recupero la información del servidor
    await http.get(Queries().signIn(), headers: {
      'Authorization': Template('Bearer {{{token}}}').renderString(
          {'token': await FirebaseAuth.instance.currentUser!.getIdToken()})
    }).then((data) async {
      switch (data.statusCode) {
        case 200:
          Map<String, dynamic> j = json.decode(data.body);
          Auxiliar.userCHEST = UserCHEST(j["id"], j["rol"]);
          break;
        default:
          FirebaseAuth.instance.signOut();
      }
    }).onError((error, stackTrace) {
      FirebaseAuth.instance.signOut();
    });
  }
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
    } else {
      if (aux.contains("-")) {
        aux = aux.split("-")[0];
      }
    }
    if (langs.contains(aux)) {
      currentLang = aux;
    }

    return MaterialApp(
      title: 'CHEST',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const MyMap(),
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primarySwatch: Colors.red,
        fontFamily: GoogleFonts.openSans().fontFamily,
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.black,
          ),
        ),
        textTheme: Theme.of(context).textTheme.apply(
            fontFamily: GoogleFonts.openSans().fontFamily,
            fontSizeFactor: 1.1,
            fontSizeDelta: 1.5),
        appBarTheme: Theme.of(context).appBarTheme.copyWith(
            backgroundColor: Theme.of(context).primaryColorDark,
            foregroundColor: Colors.white,
            centerTitle: true),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primarySwatch: Colors.teal,
        textTheme: Theme.of(context).primaryTextTheme.apply(
            fontFamily: GoogleFonts.openSans().fontFamily,
            fontSizeFactor: 1.1,
            fontSizeDelta: 1.5),
      ),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
    );
  }
}

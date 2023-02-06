import 'dart:convert';

import 'package:chest/config.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:mustache_template/mustache.dart';
import 'package:universal_io/io.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_strategy/url_strategy.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:chest/helpers/auxiliar.dart';
import 'package:chest/helpers/queries.dart';
import 'package:chest/helpers/user.dart';
import 'package:chest/main_screen.dart';
import 'package:chest/more_info.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool conectado =
      await Connectivity().checkConnectivity() != ConnectivityResult.none;
  if (conectado) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
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
            if (j.keys.contains('firstname') && j['firstname'] != null) {
              Auxiliar.userCHEST.firstname = j['firstname'];
            }
            if (j.keys.contains('lastname') && j['lastname'] != null) {
              Auxiliar.userCHEST.lastname = j['lastname'];
            }
            if (Config.debug) {
              FirebaseAnalytics.instance.logLogin(loginMethod: "emailPass");
            }
            break;
          default:
            FirebaseAuth.instance.signOut();
        }
      }).onError((error, stackTrace) {
        FirebaseAuth.instance.signOut();
      });
    }
  }
  setPathUrlStrategy();
  runApp(MyApp(
    conectado: conectado,
  ));
}

class MyApp extends StatelessWidget {
  MyApp({Key? key, this.conectado}) : super(key: key);

  //Idioma app
  static String currentLang = "en";
  static final List<String> langs = ["es", "en"];
  final bool? conectado;

  final List<String> validPaths = [
    '/',
    '/pois/:poi',
    '/pois/:poi/tasks/:task',
    '/about',
    '/itineraries',
    '/itinieraries/:itinerary',
    '/answers',
    '/answers/:answer',
    '/login',
    '/login/forgotpass',
    '/login/newuser'
  ];

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
      // home: const MyMap(),
      initialRoute: '/',
      routes: {
        '/': (context) => conectado != null && conectado!
            ? const MyMap()
            : const SinConexion(),
        '/about': (context) => const MoreInfo(),
      },
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primarySwatch: Colors.deepPurple,
        fontFamily: GoogleFonts.openSans().fontFamily,
        // textButtonTheme: TextButtonThemeData(
        //   style: TextButton.styleFrom(
        //     foregroundColor: Colors.black,
        //   ),
        // ),
        textTheme: Theme.of(context).textTheme.apply(
            fontFamily: GoogleFonts.openSans().fontFamily,
            fontSizeFactor: 1.1,
            fontSizeDelta: 1.5),
        // appBarTheme: Theme.of(context).appBarTheme.copyWith(
        //       backgroundColor: Colors.deepOrange[700],
        //       foregroundColor: Colors.white,
        //       // centerTitle: true,
        //     ),
        // elevatedButtonTheme: ElevatedButtonThemeData(
        //   style: ElevatedButton.styleFrom(
        //     backgroundColor: Colors.deepPurple,
        //     foregroundColor: Colors.white,
        //     // minimumSize: const Size(48, 48),
        //   ),
        // ),
        // textButtonTheme: TextButtonThemeData(
        //   style: TextButton.styleFrom(
        //     minimumSize: const Size(48, 48),
        //   ),
        // ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        fontFamily: GoogleFonts.openSans().fontFamily,
        textTheme: Theme.of(context).primaryTextTheme.apply(
            fontFamily: GoogleFonts.openSans().fontFamily,
            fontSizeFactor: 1.1,
            fontSizeDelta: 1.5),
        // appBarTheme: Theme.of(context).appBarTheme.copyWith(centerTitle: true),
        // elevatedButtonTheme: ElevatedButtonThemeData(
        //   style: ElevatedButton.styleFrom(
        //     backgroundColor: Colors.teal,
        //     foregroundColor: Colors.white,
        //     // minimumSize: const Size(48, 48),
        //   ),
        // ),
        // textButtonTheme: TextButtonThemeData(
        //   style: TextButton.styleFrom(
        //     minimumSize: const Size(48, 48),
        //   ),
        // ),
      ),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
    );
  }
}

class SinConexion extends StatelessWidget {
  const SinConexion({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SelectableText(
          "Offline :(",
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ),
    );
  }
}

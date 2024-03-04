import 'dart:convert';

// import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:chest/users.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mustache_template/mustache.dart';
import 'package:universal_io/io.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:chest/features.dart';
import 'package:chest/tasks.dart';
import 'package:chest/util/firebase_options.dart';
import 'package:chest/util/auxiliar.dart';
import 'package:chest/util/helpers/queries.dart';
import 'package:chest/util/helpers/user.dart';
import 'package:chest/main_screen.dart';
import 'package:chest/more_info.dart';
import 'package:chest/util/config.dart';
import 'package:chest/util/color_schemes.g.dart';
import 'package:chest/landing_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // bool conectado =
  //     await Connectivity().checkConnectivity() != ConnectivityResult.none;
  // if (conectado) {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // if (FirebaseAuth.instance.currentUser != null &&
    //     FirebaseAuth.instance.currentUser!.emailVerified &&
    //     Auxiliar.userCHEST.rol == Rol.guest) {
    //   //Recupero la información del servidor
    //   await http.get(Queries().signIn(), headers: {
    //     'Authorization': Template('Bearer {{{token}}}').renderString(
    //         {'token': await FirebaseAuth.instance.currentUser!.getIdToken()})
    //   }).then((data) async {
    //     switch (data.statusCode) {
    //       case 200:
    //         Map<String, dynamic> j = json.decode(data.body);
    //         Auxiliar.userCHEST = UserCHEST(j["id"], j["rol"]);
    //         if (j.keys.contains('firstname') && j['firstname'] != null) {
    //           Auxiliar.userCHEST.firstname = j['firstname'];
    //         }
    //         if (j.keys.contains('lastname') && j['lastname'] != null) {
    //           Auxiliar.userCHEST.lastname = j['lastname'];
    //         }
    //         if (!Config.development) {
    //           await FirebaseAnalytics.instance
    //               .logLogin(loginMethod: "emailPass")
    //               .onError((error, stackTrace) => debugPrint(error.toString()));
    //         }
    //         break;
    //       default:
    //         FirebaseAuth.instance.signOut();
    //     }
    //   }).onError((error, stackTrace) {
    //     FirebaseAuth.instance.signOut();
    //   });
    // }
  } catch (e) {
    debugPrint(e.toString());
  }
  // setPathUrlStrategy();
  usePathUrlStrategy();
  // debugRepaintRainbowEnabled = true;
  // Permite que los context.push cambien la URL: https://github.com/flutter/flutter/issues/131083
  GoRouter.optionURLReflectsImperativeAPIs = true;
  runApp(const MyApp(conectado: true));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.conectado});

  //Idioma app
  static String currentLang = "en";
  static final List<String> langs = ["es", "en", "pt"];
  final bool? conectado;

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
    final GoRouter router = GoRouter(
      initialLocation: '/',
      // TODO RECUERDA QUE LAS RUTAS COMPARTEN EXTRA!!!
      // PUEDE QUE SEA MEJOR IDEA EN EL 0 METER UN MAPA Y BUSCAR POR CLAVE
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const LandingPage(),
        ),
        GoRoute(
            path: '/map',
            builder: (context, state) => MyMap(
                  center: state.uri.queryParameters['center'],
                  zoom: state.uri.queryParameters['zoom'],
                ),
            routes: [
              GoRoute(
                  path: 'features/:shortId',
                  builder: (context, state) {
                    if (state.extra != null && state.extra is List) {
                      List extra = state.extra as List;
                      return InfoFeature(
                        shortId: state.pathParameters['shortId'],
                        locationUser: extra[0],
                        iconMarker: extra[1],
                      );
                    } else {
                      return InfoFeature(
                        shortId: state.pathParameters['shortId'],
                      );
                    }
                  },
                  routes: [
                    GoRoute(
                        path: 'tasks/:taskId',
                        builder: (context, state) {
                          if (state.extra != null && state.extra is List) {
                            List extra = state.extra as List;
                            return COTask(
                              shortIdFeature: state.pathParameters['shortId']!,
                              shortIdTask: state.pathParameters['taskId']!,
                              answer: extra[2],
                              preview: extra[3],
                              userIsNear: extra[4],
                            );
                          } else {
                            return COTask(
                              shortIdFeature: state.pathParameters['shortId']!,
                              shortIdTask: state.pathParameters['taskId']!,
                            );
                          }
                        })
                  ]),
            ]),
        GoRoute(
          path: '/about',
          builder: (context, state) => const MoreInfo(),
        ),
        GoRoute(
            path: '/users/:idUser',
            builder: (context, state) => const InfoUser(),
            routes: [
              GoRoute(
                path: 'newUser',
                builder: (context, state) => const NewUser2(),
              ),
              GoRoute(
                path: 'deleteUser',
                builder: (context, state) => const MoreInfo(),
              ),
              GoRoute(
                path: 'editUser',
                builder: (context, state) => const MoreInfo(),
              ),
            ])
      ],
    );
    return MaterialApp.router(
      title: 'CHEST',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightColorScheme,
        fontFamily: GoogleFonts.openSans().fontFamily,
        textTheme: Theme.of(context).textTheme.apply(
              fontFamily: GoogleFonts.openSans().fontFamily,
              // fontSizeFactor: 1.1,
              // fontSizeDelta: 1.5,
              // bodyColor: Colors.black,
              // displayColor: Colors.black,
            ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkColorScheme,
        fontFamily: GoogleFonts.openSans().fontFamily,
        textTheme: Theme.of(context).primaryTextTheme.apply(
              fontFamily: GoogleFonts.openSans().fontFamily,
              // fontSizeFactor: 1.1,
              // fontSizeDelta: 1.5,
            ),
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

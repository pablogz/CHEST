import 'dart:math';

import 'package:chest/main.dart';
import 'package:chest/util/auxiliar.dart';
import 'package:chest/util/config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPage();
}

class _LandingPage extends State<LandingPage> {
  bool buscandoUbicion = false;

  @override
  Widget build(BuildContext context) {
    // List<City> lstCities = Auxiliar.exCities;
    // lstCities.shuffle(Random());
    // lstCities = lstCities.sublist(0, 4);

    // List<Widget> lstPopularCities = [
    //   Center(
    //     child: Container(
    //       constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
    //       child: Wrap(
    //         alignment: WrapAlignment.start,
    //         crossAxisAlignment: WrapCrossAlignment.start,
    //         runSpacing: 5,
    //         spacing: 5,
    //         children: List.generate(lstCities.length, (index) {
    //           City p = lstCities.elementAt(index);
    //           return OutlinedButton(
    //             onPressed: () => GoRouter.of(context)
    //                 .go('/map?center=${p.point.latitude},${p.point.longitude}'),
    //             child: Text(p.label(lang: MyApp.currentLang) ?? p.label()!),
    //           );
    //         }),
    //       ),
    //     ),
    //   ),
    // ];
    AppLocalizations? appLoca = AppLocalizations.of(context);
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextTheme textTheme = td.textTheme;
    Size size = MediaQuery.of(context).size;
    double widthContainer = min(size.width, Auxiliar.maxWidth);
    List<Widget> contenidoLandingPage = [
      queEsChest(textTheme, colorScheme, appLoca, widthContainer),
      datosQueUsamos(textTheme, colorScheme, appLoca, widthContainer),
      quienesSomos(textTheme, colorScheme, appLoca, widthContainer),
      premiosPublicaciones(textTheme, colorScheme, appLoca, widthContainer),
    ];

    double desplazaAppBar = size.height * 0.35;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              primary: false,
              centerTitle: true,
              leadingWidth: 80,
              expandedHeight: max(152, desplazaAppBar),
              automaticallyImplyLeading: false,
              leading: Padding(
                padding: const EdgeInsets.only(
                  top: 5,
                  bottom: 5,
                  left: 16,
                  right: 16,
                ),
                child: SvgPicture.asset(
                  'images/logo.svg',
                  width: 48,
                  semanticsLabel: appLoca!.chest,
                ),
              ),
              title: Center(
                child: SearchAnchor.bar(
                  constraints: const BoxConstraints(
                      maxWidth: Auxiliar.maxWidth, minHeight: 56),
                  suggestionsBuilder: (context, controller) =>
                      Auxiliar.recuperaSugerencias(context, controller),
                  barHintText: appLoca.dondeQuiresEmpezar,
                  barTrailing: [
                    buscandoUbicion
                        ? const CircularProgressIndicator()
                        : IconButton(
                            tooltip: appLoca.startInMyLocation,
                            icon: const Icon(Icons.my_location),
                            onPressed: () async {
                              LocationSettings locationSettings =
                                  await Auxiliar.checkPermissionsLocation(
                                      context, defaultTargetPlatform);
                              setState(() => buscandoUbicion = true);
                              await Geolocator.getPositionStream(
                                      locationSettings: locationSettings)
                                  .first
                                  .then((Position p) {
                                setState(() => buscandoUbicion = false);
                                GoRouter.of(context).go(
                                    '/map?center=${p.latitude},${p.longitude}&zoom=15');
                              });
                            },
                          )
                  ],
                  // isFullScreen: false,
                ),
              ),
              actions: kIsWeb
                  ? [
                      IconButton(
                        onPressed: () async {
                          ScaffoldMessengerState sms =
                              ScaffoldMessenger.of(context);
                          try {
                            if (!await launchUrl(Uri.parse(
                                "https://play.google.com/store/apps/details?id=es.uva.gsic.chest"))) {
                              throw Exception();
                            }
                          } catch (error) {
                            sms.clearSnackBars();
                            sms.showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Error",
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.android),
                      ),
                      IconButton(
                        onPressed: () {
                          ScaffoldMessengerState sMState =
                              ScaffoldMessenger.of(context);
                          sMState.clearSnackBars();
                          sMState.showSnackBar(
                            SnackBar(
                              backgroundColor:
                                  Theme.of(context).colorScheme.errorContainer,
                              content: Text(
                                appLoca.enDesarrollo,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium!
                                    .copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer,
                                    ),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.apple),
                      ),
                    ]
                  : null,
            ),
            SliverList.builder(
              itemBuilder: (context, index) => Center(
                child: Container(
                  margin: index == 0
                      ? EdgeInsets.only(
                          top: desplazaAppBar / 2,
                          bottom: 40,
                          left: 20,
                          right: 20,
                        )
                      : const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 40,
                        ),
                  constraints:
                      const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: index.isOdd
                        ? colorScheme.secondaryContainer
                        : colorScheme.primaryContainer,
                  ),
                  child: contenidoLandingPage.elementAt(index),
                ),
              ),
              itemCount: contenidoLandingPage.length,
            ),
            descargaChest(textTheme, colorScheme, appLoca, widthContainer),
          ],
        ),
      ),
    );
  }

  Widget queEsChest(
    TextTheme textTheme,
    ColorScheme colorScheme,
    AppLocalizations? appLoca,
    double widthContainer,
  ) {
    double dosColum = (widthContainer / 2) - 45;
    bool ancho = widthContainer < Auxiliar.maxWidth;
    Color colorBackground = colorScheme.primary;
    Color colorText = colorScheme.onPrimary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 40, top: 20),
          child: Text(
            appLoca!.lpPreguntaCHEST,
            style: textTheme.headlineSmall!.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Wrap(
          spacing: 20,
          runSpacing: 20,
          alignment: WrapAlignment.spaceEvenly,
          crossAxisAlignment: WrapCrossAlignment.start,
          runAlignment: WrapAlignment.center,
          direction: Axis.horizontal,
          children: [
            _columnCard(
              textTheme,
              appLoca.lpCHESTEs,
              title: appLoca.lpCHESTEsTitle,
              width: widthContainer,
              colorBackground: colorBackground,
              colorText: colorText,
            ),
            _columnCard(
              textTheme,
              appLoca.lpNavegaMapa,
              title: appLoca.lpNavegaMapaTitle,
              width: ancho ? widthContainer : dosColum,
              image: 'images/landing/marcadores.png',
              colorBackground: colorBackground,
              colorText: colorText,
            ),
            _columnCard(
              textTheme,
              appLoca.lpRealizaTareas,
              title: appLoca.lpRealizaTareasTitle,
              width: ancho ? widthContainer : (widthContainer / 2) - 45,
              image: 'images/landing/tareasDescripcion.png',
              colorBackground: colorBackground,
              colorText: colorText,
            ),
            _columnCard(
              textTheme,
              appLoca.lpCreaTareas,
              title: appLoca.lpCreaTareasTitle,
              width: ancho ? widthContainer : dosColum,
              image: 'images/landing/creaTarea.png',
              colorBackground: colorBackground,
              colorText: colorText,
            ),
            _columnCard(
              textTheme,
              appLoca.lpCreaItinerarios,
              title: appLoca.lpCreaItinerariosTitle,
              width: ancho ? widthContainer : dosColum,
              image: 'images/landing/itinerarios.png',
              colorBackground: colorBackground,
              colorText: colorText,
            ),
          ],
        ),
      ],
    );
  }

  Widget datosQueUsamos(
    TextTheme textTheme,
    ColorScheme colorScheme,
    AppLocalizations? appLoca,
    double widthContainer,
  ) {
    double dosColum = (widthContainer / 2) - 45;
    bool ancho = widthContainer < Auxiliar.maxWidth;
    Color colorBackground = colorScheme.secondary;
    Color colorText = colorScheme.onSecondary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 40, top: 20),
          child: Text(
            appLoca!.lpQueDatosUsamos,
            style: textTheme.headlineSmall!.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Wrap(
          spacing: 20,
          runSpacing: 20,
          alignment: WrapAlignment.spaceEvenly,
          crossAxisAlignment: WrapCrossAlignment.start,
          runAlignment: WrapAlignment.center,
          direction: Axis.horizontal,
          children: [
            _columnCard(
              textTheme,
              appLoca.lpQueEsLOD,
              title: appLoca.lpQueEsLODTitle,
              colorBackground: colorBackground,
              colorText: colorText,
              width: ancho ? widthContainer : dosColum,
            ),
            _columnCard(
              textTheme,
              appLoca.lpDatosPrivados,
              title: appLoca.lpDatosPrivadosTitle,
              colorBackground: colorBackground,
              colorText: colorText,
              width: ancho ? widthContainer : dosColum,
            ),
          ],
        ),
      ],
    );
  }

  Widget quienesSomos(TextTheme textTheme, ColorScheme colorScheme,
      AppLocalizations? appLoca, double widthContainer) {
    double tresColum = (widthContainer / 3) - 45;
    bool ancho = tresColum * 3 < 599;
    Color colorBackground = colorScheme.primary;
    Color colorText = colorScheme.onPrimary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 40, top: 20),
          child: Text(
            appLoca!.lpQuienesSomos,
            style: textTheme.headlineSmall!.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Wrap(
          spacing: 20,
          runSpacing: 20,
          alignment: WrapAlignment.spaceEvenly,
          crossAxisAlignment: WrapCrossAlignment.start,
          runAlignment: WrapAlignment.center,
          direction: Axis.horizontal,
          children: [
            _columnCard(
              textTheme,
              appLoca.lpGSIC,
              title: appLoca.lpGSICTitle,
              width: widthContainer,
              image: 'images/landing/gsic.png',
              heightImg: 288,
              fitImage: BoxFit.fitWidth,
              colorBackground: colorBackground,
              colorText: colorText,
            ),
            _columnCard(
              textTheme,
              appLoca.lpBecaUVaSantander,
              title: appLoca.lpBecaUVaSantanderTitle,
              width: ancho ? widthContainer : tresColum,
              colorBackground: colorBackground,
              colorText: colorText,
            ),
            _columnCard(
              textTheme,
              appLoca.lpH2O,
              title: appLoca.lpH2OTitle,
              width: ancho ? widthContainer : tresColum,
              colorBackground: colorBackground,
              colorText: colorText,
            ),
            _columnCard(
              textTheme,
              appLoca.lpLodForTrees,
              title: appLoca.lpLodForTreesTitle,
              width: ancho ? widthContainer : tresColum,
              colorBackground: colorBackground,
              colorText: colorText,
            ),
          ],
        ),
      ],
    );
  }

  Widget premiosPublicaciones(TextTheme textTheme, ColorScheme colorScheme,
      AppLocalizations? appLoca, double widthContainer) {
    Color colorBackground = colorScheme.secondary;
    Color colorText = colorScheme.onSecondary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 40, top: 20),
          child: Text(
            appLoca!.premiosPublicaciones,
            style: textTheme.headlineSmall!.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Wrap(
          spacing: 20,
          runSpacing: 20,
          alignment: WrapAlignment.spaceEvenly,
          crossAxisAlignment: WrapCrossAlignment.start,
          runAlignment: WrapAlignment.center,
          direction: Axis.horizontal,
          children: [
            _columnCard(
              textTheme,
              appLoca.datosAbiertosJuntaDescripcion,
              title: appLoca.datosAbiertosJunta,
              width: widthContainer,
              image: 'images/landing/jcyl.jpg',
              fitImage: BoxFit.fitWidth,
              heightImg: 300,
              colorBackground: colorBackground,
              colorText: colorText,
              uriString:
                  "https://bocyl.jcyl.es/boletines/2023/11/09/pdf/BOCYL-D-09112023-20.pdf",
            ),
            _columnCard(
              textTheme,
              appLoca.dcEctel,
              uriString: "https://ceur-ws.org/Vol-3539/paper10.pdf",
              width: widthContainer,
              colorBackground: colorBackground,
              colorText: colorText,
            ),
            _columnCard(
              textTheme,
              appLoca.ectel22,
              uriString: "https://doi.org/10.1007/978-3-031-16290-9_34",
              width: widthContainer,
              colorBackground: colorBackground,
              colorText: colorText,
            ),
            _columnCard(
              textTheme,
              appLoca.las22,
              uriString: "https://doi.org/10.1145/3491140.3528335",
              width: widthContainer,
              colorBackground: colorBackground,
              colorText: colorText,
            ),
          ],
        ),
      ],
    );
  }

  Widget descargaChest(TextTheme textTheme, ColorScheme colorScheme,
      AppLocalizations? appLoca, double widthContainer) {
    return SliverList.builder(
      itemBuilder: (context, index) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: colorScheme.tertiaryContainer,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RichText(
                    text: TextSpan(
                      text: appLoca!.descargaApp.replaceFirst(
                          appLoca.descargaApp.split(', ').last, ''),
                      style: textTheme.titleLarge!.copyWith(
                        color: colorScheme.onTertiaryContainer,
                      ),
                      children: [
                        TextSpan(
                          text: appLoca.descargaApp.split(', ').last,
                          style: textTheme.titleLarge!.copyWith(
                            color: colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.spaceAround,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runAlignment: WrapAlignment.spaceAround,
                  runSpacing: 10,
                  spacing: 20,
                  children: [
                    InkWell(
                      onTap: () async {
                        ScaffoldMessengerState sms =
                            ScaffoldMessenger.of(context);
                        try {
                          if (!await launchUrl(Uri.parse(
                              "https://play.google.com/store/apps/details?id=es.uva.gsic.chest"))) {
                            throw Exception();
                          }
                        } catch (error) {
                          sms.clearSnackBars();
                          sms.showSnackBar(
                            SnackBar(
                              content: Text(
                                "Error",
                              ),
                            ),
                          );
                        }
                      },
                      child: Tooltip(
                        message: appLoca.descargaAppAndroid,
                        child: SvgPicture.asset(
                          'images/landing/badges/google-play-badge-${MyApp.currentLang == 'es' ? 'es' : MyApp.currentLang == 'pt' ? 'pt' : 'en'}.svg',
                          width: 200,
                          semanticsLabel: appLoca.descargaAppAndroid,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        ScaffoldMessengerState sMState =
                            ScaffoldMessenger.of(context);
                        sMState.clearSnackBars();
                        sMState.showSnackBar(
                          SnackBar(
                            backgroundColor:
                                Theme.of(context).colorScheme.errorContainer,
                            content: Text(
                              appLoca.enDesarrollo,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium!
                                  .copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer,
                                  ),
                            ),
                          ),
                        );
                      },
                      child: Tooltip(
                        message: appLoca.descargaAppIOS,
                        child: SvgPicture.asset(
                          'images/landing/badges/app-store-badge-${MyApp.currentLang == 'es' ? 'es' : MyApp.currentLang == 'pt' ? 'pt' : 'en'}.svg',
                          width: 200,
                          semanticsLabel: appLoca.descargaAppIOS,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '\u00a9 Google Play and the Google Play logo are trademarks of Google LLC.',
                  style: textTheme.labelMedium!
                      .copyWith(color: colorScheme.onTertiaryContainer),
                ),
              ),
              Text(
                '\u00a9 App Store and the App Store logo are trademarks of Apple Inc.',
                style: textTheme.labelMedium!
                    .copyWith(color: colorScheme.onTertiaryContainer),
              ),
            ],
          ),
        ),
      ),
      itemCount: kIsWeb ? 1 : 0,
    );
  }

  Widget _columnCard(
    TextTheme textTheme,
    String description, {
    String? title,
    String? image,
    BoxFit fitImage = BoxFit.cover,
    double width = 470,
    double? heightImg,
    Color colorBackground = Colors.white,
    Color colorText = Colors.black,
    String? uriString,
  }) {
    ScaffoldMessengerState sms = ScaffoldMessenger.of(context);
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: colorBackground,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title != null
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SelectableText(
                    title,
                    style: textTheme.titleLarge!.copyWith(
                      color: colorText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : Container(),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: uriString != null
                ? TextButton.icon(
                    onLongPress: () async {
                      await Clipboard.setData(ClipboardData(text: uriString));
                      sms.clearSnackBars();
                      sms.showSnackBar(const SnackBar(
                        content: Text("Copy to clipboard"),
                        duration: Durations.extralong2,
                      ));
                    },
                    icon: InkWell(
                        child: Icon(Icons.link, color: colorText),
                        onTap: () async {
                          if (!await launchUrl(Uri.parse(uriString))) {
                            if (Config.development) debugPrint('Uri problem');
                          }
                        }),
                    label: SelectableText(
                      description,
                      style: textTheme.titleMedium!.copyWith(color: colorText),
                    ),
                    onPressed: null,
                  )
                : SelectableText(
                    description,
                    style: textTheme.titleMedium!.copyWith(color: colorText),
                  ),
          ),
          image != null
              ? Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      image,
                      fit: fitImage,
                      height: heightImg ?? 500,
                    ),
                  ),
                )
              : Container(),
        ],
      ),
    );
  }
}

import 'dart:math';

import 'package:chest/main.dart';
import 'package:chest/util/auxiliar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

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
    List<Widget> contenidoLandingPage = [
      queEsChest(textTheme, colorScheme, appLoca),
      datosQueUsamos(textTheme, colorScheme, appLoca),
      quienesSomos(textTheme, colorScheme, appLoca),
    ];

    double desplazaAppBar = MediaQuery.of(context).size.height * 0.4;
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
                          top: desplazaAppBar,
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
                        ? colorScheme.primaryContainer
                        : colorScheme.secondaryContainer,
                  ),
                  child: contenidoLandingPage.elementAt(index),
                ),
              ),
              itemCount: contenidoLandingPage.length,
            ),
            descargaChest(textTheme, colorScheme, appLoca),
          ],
        ),
      ),
    );
  }

  Widget queEsChest(
      TextTheme textTheme, ColorScheme colorScheme, AppLocalizations? appLoca) {
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
              appLoca.lpCHESTEsTitle,
              appLoca.lpCHESTEs,
              width: 960,
              colorBackground: colorScheme.secondary,
              colorText: colorScheme.onSecondary,
            ),
            _columnCard(
              textTheme,
              appLoca.lpNavegaMapaTitle,
              appLoca.lpNavegaMapa,
              image: 'images/landing/marcadores.png',
              colorBackground: colorScheme.secondary,
              colorText: colorScheme.onSecondary,
            ),
            _columnCard(
              textTheme,
              appLoca.lpRealizaTareasTitle,
              appLoca.lpRealizaTareas,
              image: 'images/landing/tareasDescripcion.png',
              colorBackground: colorScheme.secondary,
              colorText: colorScheme.onSecondary,
            ),
            _columnCard(
              textTheme,
              appLoca.lpCreaTareasTitle,
              appLoca.lpCreaTareas,
              image: 'images/landing/creaTarea.png',
              colorBackground: colorScheme.secondary,
              colorText: colorScheme.onSecondary,
            ),
            _columnCard(
              textTheme,
              appLoca.lpCreaItinerariosTitle,
              appLoca.lpCreaItinerarios,
              image: 'images/landing/itinerarios.png',
              colorBackground: colorScheme.secondary,
              colorText: colorScheme.onSecondary,
            ),
          ],
        ),
      ],
    );
  }

  Widget datosQueUsamos(
      TextTheme textTheme, ColorScheme colorScheme, AppLocalizations? appLoca) {
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
              appLoca.lpQueEsLODTitle,
              appLoca.lpQueEsLOD,
              colorBackground: colorScheme.primary,
              colorText: colorScheme.onPrimary,
            ),
            _columnCard(
              textTheme,
              appLoca.lpDatosPrivadosTitle,
              appLoca.lpDatosPrivados,
              colorBackground: colorScheme.primary,
              colorText: colorScheme.onPrimary,
            ),
          ],
        ),
      ],
    );
  }

  Widget quienesSomos(
      TextTheme textTheme, ColorScheme colorScheme, AppLocalizations? appLoca) {
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
              appLoca.lpGSICTitle,
              appLoca.lpGSIC,
              width: 960,
              image: 'images/landing/gsic.png',
              fitImage: BoxFit.contain,
              colorBackground: colorScheme.secondary,
              colorText: colorScheme.onSecondary,
            ),
            _columnCard(
              textTheme,
              appLoca.lpBecaUVaSantanderTitle,
              appLoca.lpBecaUVaSantander,
              width: 300,
              colorBackground: colorScheme.secondary,
              colorText: colorScheme.onSecondary,
            ),
            _columnCard(
              textTheme,
              appLoca.lpH2OTitle,
              appLoca.lpH2O,
              width: 300,
              colorBackground: colorScheme.secondary,
              colorText: colorScheme.onSecondary,
            ),
            _columnCard(
              textTheme,
              appLoca.lpLodForTreesTitle,
              appLoca.lpLodForTrees,
              width: 300,
              colorBackground: colorScheme.secondary,
              colorText: colorScheme.onSecondary,
            ),
          ],
        ),
      ],
    );
  }

  Widget descargaChest(
      TextTheme textTheme, ColorScheme colorScheme, AppLocalizations? appLoca) {
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
    String title,
    String description, {
    String? image,
    BoxFit fitImage = BoxFit.cover,
    double width = 470,
    Color colorBackground = Colors.white,
    Color colorText = Colors.black,
  }) {
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
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              title,
              style: textTheme.titleLarge!.copyWith(
                color: colorText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              description,
              style: textTheme.titleMedium!.copyWith(color: colorText),
            ),
          ),
          image != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    image,
                    fit: fitImage,
                    height: 500,
                  ),
                )
              : Container(),
        ],
      ),
    );
  }
}

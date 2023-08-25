import 'dart:math';

import 'package:chest/main.dart';
import 'package:chest/util/auxiliar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPage();
}

class _LandingPage extends State<LandingPage> {
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

    double desplaza = MediaQuery.of(context).size.height * 0.75;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              primary: false,
              centerTitle: true,
              leadingWidth: 80,
              expandedHeight: max(152, desplaza),
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
              title: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Center(
                  child: SearchAnchor.bar(
                    constraints:
                        const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                    suggestionsBuilder: (context, controller) =>
                        Auxiliar.recuperaSugerencias(context, controller),
                    barHintText: appLoca.dondeQuiresEmpezar,
                    isFullScreen: false,
                  ),
                ),
              ),
              actions: kIsWeb
                  ? [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.android),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.apple),
                      ),
                    ]
                  : null,
            ),
            SliverList.builder(
              itemBuilder: (context, index) => Center(
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
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
              image: 'images/landing/marcadores.png',
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
              image: 'images/landing/marcadores.png',
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
            appLoca!.lpPreguntaCHEST, //TODO: Cambiar a qué datos usamos
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
              appLoca.lpCHESTEsTitle, //TODO: Cambiar a qué es LOD
              appLoca.lpCHESTEs,
              image:
                  'images/landing/marcadores.png', //TODO: Cambiar a 'images/landing/lod.png
              colorBackground: colorScheme.primary,
              colorText: colorScheme.onPrimary,
            ),
            _columnCard(
              textTheme,
              appLoca
                  .lpCHESTEsTitle, //TODO: Cambiar a datos privados que usamos
              appLoca.lpCHESTEs,
              image:
                  'images/landing/marcadores.png', //TODO: Cambiar a algo que represente seguridad
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
            appLoca!.lpPreguntaCHEST, //TODO: Cambiar a quiénes somos
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
              appLoca.lpCHESTEsTitle, //TODO: Cambiar a GSIC
              appLoca.lpCHESTEs,
              width: 960,
              image: 'images/landing/marcadores.png',
              colorBackground: colorScheme.secondary,
              colorText: colorScheme.onSecondary,
            ),
            _columnCard(
              // TODO: Cambiar a los proyectos
              textTheme,
              appLoca.lpCHESTEsTitle,
              appLoca.lpCHESTEs,
              width: 300,
              image: 'images/landing/marcadores.png',
              colorBackground: colorScheme.secondary,
              colorText: colorScheme.onSecondary,
            ),
            _columnCard(
              // TODO: Cambiar a los proyectos
              textTheme,
              appLoca.lpCHESTEsTitle,
              appLoca.lpCHESTEs,
              width: 300,
              image: 'images/landing/marcadores.png',
              colorBackground: colorScheme.secondary,
              colorText: colorScheme.onSecondary,
            ),
            _columnCard(
              // TODO: Cambiar a los proyectos
              textTheme,
              appLoca.lpCHESTEsTitle,
              appLoca.lpCHESTEs,
              width: 300,
              image: 'images/landing/marcadores.png',
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
                      onTap: () {},
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
                      onTap: () {},
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
                    fit: BoxFit.cover,
                    height: 500,
                  ),
                )
              : Container(),
        ],
      ),
    );
  }
}

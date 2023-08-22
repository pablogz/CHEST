import 'dart:math';

import 'package:chest/main.dart';
import 'package:chest/util/auxiliar.dart';
import 'package:chest/util/helpers/city.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPage();
}

class _LandingPage extends State<LandingPage> {
  @override
  Widget build(BuildContext context) {
    List<City> lstCities = Auxiliar.exCities;
    lstCities.shuffle(Random());
    lstCities = lstCities.sublist(0, 4);

    List<Widget> lstPopularCities = [
      Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
          child: Wrap(
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.start,
            runSpacing: 5,
            spacing: 5,
            children: List.generate(lstCities.length, (index) {
              City p = lstCities.elementAt(index);
              return OutlinedButton(
                onPressed: () => GoRouter.of(context)
                    .go('/map?center=${p.point.latitude},${p.point.longitude}'),
                child: Text(p.label(lang: MyApp.currentLang) ?? p.label()!),
              );
            }),
          ),
        ),
      ),
    ];
    AppLocalizations? appLoca = AppLocalizations.of(context);
    TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SvgPicture.asset(
              'images/logo.svg',
              height: 40,
              semanticsLabel: 'CHEST',
            ),
            const SizedBox(width: 5),
            Text(
              appLoca!.chest,
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // SliverAppBar(
            //   pinned: true,
            //   title: Row(
            //     mainAxisAlignment: MainAxisAlignment.start,
            //     mainAxisSize: MainAxisSize.min,
            //     crossAxisAlignment: CrossAxisAlignment.end,
            //     children: [
            //       SvgPicture.asset(
            //         'images/logo.svg',
            //         height: 40,
            //         semanticsLabel: 'CHEST',
            //       ),
            //       const SizedBox(width: 5),
            //       Text(
            //         appLoca!.chest,
            //       ),
            //     ],
            //   ),
            //   centerTitle: false,
            // ),
            SliverPadding(
              padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Center(
                    child: Text(
                      appLoca.dondeQuiresEmpezar,
                      style: textTheme.headlineSmall,
                    ),
                  ),
                  childCount: 1,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(top: 5, left: 20, right: 20),
              sliver: SliverAppBar(
                primary: false,
                centerTitle: true,
                clipBehavior: Clip.none,
                shape: const StadiumBorder(),
                scrolledUnderElevation: 0.0,
                titleSpacing: 0.0,
                backgroundColor: Colors.transparent,
                title: SearchAnchor.bar(
                  constraints:
                      const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                  suggestionsBuilder: (context, controller) =>
                      Auxiliar.recuperaSugerencias(context, controller),
                  barHintText: "Valladolid",
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(
                  top: 10, left: 20, right: 20, bottom: 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => lstPopularCities.elementAt(index),
                  childCount: lstPopularCities.length,
                ),
              ),
            ),
            SliverList.builder(
                itemBuilder: (context, index) => Center(
                      child: Container(
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        height: 500,
                      ),
                    ),
                itemCount: 1),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
//import 'package:flutter_svg/svg.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:chest/helpers/auxiliar.dart';

class MoreInfo extends StatelessWidget {
  const MoreInfo({super.key});

  List<Widget> widgetMoreInfo(ThemeData td, String title, String text) {
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(
          title,
          style: td.textTheme.headlineSmall,
        ),
      ),
      Text(
        text,
        textAlign: TextAlign.left,
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        child: Divider(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    ThemeData td = Theme.of(context);
    AppLocalizations? appLoca = AppLocalizations.of(context);
    List<Widget> lst = [];
    lst.addAll(widgetMoreInfo(td, appLoca!.infoQueEs, appLoca.infoQueEsM));
    lst.addAll(widgetMoreInfo(td, appLoca.infoLod, appLoca.infoLodM));
    lst.addAll(widgetMoreInfo(td, appLoca.infoGSIC, appLoca.infoGSICM));
    lst.addAll(widgetMoreInfo(td, appLoca.infoLicense, '')); //TODO
    lst.addAll(widgetMoreInfo(td, appLoca.infoMapas, appLoca.infoMapasM));
    lst.addAll(widgetMoreInfo(td, appLoca.infoBiblios, '')); //TODO

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(AppLocalizations.of(context)!.sobreCHEST),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              vertical: 40,
              horizontal: 10,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                  (context, index) => Center(
                          child: Container(
                        constraints:
                            const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                        child: lst.elementAt(index),
                      )),
                  childCount: lst.length),
            ),
          )
        ],
      ),
    );
  }
}

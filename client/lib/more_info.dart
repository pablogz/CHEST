import 'package:flutter/material.dart';
//import 'package:flutter_svg/svg.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:fwfh_url_launcher/fwfh_url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:chest/helpers/auxiliar.dart';
import 'package:chest/helpers/widget_facto.dart';

class MoreInfo extends StatelessWidget {
  const MoreInfo({super.key});

  List<Widget> widgetMoreInfo(ThemeData td, String title, String text,
      {bool divider = true}) {
    List<Widget> lst = [
      Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(
          title,
          style: td.textTheme.headlineSmall,
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: HtmlWidget(
          text,
          textStyle: td.textTheme.bodyMedium,
          factoryBuilder: () => MyWidgetFactory(),
        ),
      ),
    ];
    if (divider) {
      lst.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          child: Divider(),
        ),
      );
    }
    return lst;
  }

  @override
  Widget build(BuildContext context) {
    ThemeData td = Theme.of(context);
    AppLocalizations? appLoca = AppLocalizations.of(context);
    List<Widget> lst = [];
    lst.addAll(widgetMoreInfo(td, appLoca!.infoQueEs, appLoca.infoQueEsM));
    lst.addAll(widgetMoreInfo(td, appLoca.infoLod, appLoca.infoLodM));
    lst.addAll(widgetMoreInfo(td, appLoca.infoGSIC, appLoca.infoGSICM));
    lst.addAll(widgetMoreInfo(td, appLoca.infoLicense, appLoca.infoLicenseM));
    lst.addAll(widgetMoreInfo(td, appLoca.infoMapas, appLoca.infoMapasM));
    lst.addAll(widgetMoreInfo(td, appLoca.infoBiblios, appLoca.infoBibliosM,
        divider: false));
    lst.add(Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: OutlinedButton(
        onPressed: () {
          List<String> lbr = [
            appLoca.lbrflutter_map,
            appLoca.lbrflutter_map_marker_cluster,
            appLoca.lbrCupertinoIcons,
            appLoca.lbrgeolocator,
            appLoca.lbrfirebase_core,
            appLoca.lbrfirebase_auth,
            appLoca.lbrfirebase_analytics,
            appLoca.lbrhttp,
            appLoca.lbrmustache_template,
            appLoca.lbruniversal_io,
            appLoca.lbrgoogle_fonts,
            appLoca.lbrflutter_svg,
            appLoca.lbremail_validator,
            appLoca.lbrurl_launcher,
            appLoca.lbrfwfh_url_launcher,
            appLoca.lbrflutter_map,
            appLoca.lbrcamera,
            appLoca.lbrextended_image,
            appLoca.lbrconnectivity_plus,
            appLoca.lbrurl_strategy
          ];

          List<Widget> lbrW = [];
          for (String str in lbr) {
            lbrW.add(Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: Icon(
                        Icons.circle,
                        size: 10,
                        color: td.colorScheme.primary,
                      ),
                    ),
                    Expanded(
                      child: HtmlWidget(
                        str,
                        textStyle: td.textTheme.bodyMedium,
                        factoryBuilder: () => MyWidgetFactory(),
                      ),
                    ),
                  ],
                ),
              ),
            ));
          }

          showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                  title: Text(appLoca.infoBiblios),
                  titlePadding: const EdgeInsets.only(
                      top: 24, right: 24, bottom: 10, left: 24),
                  actions: [
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(appLoca.cancelar),
                    )
                  ],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  scrollable: true,
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: lbrW,
                  )
                  // content: CustomScrollView(
                  //   slivers: [
                  //     SliverList(
                  //       delegate: SliverChildBuilderDelegate(
                  //         (context, index) {
                  //           return Padding(
                  //             padding: const EdgeInsets.symmetric(vertical: 5),
                  //             child: Align(
                  //               alignment: Alignment.centerLeft,
                  //               child: HtmlWidget(
                  //                 "lbr.elementAt(index)",
                  //                 textStyle: td.textTheme.bodyMedium,
                  //                 factoryBuilder: () => MyWidgetFactory(),
                  //               ),
                  //             ),
                  //           );
                  //         },
                  //         childCount: 3,
                  //       ),
                  //     )
                  //   ],
                  ),
              barrierDismissible: true);
        },
        child: Text(appLoca.infoBiblios),
      ),
    ));

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
                        ),
                      ),
                  childCount: lst.length),
            ),
          )
        ],
      ),
    );
  }
}

import 'package:chest/util/config.dart';
import 'package:flutter/material.dart';
//import 'package:flutter_svg/svg.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
// import 'package:fwfh_url_launcher/fwfh_url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:chest/util/auxiliar.dart';
import 'package:chest/util/helpers/widget_facto.dart';

class MoreInfo extends StatefulWidget {
  const MoreInfo({super.key});

  @override
  State<MoreInfo> createState() => _MoreInfo();
}

class _MoreInfo extends State<MoreInfo> {
  @override
  Widget build(BuildContext context) {
    ThemeData td = Theme.of(context);
    AppLocalizations? appLoca = AppLocalizations.of(context);
    List<Widget> lst = [];
    lst.addAll(_widgetMoreInfo(td, appLoca!.infoQueEs, appLoca.infoQueEsM));
    lst.addAll(_widgetMoreInfo(td, appLoca.infoLod, appLoca.infoLodM));
    lst.addAll(_widgetMoreInfo(td, appLoca.infoGSIC, appLoca.infoGSICM));
    lst.addAll(_widgetMoreInfo(td, appLoca.infoLicense, appLoca.infoLicenseM));
    lst.addAll(_widgetMoreInfo(td, appLoca.infoMapas, appLoca.infoMapasM));
    lst.addAll(_widgetMoreInfo(td, appLoca.infoBiblios, appLoca.infoBibliosM,
        divider: false));
    lst.add(Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: OutlinedButton(
        onPressed: () {
          List<String> lbr = [
            appLoca.lbrflutter_map,
            appLoca.lbrflutter_map_marker_cluster,
            appLoca.lbrflutter_map_cancellable_tile_provider,
            appLoca.lbralatlong2,
            appLoca.lbrIntl,
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
            appLoca.lbrurl_launcher,
            appLoca.lbrfwfh_url_launcher,
            appLoca.lbrcamera,
            appLoca.lbrurl_strategy,
            appLoca.lbruuid,
            appLoca.lbrgo_router,
            appLoca.lbrshare_plus,
            appLoca.lbrpath_provider,
            appLoca.lbrshared_preferences,
            appLoca.lbrimage_network,
            appLoca.lbrquill_html_editor,
            appLoca.lbrcached_network_image,
            appLoca.lbrgpx,
            appLoca.lbrfile_picker,
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
                    ),
                  ),
              barrierDismissible: true);
        },
        child: Text(appLoca.infoBiblios),
      ),
    ));

    return Scaffold(
        body: CustomScrollView(slivers: [
      SliverAppBar(
        title: Text(AppLocalizations.of(context)!.sobreCHEST),
        centerTitle: false,
        pinned: true,
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
      ),
      const SliverPadding(
        padding: EdgeInsets.only(
          bottom: 40,
          left: 10,
          right: 10,
        ),
        sliver: SliverToBoxAdapter(
          child: Center(
            child: Text('V. ${Config.version}'),
          ),
        ),
      )
    ]));
  }

  List<Widget> _widgetMoreInfo(ThemeData td, String title, String text,
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
}

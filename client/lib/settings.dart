import 'package:flutter/material.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:chest/util/auxiliar.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _Settings();
}

class _Settings extends State<Settings> {
  @override
  Widget build(BuildContext context) {
    AppLocalizations appLoca = AppLocalizations.of(context)!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(appLoca.ajustes),
            floating: true,
            primary: false,
          ),
          bodyWidget(),
        ],
      ),
    );
  }

  Widget bodyWidget() {
    double widthScreen = MediaQuery.of(context).size.width;
    List<Widget> lstBody = [];

    return SliverList.builder(
      itemCount: lstBody.length,
      itemBuilder: (context, index) => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
          child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: 5,
                horizontal: Auxiliar.getLateralMargin(widthScreen),
              ),
              child: lstBody.elementAt(index)),
        ),
      ),
    );
  }
}

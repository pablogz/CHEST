import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'helpers/auxiliar.dart';

class MoreInfo extends StatelessWidget {
  const MoreInfo({super.key});

  @override
  Widget build(BuildContext context) {
    final double widthDevice = MediaQuery.of(context).size.width;
    double widthImg =
        (MediaQuery.of(context).orientation == Orientation.landscape)
            ? widthDevice / 8
            : widthDevice / 4;
    bool lightMode =
        MediaQuery.of(context).platformBrightness == Brightness.light;
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Theme.of(context).primaryColorDark,
          leading: const BackButton(color: Colors.white),
          title: const Text('CHEST')),
      body: Center(
          child: SingleChildScrollView(
              child: Column(
        children: [
          Container(
              constraints: const BoxConstraints(maxWidth: Auxiliar.MAX_WIDTH),
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SvgPicture.asset(
                    'images/logo.svg',
                    width: widthImg,
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.infoQueEs,
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall!
                            .copyWith(
                                color: lightMode ? Colors.black : Colors.white),
                      ),
                      Text(
                        AppLocalizations.of(context)!.infoQueEsM,
                      )
                    ],
                  )),
                ],
              )),
          const SizedBox(
            height: 10,
          ),
          Container(
              constraints: const BoxConstraints(maxWidth: Auxiliar.MAX_WIDTH),
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.infoLod,
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall!
                            .copyWith(
                                color: lightMode ? Colors.black : Colors.white),
                      ),
                      Text(AppLocalizations.of(context)!.infoLodM)
                    ],
                  )),
                  const SizedBox(
                    width: 10,
                  ),
                  Image.asset(
                    'images/fuentes.png',
                    width: widthImg,
                  )
                ],
              )),
          const SizedBox(
            height: 10,
          ),
          Container(
              constraints: const BoxConstraints(maxWidth: Auxiliar.MAX_WIDTH),
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'images/gsicUVa.png',
                    width: widthImg,
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.infoGSIC,
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall!
                            .copyWith(
                                color: lightMode ? Colors.black : Colors.white),
                      ),
                      Text(AppLocalizations.of(context)!.infoGSICM,
                          style: Theme.of(context).textTheme.bodyLarge)
                    ],
                  )),
                ],
              )),
          Container(
              alignment: Alignment.centerLeft,
              constraints: const BoxConstraints(maxWidth: Auxiliar.MAX_WIDTH),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.infoLicense,
                    style: Theme.of(context).textTheme.displaySmall!.copyWith(
                        color: lightMode ? Colors.black : Colors.white),
                  ),
                  //TODO
                  const Text(
                    '',
                  )
                ],
              )),
          const SizedBox(
            height: 20,
          ),
          Container(
              alignment: Alignment.centerLeft,
              constraints: const BoxConstraints(maxWidth: Auxiliar.MAX_WIDTH),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.infoMapas,
                    style: Theme.of(context).textTheme.displaySmall!.copyWith(
                        color: lightMode ? Colors.black : Colors.white),
                  ),
                  Text(
                    AppLocalizations.of(context)!.infoMapasM,
                  )
                ],
              )),
          const SizedBox(
            height: 20,
          ),
          Container(
              alignment: Alignment.centerLeft,
              constraints: const BoxConstraints(maxWidth: Auxiliar.MAX_WIDTH),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.infoBiblios,
                    style: Theme.of(context).textTheme.displaySmall!.copyWith(
                        color: lightMode ? Colors.black : Colors.white),
                  ),
                  //TODO
                  const Text(
                    '',
                  )
                ],
              )),
        ],
      ))),
    );
  }
}

import 'package:flutter/material.dart';
//import 'package:flutter_svg/svg.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:chest/helpers/auxiliar.dart';

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
          // leading: const BackButton(color: Colors.white),
          title: const Text('CHEST')),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                padding: const EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SvgPicture.asset(
                    //   'images/logo.svg',
                    //   width: widthImg,
                    // ),
                    // const SizedBox(
                    //   width: 10,
                    // ),
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
                                    color: Theme.of(context).brightness ==
                                            Brightness.light
                                        ? Colors.black
                                        : null),
                          ),
                          Text(
                            AppLocalizations.of(context)!.infoQueEsM,
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Container(
                  constraints:
                      const BoxConstraints(maxWidth: Auxiliar.maxWidth),
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
                                    color: Theme.of(context).brightness ==
                                            Brightness.light
                                        ? Colors.black
                                        : null),
                          ),
                          Text(AppLocalizations.of(context)!.infoLodM)
                        ],
                      )),
                      // const SizedBox(
                      //   width: 10,
                      // ),
                      // Image.asset(
                      //   'images/fuentes.png',
                      //   width: widthImg,
                      // )
                    ],
                  )),
              const Divider(),
              Container(
                constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                padding: const EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image.asset(
                    //   'images/gsicUVa.png',
                    //   width: widthImg,
                    // ),
                    // const SizedBox(
                    //   width: 10,
                    // ),
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
                                    color: Theme.of(context).brightness ==
                                            Brightness.light
                                        ? Colors.black
                                        : null),
                          ),
                          Text(AppLocalizations.of(context)!.infoGSICM,
                              style: Theme.of(context).textTheme.bodyLarge)
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Container(
                alignment: Alignment.centerLeft,
                constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.infoLicense,
                      style: Theme.of(context).textTheme.displaySmall!.copyWith(
                          color:
                              Theme.of(context).brightness == Brightness.light
                                  ? Colors.black
                                  : null),
                    ),
                    //TODO
                    const Text(
                      '',
                    )
                  ],
                ),
              ),
              const Divider(),
              Container(
                alignment: Alignment.centerLeft,
                constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.infoMapas,
                      style: Theme.of(context).textTheme.displaySmall!.copyWith(
                          color:
                              Theme.of(context).brightness == Brightness.light
                                  ? Colors.black
                                  : null),
                    ),
                    Text(
                      AppLocalizations.of(context)!.infoMapasM,
                    )
                  ],
                ),
              ),
              const Divider(),
              Container(
                alignment: Alignment.centerLeft,
                constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.infoBiblios,
                      style: Theme.of(context).textTheme.displaySmall!.copyWith(
                          color:
                              Theme.of(context).brightness == Brightness.light
                                  ? Colors.black
                                  : null),
                    ),
                    //TODO
                    const Text(
                      '',
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

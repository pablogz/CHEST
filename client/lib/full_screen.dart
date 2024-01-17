import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:chest/util/helpers/pair.dart';

class FullScreenImage extends StatelessWidget {
  final PairImage urlImagen;
  final bool local;
  final GestureConfig gc = GestureConfig(
    minScale: 0.2,
    animationMinScale: 0.1,
    maxScale: 4.0,
    animationMaxScale: 4.5,
    speed: 1.0,
    inertialSpeed: 100.0,
    initialScale: 1.0,
    inPageView: false,
    initialAlignment: InitialAlignment.center,
  );
  FullScreenImage(
    this.urlImagen, {
    this.local = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    Widget imagen = local
        ? ExtendedImage.asset(
            urlImagen.image,
            mode: ExtendedImageMode.gesture,
            initGestureConfigHandler: (state) => gc,
          )
        : ExtendedImage.network(
            urlImagen.image,
            cache: true,
            mode: ExtendedImageMode.gesture,
            initGestureConfigHandler: (state) => gc,
          );
    Widget cuerpo;
    if (urlImagen.hasLicense) {
      cuerpo = Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: imagen),
          TextButton.icon(
              onPressed: () async {
                ScaffoldMessengerState sms = ScaffoldMessenger.of(context);
                AppLocalizations? appLoca = AppLocalizations.of(context);
                try {
                  if (!await launchUrl(Uri.parse(urlImagen.license))) {
                    throw Exception();
                  }
                } catch (error) {
                  sms.clearSnackBars();
                  sms.showSnackBar(
                    SnackBar(
                      content: Text(
                        appLoca!.iniciaParaRealizar,
                      ),
                    ),
                  );
                }
              },
              label: Text(AppLocalizations.of(context)!.licenciaNPILabel),
              icon: const Icon(Icons.local_police)),
        ],
      );
    } else {
      cuerpo = imagen;
    }
    return Scaffold(
      appBar: AppBar(
        // backgroundColor: Theme.of(context).primaryColorDark,
        // leading: const BackButton(color: Colors.white),
        title: Text(AppLocalizations.of(context)!.pantallaCompleta),
      ),
      body: Center(child: cuerpo),
    );
  }
}

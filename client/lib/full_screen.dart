import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'helpers/auxiliar.dart';

class FullScreenImage extends StatelessWidget {
  final PairImage urlImagen;
  final bool local;
  const FullScreenImage(this.urlImagen, {required this.local, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColorDark,
        leading: const BackButton(color: Colors.white),
        title: Text(AppLocalizations.of(context)!.pantallaCompleta),
      ),
      // body: Center(
      //     child: InteractiveViewer(
      //         constrained: false,
      //         boundaryMargin: const EdgeInsets.all(double.infinity),
      //         minScale: 0.1,
      //         maxScale: 2.5,
      //         child: local
      //             ? Text('TODO')
      //             : Image.network(
      //                 urlImagen.image,
      //               ))),
      body: Center(
        child: local
            ? Text('TODO')
            : ExtendedImage.network(
                urlImagen.image,
                cache: true,
                mode: ExtendedImageMode.gesture,
                initGestureConfigHandler: (state) {
                  return GestureConfig(
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
                },
              ),
      ),
    );
  }
}

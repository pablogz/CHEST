import 'package:chest/main.dart';
import 'package:chest/util/auxiliar.dart';
import 'package:chest/util/helpers/feature.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

class CHESTMarker extends Marker {
  final bool visible;
  final Feature feature;
  final Widget icon;
  final BuildContext context;
  final Layers currentLayer;

  CHESTMarker(
    this.context, {
    required this.feature,
    required this.icon,
    this.visible = true,
    bool visibleLabel = true,
    this.currentLayer = Layers.carto,
    Function()? onTap,
  }) : super(
          point: feature.point,
          child: Visibility(
            visible: visible,
            child: InkWell(
              onTap: onTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: visibleLabel ? 36 : 52,
                    height: visibleLabel ? 36 : 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2),
                      color: Theme.of(context).colorScheme.primaryContainer,
                    ),
                    child: icon,
                  ),
                  visibleLabel
                      ? Container(
                          constraints: const BoxConstraints(maxWidth: 86),
                          padding: const EdgeInsets.all(2),
                          child: Text(
                            feature.labelLang(MyApp.currentLang) ??
                                feature.labelLang("en") ??
                                feature.labels.first.value,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.start,
                            style: currentLayer == Layers.carto
                                ? Theme.of(context)
                                    .textTheme
                                    .labelLarge!
                                    .copyWith(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    )
                                : Theme.of(context)
                                    .textTheme
                                    .labelLarge!
                                    .copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      const Shadow(
                                        color: Colors.black,
                                        offset: Offset(1, 0),
                                      ),
                                      const Shadow(
                                        color: Colors.black,
                                        offset: Offset(-1, 0),
                                      ),
                                      const Shadow(
                                        color: Colors.black,
                                        offset: Offset(0, 1),
                                      ),
                                      const Shadow(
                                        color: Colors.black,
                                        offset: Offset(0, -1),
                                      ),
                                    ],
                                  ),
                          ),
                        )
                      : Container(),
                ],
              ),
            ),
          ),
          height: visibleLabel ? 62 : 52,
          width: visibleLabel ? 122 : 52,
          alignment: Alignment.centerRight,
        );
}

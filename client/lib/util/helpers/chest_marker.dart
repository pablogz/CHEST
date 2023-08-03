import 'package:chest/main.dart';
import 'package:chest/util/helpers/pois.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

class CHESTMarker extends Marker {
  late bool visible;
  final POI poi;
  late Widget _icon;

  CHESTMarker(
      {required this.poi,
      required Widget icon,
      bool? visible,
      bool? visibleTooltip,
      double? height,
      double? width,
      Function()? onTap})
      : super(
          point: poi.point,
          builder: (context) {
            ColorScheme cS = Theme.of(context).colorScheme;
            return Visibility(
              visible: visible ?? true,
              child: Tooltip(
                message: visibleTooltip != null && visibleTooltip
                    ? poi.labelLang(MyApp.currentLang) ??
                        poi.labelLang("es") ??
                        poi.labels.first.value
                    : '',
                child: InkWell(
                  onTap: onTap,
                  child: Container(
                    width: width ?? 52,
                    height: height ?? 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: cS.primary, width: 2),
                      color: cS.primaryContainer,
                    ),
                    child: icon,
                  ),
                ),
              ),
            );
          },
          height: height ?? 52,
          width: width ?? 52,
        ) {
    _icon = icon;
  }
  Widget get icon => _icon;
}

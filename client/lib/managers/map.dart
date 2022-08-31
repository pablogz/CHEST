import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class MyMap extends StatefulWidget {
  const MyMap({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _MyMap();
}

class _MyMap extends State<MyMap> {
  int currentPageIndex = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        /*bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            currentIndex: 0,
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.map), label: "Mapa", tooltip: "Mapa"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.my_library_books_outlined),
                  label: "Answers",
                  tooltip: "Answers"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  label: "Perfil",
                  tooltip: "Perfil"),
            ]),*/
        bottomNavigationBar: NavigationBar(
          onDestinationSelected: (int index) {
            setState(() {
              currentPageIndex = index;
            });
          },
          selectedIndex: currentPageIndex,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              label: 'Mapa',
              tooltip: 'Mapa',
              selectedIcon: Icon(Icons.map),
            ),
            NavigationDestination(
                icon: Icon(Icons.my_library_books_outlined),
                selectedIcon: Icon(Icons.my_library_books),
                label: "Answers",
                tooltip: "Answers"),
            NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: "Perfil",
                tooltip: "Perfil"),
          ],
        ),
        body: [
          FlutterMap(
              options: MapOptions(
                  maxZoom: 20,
                  minZoom: 12,
                  /*bounds: LatLngBounds(
                      LatLng(41.68, -4.7621), LatLng(41.605, -4.7028)),
                  boundsOptions:
                      const FitBoundsOptions(padding: EdgeInsets.all(10)),*/
                  center: LatLng(41.6529, -4.72839),
                  zoom: 15.0,
                  interactiveFlags: InteractiveFlag.pinchZoom |
                      InteractiveFlag.doubleTapZoom |
                      InteractiveFlag.drag |
                      InteractiveFlag.pinchMove,
                  enableScrollWheel: false,
                  //onPositionChanged: (mapPos, vF) => funIni(mapPos, vF),
                  pinchZoomThreshold: 2.0,
                  plugins: [
                    MarkerClusterPlugin(),
                  ]),
              children: [
                TileLayerWidget(
                    options: TileLayerOptions(
                  minZoom: 1,
                  maxZoom: 20,
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: ['a', 'b', 'c'],
                  backgroundColor: Colors.grey,
                )),
                AttributionWidget(
                  attributionBuilder: (context) {
                    return ColoredBox(
                        color: Colors.white30,
                        child: Padding(
                            padding: const EdgeInsets.all(1),
                            child: Text(
                              AppLocalizations.of(context)!.atribucionMapa,
                              style: const TextStyle(fontSize: 12),
                            )));
                  },
                )
              ]),
          Container(
            color: Colors.green,
            alignment: Alignment.center,
            child: const Text('Page 2'),
          ),
          Container(
            color: Colors.blue,
            alignment: Alignment.center,
            child: const Text('Page 3'),
          )
        ][currentPageIndex]);
  }
}

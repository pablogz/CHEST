import 'dart:html';
import 'dart:io';

import 'package:chest/util/helpers/answers.dart';
import 'package:intl/intl.dart';
import 'package:mustache_template/mustache.dart';
import 'package:uuid/uuid.dart';

class AuxiliarFunctions {
  static const String _idUGuestUser = "";

  static void downloadAnswerWeb(Answer answer, {String titlePage = 'CHEST'}) {
    Blob contenido = Blob([
      Template(
              '<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>{{{titlePage}}}</title><link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/css/bootstrap.min.css" rel="stylesheet"integrity="sha384-GLhlTQ8iRABdZLl6O3oVMWSktQOp6b7In1Zl3/Jr59b6EGGoI1aFkw7cmDA6j6gD" crossorigin="anonymous"><link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin><link href="https://fonts.googleapis.com/css2?family=Open+Sans&display=swap" rel="stylesheet"><link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.3/dist/leaflet.css"integrity="sha256-kLaT2GOSpHechhsozzB+flnD+zUyjE2LlfWPgU04xyI=" crossorigin="" /><style>body {font-family: "Open Sans", sans-serif;font-display: swap;}nav {background-color: #673AB7;}#map {height: 180px;width: 100%;}</style></head><body><nav class="navbar sticky-top" data-bs-theme="dark"><div class="container-fluid"><span class="navbar-brand mb-0">{{{titlePage}}}</span></div></nav><div class="container mt-4"><p class="display-6 text-center">{{{labelPoi}}}</p><div class="card mt-3" id="map"></div><p class="mt-3 px-2">{{{commentTask}}}</p><hr class="mt-3 mx-5"></div><div class="container mt-4"><figure class="text-end"><blockquote class="blockquote"><p>{{{answer}}}</p></blockquote><figcaption class="blockquote-footer">{{{date}}}</figcaption></figure></div><script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/js/bootstrap.bundle.min.js"integrity="sha384-w76AqPfDkMBDXo30jS1Sgez6pr3x5MlQ1ZAGC+nuZB+EYdgRZgiwxhTBTkF7CXvN"crossorigin="anonymous"></script><script src="https://unpkg.com/leaflet@1.9.3/dist/leaflet.js"integrity="sha256-WBkoXOwTeyKclOHuWtc+i2uENFpDZ9YPdf5Hf+D7ewM=" crossorigin=""></script><script>var map = L.map("map", {boxZoom: false,scrollWheelZoom: false,touchZoom: false,tapHold: false,dragging: false,zoomControl: false,}).setView([{{{lat}}}, {{{long}}}], 17);L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {minZoom: 17,maxZoom: 17,attribution: "&copy; <a href=\\"https://www.openstreetmap.org/copyright\\">OpenStreetMap</a>s",}).addTo(map);L.circle([{{{lat}}}, {{{long}}}], {color: "#673AB7",fillColor: "#673AB7",fillOpacity: 0.3,radius: 36}).addTo(map);</script></body></html>')
          .renderString({
        'lat': answer.poi.lat,
        'long': answer.poi.long,
        'titlePage': titlePage,
        'labelPoi': answer.hasLabelPoi ? answer.labelPoi : 'Feature',
        'commentTask':
            answer.hasCommentTask ? answer.commentTask : 'Comment Task',
        'answer': Template("{{{answer}}}{{{extraAnswer}}}").renderString({
          'answer': answer.answer['answer'],
          'extraAnswer':
              answer.hasExtraText ? '. ${answer.answer["extraText"]}' : '.'
        }),
        'date': DateFormat('H:mm d/M/y').format(
            DateTime.fromMillisecondsSinceEpoch(answer.answer['timestamp']))
      })
    ], 'text/html', 'native');
    // https://stackoverflow.com/a/63842948
    AnchorElement(href: Url.createObjectUrlFromBlob(contenido))
      ..setAttribute(
          'download', 'CHEST-${DateTime.now().millisecondsSinceEpoch}')
      ..click();
  }

  static String getIdUser() {
    String? cookies = document.cookie;
    if (cookies != null) {
      List<String> lstCookies = cookies.split(";");
      for (String cookie in lstCookies) {
        if (cookie.contains("idUserChest")) {
          return cookie.split("=")[1].trim();
        }
      }
    }
    String newId = const Uuid().v4();
    if (cookies == null) {
      document.cookie = "idUserChest=$newId";
    } else {
      document.cookie = document.cookie!.isEmpty
          ? "idUserChest=$newId"
          : "${document.cookie}; idUserChest=$newId";
    }
    return newId;
  }

  static Future<bool> writeFile(
          {required String fileName,
          required String toFile,
          FileMode mode = FileMode.write}) async =>
      false;
  static Future<String?> readFile({required String fileName}) async => null;
}

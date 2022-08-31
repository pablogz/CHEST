import 'package:flutter/material.dart';

class Auxiliar {
  //Acentos en mac: https://github.com/flutter/flutter/issues/75510#issuecomment-861997917
  static void checkAccents(
      String input, TextEditingController textEditingController) {
    if (input.contains('´a') ||
        input.contains('´A') ||
        input.contains('´e') ||
        input.contains('´E') ||
        input.contains('´i') ||
        input.contains('´I') ||
        input.contains('´o') ||
        input.contains('´O') ||
        input.contains('´u') ||
        input.contains('´U')) {
      textEditingController.text = input
          .replaceAll('´a', 'á')
          .replaceAll('´A', 'Á')
          .replaceAll('´e', 'é')
          .replaceAll('´E', 'É')
          .replaceAll('´i', 'í')
          .replaceAll('´I', 'Í')
          .replaceAll('´o', 'ó')
          .replaceAll('´O', 'ó')
          .replaceAll('´u', 'ú')
          .replaceAll('´U', 'Ú');
      textEditingController.selection = TextSelection.fromPosition(
          TextPosition(offset: textEditingController.text.length));
    }
  }

  //https://www.w3resource.com/javascript/form/email-validation.php
  static bool validMail(String text) =>
      RegExp(r"^\w+([\.-]?\w+)*@\w+([\.-]?\w+)*(\.\w{2,3})+$")
          .hasMatch(text.trim());
}

class PairLang {
  late String _lang;
  final String _value;
  PairLang(this._lang, this._value);

  PairLang.withoutLang(this._value) {
    _lang = "";
  }

  bool get hasLang => _lang.isNotEmpty;
  String get lang => _lang;
  String get value => _value;
}

class Category {
  final String _iri;
  late List<PairLang> _label;
  late List<String> _broader;
  Category(this._iri, label, broader) {
    _label = [];
    if (label is String || label is Map || label is List) {
      if (label is String) {
        _label.add(PairLang.withoutLang(label));
      } else {
        if (label is Map) {
          label.forEach((key, value) => _label.add(PairLang(key, value)));
        } else {
          for (Map<String, String> l in label) {
            l.forEach(
                (String key, String value) => _label.add(PairLang(key, value)));
          }
        }
      }
    } else {
      throw Exception("Problem with label");
    }
    if (broader is List) {
      _broader = [...broader];
    } else {
      _broader = [broader.toString()];
    }
  }

  String get iri => _iri;
  List<PairLang> get label => _label;
  List<String> get broader => _broader;
}

class PairImage {
  late final String _image;
  String _license = "";
  late bool hasLicense;
  PairImage(image, this._license) {
    _image = image.replaceFirst('http://', 'https://');
    hasLicense = (_license.trim().isNotEmpty);
  }

  PairImage.withoutLicense(image) {
    _image = image.replaceFirst('http://', 'https://');
    hasLicense = false;
  }

  String get image => _image;
  String get license => _license;
}

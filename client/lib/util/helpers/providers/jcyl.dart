import 'package:chest/util/helpers/pair.dart';

class JCyL {
  final String provider = 'jcyl';
  late String _id, _shortId, _url, _license;
  late PairLang _label, _description;
  PairLang? _altLabel;
  late ElementLabels _category;

  JCyL(Map<String, dynamic>? data) {
    try {
      if (data == null) {
        throw Exception('Problem with data: it\'s null!! Wikidata constructor');
      } else {
        if (data.containsKey('id')) {
          _id = data['id'].toString();
        } else {
          throw Exception('Problem with id in Wikidata constructor');
        }
        if (data.containsKey('shortId')) {
          _shortId = data['shortId'].toString();
        } else {
          throw Exception('Problem with shortId in Wikidata constructor');
        }
        if (data.containsKey('url')) {
          _url = data['url'].toString();
        } else {
          throw Exception('Problem with url in Wikidata constructor');
        }
        if (data.containsKey('license')) {
          _license = data['license'].toString();
        } else {
          throw Exception('Problem with license in Wikidata constructor');
        }
        List<String> labelDescription = ['label', 'comment'];
        for (String key in labelDescription) {
          if (data.containsKey(key) &&
              data[key] is Map &&
              data[key].containsKey('value') &&
              data[key].containsKey('lang')) {
            if (key == 'label') {
              _label = PairLang('es', data[key]['value']);
            } else {
              _description = PairLang('es', data[key]['value']);
            }
          } else {
            throw Exception('Problem with $key in Wikidata constructor');
          }
        }

        if (data.containsKey('altLabel') &&
            data['altLabel'] is Map &&
            data['altLabel'].containsKey('value') &&
            data['altLabel'].containsKey('lang')) {
          _label = PairLang('es', data['altLabel']['value']);
        }

        if (data.containsKey('category') && data.containsKey('categoryLabel')) {
          _category = ElementLabels(data['category'], [data['categoryLabel']]);
        } else {
          throw Exception('Problem with category in Wikidata constructor');
        }
      }
    } catch (error) {
      throw Exception(error);
    }
  }

  String get id => _id;
  String get shortId => _shortId;
  String get url => _url;
  String get license => _license;
  PairLang get label => _label;
  PairLang get description => _description;
  PairLang? get altLabel => _altLabel;
  ElementLabels get category => _category;
  String get textProvider => "JCyL";

  Map<String, dynamic> toSourceInfo() {
    Map<String, dynamic> out = {
      'id': id,
      'shortId': shortId,
      'url': url,
      'license': license,
      'label': label.toMap(),
      'description': description.toMap(),
      'category': category.toMap()
    };

    if (altLabel != null) {
      out['latLabel'] = altLabel!.toMap();
    }

    return out;
  }
}

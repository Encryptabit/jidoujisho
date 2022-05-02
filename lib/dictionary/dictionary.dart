import 'dart:convert';

class Dictionary {
  Dictionary({
    required this.dictionaryName,
    required this.formatName,
    required this.metadata,
  });

  /// The name of the dictionary. For example, this could be "Merriam-Webster
  /// Dictionary" or "大辞林" or "JMdict".
  ///
  /// Dictionary names are meant to be unique, meaning two dictionaries of the
  /// same name should not be allowed to be added in the database. The
  /// database will also effectively use this dictionary name as a directory
  /// prefix.
  final String dictionaryName;

  /// The format that the dictionary was sourced from.
  final String formatName;

  /// The metadata pertaining to this dictionary from import. Used for
  /// format-specific enhancements.
  final Map<String, String> metadata;

  /// Get a serialised representation of the dictionary search result
  /// for history and persistence purposes.
  String toJson() {
    Map<String, String> map = {
      'dictionaryName': dictionaryName,
      'formatName': formatName,
      'metadata': jsonEncode(metadata),
    };

    return jsonEncode(map);
  }

  factory Dictionary.fromJson(String json) {
    Map<String, String> map = Map.castFrom(jsonDecode(json));

    return Dictionary(
      dictionaryName: map['dictionaryName']!,
      formatName: map['formatName']!,
      metadata: Map.castFrom(
        jsonDecode(map['metadata']!),
      ),
    );
  }
}

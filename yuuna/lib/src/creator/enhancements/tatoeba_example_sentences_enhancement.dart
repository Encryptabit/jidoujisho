import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuuna/creator.dart';
import 'package:yuuna/language.dart';
import 'package:yuuna/models.dart';
import 'package:http/http.dart' as http;

/// An enhancement used to fetch example sentences via Tatoeba.
class TatoebaExampleSentencesEnhancement extends Enhancement {
  /// Initialise this enhancement with the hardset parameters.
  TatoebaExampleSentencesEnhancement()
      : super(
          uniqueKey: key,
          label: 'Tatoeba Example Sentences',
          description: 'Pick example phrases and sentences from Tatoeba.',
          icon: Icons.article_outlined,
          field: TermField.instance,
        );

  /// Used to identify this enhancement and to allow a constant value for the
  /// default mappings value of [AnkiMapping].
  static const String key = 'tatoeba_example_sentences';

  /// Used to store results that have already been found at runtime.
  final Map<String, List<String>> _tatoebaCache = {};

  /// Client used to communicate with Tatoeba.
  final http.Client _client = http.Client();

  @override
  Future<void> enhanceCreatorParams({
    required BuildContext context,
    required WidgetRef ref,
    required AppModel appModel,
    required CreatorModel creatorModel,
    required EnhancementTriggerCause cause,
  }) async {
    String searchTerm = creatorModel.getFieldController(field).text;

    List<String> exampleSentences = await searchForSentences(
      context: context,
      appModel: appModel,
      searchTerm: searchTerm,
    );

    appModel.openExampleSentenceDialog(
      exampleSentences: exampleSentences,
      onSelect: (selection) {
        if (selection.isEmpty) {
          return;
        }

        creatorModel.getFieldController(SentenceField.instance).text =
            selection.join('\n\n');
      },
      onAppend: (selection) {
        if (selection.isEmpty) {
          return;
        }

        String currentSentence =
            creatorModel.getFieldController(SentenceField.instance).text;

        creatorModel.getFieldController(SentenceField.instance).text =
            '${currentSentence.trim()}\n\n${selection.join('\n\n')}'.trim();
      },
    );
  }

  /// Search Tatoeba for example sentences and return a list of results.
  Future<List<String>> searchForSentences({
    required BuildContext context,
    required AppModel appModel,
    required String searchTerm,
  }) async {
    if (searchTerm.trim().isEmpty) {
      return [];
    }

    late String langCode;
    Language language = appModel.targetLanguage;
    // Language Customizable
    if (language is JapaneseLanguage) {
      langCode = 'jpn';
    } else if (language is EnglishLanguage) {
      langCode = 'eng';
    } else {
      throw UnimplementedError('This language is not implemented for Tatoeba');
    }

    String cacheKey = '$langCode/$searchTerm';

    if (_tatoebaCache[cacheKey] != null) {
      return _tatoebaCache[cacheKey]!;
    }

    List<String> sentences = [];

    http.Response response = await _client.get(Uri.parse(
        'https://tatoeba.org/en/api_v0/search?from=$langCode&has_audio=&native=&orphans=no&query=${Uri.encodeComponent(searchTerm)}&sort=relevance&sort_reverse=&tags=&to=none&trans_filter=limit&trans_has_audio=&trans_link=&trans_orphan=&trans_to=&trans_unapproved=&trans_user=&unapproved=no&user='));

    Map<String, dynamic> json = jsonDecode(response.body);
    List<Map<String, dynamic>> results =
        List<Map<String, dynamic>>.from(json['results']);

    sentences = results.map((result) => result['text'].toString()).toList();
    _tatoebaCache[cacheKey] = sentences;

    return sentences;
  }
}

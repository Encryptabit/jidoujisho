import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuuna/creator.dart';
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/models.dart';

/// An enhancement used as a shortcut for adding text items to the Stash.
class AddToStashAction extends QuickAction {
  /// Initialise this enhancement with the hardset parameters.
  AddToStashAction()
      : super(
          uniqueKey: key,
          label: 'Add To Stash',
          description:
              'Quickly save the headword of a dictionary entry to the Stash.',
          icon: Icons.bookmark_add,
        );

  /// Used to identify this enhancement and to allow a constant value for the
  /// default mappings value of [AnkiMapping].
  static const String key = 'add_to_stash';

  @override
  Color getIconColor({
    required BuildContext context,
    required AppModel appModel,
    required DictionaryTerm dictionaryTerm,
  }) {
    if (appModel.isTermInStash(dictionaryTerm.term)) {
      return Theme.of(context).colorScheme.primary;
    } else {
      return super.getIconColor(
        context: context,
        appModel: appModel,
        dictionaryTerm: dictionaryTerm,
      );
    }
  }

  @override
  Future<void> executeAction({
    required BuildContext context,
    required WidgetRef ref,
    required AppModel appModel,
    required CreatorModel creatorModel,
    required DictionaryTerm dictionaryTerm,
    required List<DictionaryMetaEntry> metaEntries,
  }) async {
    if (!appModel.isTermInStash(dictionaryTerm.term)) {
      appModel.addToStash(terms: [dictionaryTerm.term]);
    } else {
      appModel.removeFromStash(term: dictionaryTerm.term);
    }
  }
}

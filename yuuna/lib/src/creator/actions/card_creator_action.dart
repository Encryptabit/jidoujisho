import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuuna/creator.dart';
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/models.dart';
import 'package:yuuna/pages.dart';

/// An enhancement used effectively as a shortcut for opening the Card Creator.
class CardCreatorAction extends QuickAction {
  /// Initialise this enhancement with the hardset parameters.
  CardCreatorAction()
      : super(
          uniqueKey: key,
          label: 'Card Creator',
          description:
              'Create a card with the selected dictionary entry parameters and'
              ' edit before export.',
          icon: Icons.note_add,
        );

  /// Used to identify this enhancement and to allow a constant value for the
  /// default mappings value of [AnkiMapping].
  static const String key = 'card_creator';

  @override
  Future<void> executeAction({
    required BuildContext context,
    required WidgetRef ref,
    required AppModel appModel,
    required CreatorModel creatorModel,
    required DictionaryTerm dictionaryTerm,
    required List<DictionaryMetaEntry> metaEntries,
  }) async {
    if (appModel.isMediaOpen) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await Future.delayed(const Duration(milliseconds: 5), () {});
    }

    if (appModel.isCreatorOpen) {
      Map<Field, String> newTextFields = {};
      for (Field field in appModel.activeFields) {
        String? newTextField = field.onCreatorOpenAction(
          context: context,
          ref: ref,
          appModel: appModel,
          creatorModel: creatorModel,
          dictionaryTerm: dictionaryTerm,
          metaEntries: metaEntries,
          creatorJustLaunched: false,
        );

        if (newTextField != null) {
          newTextFields[field] = newTextField;
        }
      }

      creatorModel.copyContext(
        CreatorFieldValues(textValues: newTextFields),
      );

      for (Field field in appModel.activeFields) {
        Enhancement? enhancement = appModel.lastSelectedMapping
            .getAutoFieldEnhancement(appModel: appModel, field: field);

        if (enhancement != null) {
          enhancement.enhanceCreatorParams(
            context: context,
            ref: ref,
            appModel: appModel,
            creatorModel: creatorModel,
            cause: EnhancementTriggerCause.auto,
          );
        }
      }

      Navigator.of(context).popUntil(
        (route) => route.settings.name == (CreatorPage).toString(),
      );
    } else {
      Map<Field, String> newTextFields = {};
      for (Field field in appModel.activeFields) {
        String? newTextField = field.onCreatorOpenAction(
          context: context,
          ref: ref,
          appModel: appModel,
          creatorModel: creatorModel,
          dictionaryTerm: dictionaryTerm,
          metaEntries: metaEntries,
          creatorJustLaunched: true,
        );

        if (newTextField != null) {
          newTextFields[field] = newTextField;
        }
      }

      await appModel.openCreator(
        ref: ref,
        killOnPop: false,
        creatorFieldValues: CreatorFieldValues(textValues: newTextFields),
      );

      if (appModel.isMediaOpen) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    }
  }
}

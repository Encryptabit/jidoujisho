import 'dart:math';

import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:spaces/spaces.dart';
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// Returns the widget for a [DictionaryEntry] making up a collection of
/// meanings.
class DictionaryEntryPage extends BasePage {
  /// Create the widget for a dictionary entry.
  const DictionaryEntryPage({
    required this.entry,
    required this.meaningTags,
    required this.onSearch,
    required this.onStash,
    required this.expandableController,
    super.key,
  });

  /// The entry particular to this widget.
  final DictionaryEntry entry;

  /// Meaning tags particular to this widget.
  final List<DictionaryTag> meaningTags;

  /// Action to be done upon selecting the search option.
  final Function(String) onSearch;

  /// Action to be done upon selecting the stash option.
  final Function(String) onStash;

  /// Controller specific to a dictionary name.
  final ExpandableController expandableController;

  @override
  BasePageState<DictionaryEntryPage> createState() =>
      _DictionaryEntryPageState();
}

class _DictionaryEntryPageState extends BasePageState<DictionaryEntryPage> {
  String get dictionaryImportTag =>
      appModelNoUpdate.translate('dictionary_import_tag');

  @override
  JidoujishoTextSelectionControls get selectionControls =>
      JidoujishoTextSelectionControls(
        searchAction: widget.onSearch,
        searchActionLabel: searchLabel,
        stashAction: widget.onStash,
        stashActionLabel: stashLabel,
        allowCopy: true,
        allowSelectAll: true,
        allowCut: true,
        allowPaste: true,
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: Spacing.of(context).spaces.extraSmall,
        bottom: Spacing.of(context).spaces.normal,
      ),
      child: ExpandablePanel(
        theme: ExpandableThemeData(
          iconPadding: EdgeInsets.zero,
          iconSize: Theme.of(context).textTheme.titleLarge?.fontSize,
          expandIcon: Icons.arrow_drop_down,
          collapseIcon: Icons.arrow_drop_up,
          iconColor: Theme.of(context).unselectedWidgetColor,
          headerAlignment: ExpandablePanelHeaderAlignment.center,
        ),
        controller: widget.expandableController,
        header: Wrap(children: getTagsForEntry()),
        collapsed: const SizedBox.shrink(),
        expanded: Padding(
          padding: EdgeInsets.only(
            top: Spacing.of(context).spaces.small,
            left: Spacing.of(context).spaces.normal,
          ),
          child: ListView.builder(
            cacheExtent: 99999999999999,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            primary: false,
            itemCount: widget.entry.meanings.length,
            itemBuilder: (context, index) {
              String sourceText = widget.entry.meanings.length != 1
                  ? '• ${widget.entry.meanings[index].trim()}'
                  : widget.entry.meanings.first.trim();

              final SelectableTextController _selectableTextController =
                  SelectableTextController();

              return SelectableText(
                sourceText,
                controller: _selectableTextController,
                style: TextStyle(fontSize: appModel.dictionaryFontSize),
                selectionControls: selectionControls,
                onSelectionChanged: (selection, cause) {
                  if (!selection.isCollapsed &&
                      cause == SelectionChangedCause.tap) {
                    String text = sourceText.substring(selection.baseOffset);

                    bool isSpaceDelimited =
                        appModel.targetLanguage.isSpaceDelimited;
                    int whitespaceOffset = text.length - text.trimLeft().length;
                    int offsetIndex = selection.baseOffset + whitespaceOffset;
                    int length = appModel.targetLanguage
                        .textToWords(text)
                        .firstWhere((e) => e.trim().isNotEmpty)
                        .length;

                    _selectableTextController.setSelection(
                      offsetIndex,
                      offsetIndex + length,
                    );

                    appModel.searchDictionary(text).then((result) {
                      int length = isSpaceDelimited
                          ? appModel.targetLanguage
                              .textToWords(text)
                              .firstWhere((e) => e.trim().isNotEmpty)
                              .length
                          : max(1, result.bestLength);

                      _selectableTextController.setSelection(
                          offsetIndex, offsetIndex + length);
                    });
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  /// Fetches the tag widgets for a [DictionaryEntry].
  List<Widget> getTagsForEntry() {
    String dictionaryImportTag = appModel.translate('dictionary_import_tag');

    List<Widget> tagWidgets = [];

    tagWidgets.add(
      JidoujishoTag(
        text: widget.entry.dictionaryName,
        message: dictionaryImportTag.replaceAll(
          '%dictionaryName%',
          widget.entry.dictionaryName,
        ),
        backgroundColor: Colors.red.shade900,
      ),
    );

    tagWidgets.addAll(widget.meaningTags.map((tag) {
      return JidoujishoTag(
        text: tag.name,
        message: tag.notes,
        backgroundColor: tag.color,
      );
    }).toList());

    return tagWidgets;
  }
}

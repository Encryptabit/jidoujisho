import 'dart:ui';

import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:spaces/spaces.dart';
import 'package:subtitle/subtitle.dart';
import 'package:yuuna/creator.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';
import 'package:yuuna/models.dart';

/// The page used for the Card Creator to modify a note before export. Relies
/// on the [CreatorModel].
class CreatorPage extends BasePage {
  /// Construct an instance of the [HomePage].
  const CreatorPage({
    required this.decks,
    required this.editEnhancements,
    required this.editFields,
    required this.killOnPop,
    required this.subtitles,
    super.key,
  });

  /// List of decks that are fetched prior to navigating to this page.
  final List<String> decks;

  /// Whether or not the creator page allows editing of set enhancements.
  final bool editEnhancements;

  /// Whether or not the creator page allows editing of set fields.
  final bool editFields;

  /// If true, popping will exit the application.
  final bool killOnPop;

  /// Used to generate multiple images if required and invoked from a
  /// media source. See [MediaSource.generateImages].
  final List<Subtitle>? subtitles;

  @override
  BasePageState<CreatorPage> createState() => _CreatorPageState();
}

class _CreatorPageState extends BasePageState<CreatorPage> {
  String get creatorExportingAsLabel =>
      appModel.translate('creator_exporting_as');
  String get creatorExportingAsEditingEnhancementsLabel =>
      appModel.translate('creator_exporting_as_enhancements_editing');
  String get creatorExportingAsEditingFieldsLabel =>
      appModel.translate('creator_exporting_as_fields_editing');
  String get infoEnhancementsLabel => appModel.translate('info_enhancements');
  String get infoFieldsLabel => appModel.translate('info_fields');
  String get creatorExportCard => appModel.translate('creator_export_card');
  String get assignManualEnhancementLabel =>
      appModel.translate('assign_manual_enhancement');
  String get assignAutoEnhancementLabel =>
      appModel.translate('assign_auto_enhancement');
  String get removeField => appModel.translate('remove_field');
  String get addField => appModel.translate('add_field');
  String get addFieldHint => appModel.translate('add_field_hint');
  String get hiddenFields => appModel.translate('hidden_fields');
  String get removeEnhancementLabel => appModel.translate('remove_enhancement');
  String get editActionsLabel => appModel.translate('edit_actions');
  String get backLabel => appModel.translate('back');
  String get clearCreatorTitle => appModel.translate('clear_creator_title');
  String get clearCreatorDescription =>
      appModel.translate('clear_creator_description');
  String get dialogClearLabel => appModel.translate('dialog_clear');
  String get dialogCancelLabel => appModel.translate('dialog_cancel');
  String get editFieldsLabel => appModel.translate('edit_fields');
  String get closeOnExportLabel => appModel.translate('close_on_export');
  String get closeOnExportOnToast => appModel.translate('close_on_export_on');
  String get closeOnExportOffToast => appModel.translate('close_on_export_off');

  bool get isCardEditing => !widget.editEnhancements && !widget.editFields;

  /// Get the export details pertaining to the fields.
  CreatorFieldValues get exportDetails => creatorModel.getExportDetails(ref);

  Future<bool> onWillPop() async {
    if (isCardEditing) {
      creatorModel.clearAll();
    }

    if (widget.killOnPop) {
      FlutterExitApp.exitApp();
      return false;
    }

    return true;
  }

  Color get activeButtonColor =>
      Theme.of(context).unselectedWidgetColor.withOpacity(0.1);
  Color get inactiveButtonColor =>
      Theme.of(context).unselectedWidgetColor.withOpacity(0.05);
  Color get activeTextColor => Theme.of(context).appBarTheme.foregroundColor!;
  Color get inactiveTextColor => Theme.of(context).unselectedWidgetColor;

  /// For controlling collapsed fields.
  late final ExpandableController expandableController;

  bool _creatorInitialised = false;

  @override
  void initState() {
    super.initState();

    expandableController =
        ExpandableController(initialExpanded: !isCardEditing);
  }

  Future<void> initialiseCreator() async {
    appModel.validateSelectedMapping(
      context: context,
      mapping: appModel.lastSelectedMapping,
    );

    for (Field field in appModel.activeFields) {
      /// If a media source has a generate images or audio function, then use that
      /// over any set auto enhancement.
      if (appModel.isMediaOpen && appModel.getCurrentMediaItem() != null) {
        MediaSource mediaSource =
            appModel.getCurrentMediaItem()!.getMediaSource(appModel: appModel);
        if (field is ImageField && mediaSource.overridesAutoImage) {
          await field.setImages(
            appModel: appModel,
            creatorModel: creatorModel,
            searchTerm: '',
            newAutoCannotOverride: true,
            cause: EnhancementTriggerCause.manual,
            generateImages: () async {
              return mediaSource.generateImages(
                appModel: appModel,
                item: appModel.getCurrentMediaItem()!,
                subtitles: widget.subtitles,
                options: appModel.currentSubtitleOptions!.value,
              );
            },
          );
          continue;
        }
        if (field is AudioSentenceField && mediaSource.overridesAutoAudio) {
          await field.setAudio(
            appModel: appModel,
            creatorModel: creatorModel,
            searchTerm: '',
            newAutoCannotOverride: true,
            cause: EnhancementTriggerCause.manual,
            generateAudio: () async {
              return mediaSource.generateAudio(
                appModel: appModel,
                item: appModel.getCurrentMediaItem()!,
                subtitles: widget.subtitles,
                options: appModel.currentSubtitleOptions!.value,
              );
            },
          );
          continue;
        }
      }

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
  }

  @override
  Widget build(BuildContext context) {
    if (!_creatorInitialised && isCardEditing) {
      _creatorInitialised = true;
      initialiseCreator();
    }

    return WillPopScope(
      onWillPop: onWillPop,
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Stack(
          children: [
            buildBlur(),
            buildScaffold(),
          ],
        ),
      ),
    );
  }

  Widget buildBlur() {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
      child: Container(),
    );
  }

  AppBar buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      leading: buildBackButton(),
      title: buildTitle(),
      actions: buildActions(),
      titleSpacing: 8,
    );
  }

  Widget buildTutorialMessage() {
    return ListTile(
      dense: true,
      title: Text.rich(
        TextSpan(
          text: '',
          children: <InlineSpan>[
            WidgetSpan(
              child: Icon(
                Icons.info,
                size: textTheme.bodySmall?.fontSize,
              ),
            ),
            const WidgetSpan(
              child: SizedBox(width: 8),
            ),
            TextSpan(
              text: widget.editEnhancements
                  ? infoEnhancementsLabel
                  : infoFieldsLabel,
              style: TextStyle(
                fontSize: textTheme.bodySmall?.fontSize,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.justify,
      ),
    );
  }

  Widget buildCollapsableHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: Spacing.of(context).spaces.normal,
        horizontal: Spacing.of(context).spaces.small,
      ),
      child: Row(
        children: [
          Icon(Icons.edit_note,
              color: Theme.of(context).unselectedWidgetColor,
              size: textTheme.labelLarge?.fontSize),
          const Space.semiSmall(),
          Text(
            hiddenFields,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).unselectedWidgetColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildExpandablePanel() {
    if (!widget.editFields &&
        appModel.lastSelectedMapping.creatorCollapsedFieldKeys.isEmpty) {
      return const SizedBox.shrink();
    }

    return ExpandablePanel(
      theme: ExpandableThemeData(
        iconPadding: Spacing.of(context).insets.onlyRight.small,
        iconSize: Theme.of(context).textTheme.titleLarge?.fontSize,
        expandIcon: Icons.arrow_drop_down,
        collapseIcon: Icons.arrow_drop_up,
        iconColor: Theme.of(context).unselectedWidgetColor,
        headerAlignment: ExpandablePanelHeaderAlignment.center,
      ),
      controller: expandableController,
      header: buildCollapsableHeader(),
      collapsed: const SizedBox.shrink(),
      expanded: buildCollapsedTextFields(),
    );
  }

  Future<void> exportCard() async {
    await appModel.addNote(
      creatorFieldValues: creatorModel.getExportDetails(ref),
      mapping: appModel.lastSelectedMapping,
      deck: appModel.lastSelectedDeckName,
      onSuccess: () {
        creatorModel.clearAll();

        if (appModel.closeCreatorOnExport) {
          Navigator.pop(context);
        }
      },
    );
  }

  Widget buildExportButton() {
    late bool isExportable;
    if (widget.editEnhancements) {
      isExportable = false;
    } else {
      isExportable = exportDetails.isExportable;
    }

    return Padding(
      padding: Spacing.of(context).insets.all.normal,
      child: InkWell(
        onTap: isExportable ? exportCard : null,
        child: Container(
          padding: Spacing.of(context).insets.vertical.normal,
          alignment: Alignment.center,
          width: double.infinity,
          color: isExportable ? activeButtonColor : inactiveButtonColor,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.note_add,
                size: textTheme.titleSmall?.fontSize,
                color: isExportable ? activeTextColor : inactiveTextColor,
              ),
              const Space.small(),
              Text(
                creatorExportCard,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isExportable ? activeTextColor : inactiveTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildEditActionsButton() {
    return Padding(
      padding: Spacing.of(context).insets.all.normal,
      child: InkWell(
        onTap: showQuickActionsPage,
        child: Container(
          padding: Spacing.of(context).insets.vertical.normal,
          alignment: Alignment.center,
          width: double.infinity,
          color: activeButtonColor,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.electric_bolt,
                size: textTheme.titleSmall?.fontSize,
                color: activeTextColor,
              ),
              const Space.small(),
              Text(
                editActionsLabel,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: activeTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildEditFieldsButton() {
    return Padding(
      padding: Spacing.of(context).insets.exceptBottom.normal,
      child: InkWell(
        onTap: () async {
          await appModel.openCreatorFieldsEditor();
          setState(() {});
        },
        child: Container(
          padding: Spacing.of(context).insets.vertical.normal,
          alignment: Alignment.center,
          width: double.infinity,
          color: activeButtonColor,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.edit,
                size: textTheme.titleSmall?.fontSize,
                color: activeTextColor,
              ),
              const Space.small(),
              Text(
                editFieldsLabel,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: activeTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showQuickActionsPage() {
    showDialog(
      context: context,
      builder: (context) => const CreatorQuickActionsPage(),
    );
  }

  Widget buildScaffold() {
    bool showPortrait = (appModel.activeFields.contains(ImageField.instance) &&
            !ImageField.instance.showWidget &&
            !ImageField.instance.isSearching) ||
        MediaQuery.of(context).orientation == Orientation.portrait ||
        widget.editEnhancements ||
        widget.editFields ||
        !appModel.activeFields.contains(ImageField.instance);

    return Scaffold(
      backgroundColor:
          theme.backgroundColor.withOpacity(isCardEditing ? 0.5 : 1),
      key: _scaffoldKey,
      resizeToAvoidBottomInset: true,
      appBar: showPortrait ? buildAppBar() : null,
      body: showPortrait ? buildPortrait() : buildLandscape(),
    );
  }

  Widget buildLandscape() {
    return SafeArea(
      top: false,
      child: Row(
        children: [
          Flexible(
            flex: 3,
            child: Column(
              children: [
                buildAppBar(),
                const Space.semiBig(),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (appModel.activeFields.contains(ImageField.instance))
                        Expanded(
                          child: ImageField.instance.buildTopWidget(
                            context: context,
                            ref: ref,
                            appModel: appModel,
                            creatorModel: creatorModel,
                            orientation: Orientation.landscape,
                          ),
                        ),
                      if (appModel.activeFields.contains(AudioField.instance))
                        AudioField.instance.buildTopWidget(
                          context: context,
                          ref: ref,
                          appModel: appModel,
                          creatorModel: creatorModel,
                          orientation: Orientation.landscape,
                        ),
                      if (appModel.activeFields
                          .contains(AudioSentenceField.instance))
                        AudioSentenceField.instance.buildTopWidget(
                          context: context,
                          ref: ref,
                          appModel: appModel,
                          creatorModel: creatorModel,
                          orientation: Orientation.landscape,
                        ),
                    ],
                  ),
                ),
                buildDeckDropdown(),
                const Space.small(),
              ],
            ),
          ),
          Flexible(
            flex: 4,
            child: Column(
              children: [
                Expanded(child: buildFields(isPortrait: false)),
                if (widget.editEnhancements) buildEditFieldsButton(),
                if (widget.editEnhancements) buildEditActionsButton(),
                if (isCardEditing) buildExportButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPortrait() {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(child: buildFields(isPortrait: true)),
          if (widget.editEnhancements) buildEditFieldsButton(),
          if (widget.editEnhancements) buildEditActionsButton(),
          if (isCardEditing) buildExportButton(),
        ],
      ),
    );
  }

  final ScrollController _scrollController = ScrollController();

  Widget buildFields({required bool isPortrait}) {
    return RawScrollbar(
      thickness: 3,
      thumbVisibility: true,
      controller: _scrollController,
      child: Padding(
        padding: Spacing.of(context).insets.horizontal.small,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          controller: _scrollController,
          children: [
            if (isCardEditing && isPortrait) buildTopWidgets(),
            if (!isCardEditing) buildTutorialMessage(),
            if (isCardEditing && isPortrait) buildDeckDropdown(),
            buildTextFields(),
            buildExpandablePanel(),
          ],
        ),
      ),
    );
  }

  Widget buildTopWidgets() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: appModel.activeFields.length,
      itemBuilder: (context, index) {
        Field field = appModel.activeFields[index];
        if (field is ImageExportField) {
          return field.buildTopWidget(
            context: context,
            ref: ref,
            appModel: appModel,
            creatorModel: creatorModel,
            orientation: Orientation.portrait,
          );
        } else if (field is AudioExportField) {
          return field.buildTopWidget(
            context: context,
            ref: ref,
            appModel: appModel,
            creatorModel: creatorModel,
            orientation: Orientation.portrait,
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget buildDeckDropdown() {
    return JidoujishoDropdown<String>(
      enabled: !widget.editEnhancements,
      options: widget.decks,
      initialOption: appModel.lastSelectedDeckName,
      generateLabel: (deckName) => deckName,
      onChanged: (deckName) {
        appModel.setLastSelectedDeck(deckName!);
        setState(() {});
      },
    );
  }

  Widget buildTextFields() {
    AnkiMapping mapping = appModel.lastSelectedMapping;
    List<Field> fields = mapping.getCreatorFields();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.editFields ? fields.length + 1 : fields.length,
      itemBuilder: (context, index) {
        if (widget.editFields && index == fields.length) {
          return buildAddTextField(mapping: mapping, isCollapsed: false);
        }

        Field field = fields[index];
        return buildTextField(
          mapping: mapping,
          field: field,
          isCollapsed: false,
        );
      },
    );
  }

  Widget buildCollapsedTextFields() {
    AnkiMapping mapping = appModel.lastSelectedMapping;
    List<Field> fields = mapping.getCreatorCollapsedFields();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.editFields ? fields.length + 1 : fields.length,
      itemBuilder: (context, index) {
        if (widget.editFields && index == fields.length) {
          return buildAddTextField(mapping: mapping, isCollapsed: true);
        }

        Field field = fields[index];
        return buildTextField(
          mapping: mapping,
          field: field,
          isCollapsed: true,
        );
      },
    );
  }

  Widget buildBackButton() {
    return JidoujishoIconButton(
      tooltip: backLabel,
      icon: Icons.arrow_back,
      onTap: () {
        if (widget.killOnPop) {
          FlutterExitApp.exitApp();
        } else {
          Navigator.pop(context);
        }
      },
    );
  }

  Widget buildSearchClearButton() {
    return JidoujishoIconButton(
      tooltip: clearCreatorTitle,
      icon: Icons.delete_sweep,
      onTap: showClearPrompt,
    );
  }

  void showClearPrompt() async {
    Widget alertDialog = AlertDialog(
      title: Text(clearCreatorTitle),
      content: Text(
        clearCreatorDescription,
      ),
      actions: <Widget>[
        TextButton(
          child: Text(
            dialogClearLabel,
            style: TextStyle(
              color: theme.colorScheme.primary,
            ),
          ),
          onPressed: () async {
            creatorModel.clearAll();
            Navigator.pop(context);
          },
        ),
        TextButton(
          child: Text(dialogCancelLabel),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );

    await showDialog(
      context: context,
      builder: (context) => alertDialog,
    );
  }

  Widget buildTitle() {
    late String label;
    if (widget.editEnhancements) {
      label = creatorExportingAsEditingEnhancementsLabel;
    } else if (widget.editFields) {
      label = creatorExportingAsEditingFieldsLabel;
    } else {
      label = creatorExportingAsLabel;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              JidoujishoMarquee(
                text: label,
                style: TextStyle(fontSize: textTheme.labelSmall?.fontSize),
              ),
              JidoujishoMarquee(
                text: appModel.lastSelectedMappingName,
                style: TextStyle(fontSize: textTheme.titleMedium?.fontSize),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildRemoveFieldButton({
    required AnkiMapping mapping,
    required Field field,
    required bool isCollapsed,
  }) {
    return JidoujishoIconButton(
      isWideTapArea: true,
      size: textTheme.titleLarge?.fontSize,
      tooltip: removeField,
      enabledColor: theme.colorScheme.primary,
      icon: field.icon,
      onTap: () async {
        appModel.removeField(
          mapping: mapping,
          field: field,
          isCollapsed: isCollapsed,
        );
        setState(() {});
      },
    );
  }

  Widget buildAddFieldButton({
    required AnkiMapping mapping,
    required bool isCollapsed,
  }) {
    return JidoujishoIconButton(
      isWideTapArea: true,
      size: textTheme.titleLarge?.fontSize,
      tooltip: addField,
      icon: Icons.add_circle,
      onTap: () async {
        await showDialog(
          barrierDismissible: true,
          context: context,
          builder: (context) => FieldPickerDialogPage(
            mapping: mapping,
            isCollapsed: isCollapsed,
          ),
        );
        setState(() {});
      },
    );
  }

  Widget buildAutoEnhancementEditButton({
    required AnkiMapping mapping,
    required Field field,
  }) {
    Enhancement? enhancement =
        mapping.getAutoFieldEnhancement(appModel: appModel, field: field);

    if (enhancement == null) {
      return JidoujishoIconButton(
        isWideTapArea: true,
        size: textTheme.titleLarge?.fontSize,
        tooltip: assignAutoEnhancementLabel,
        icon: Icons.add_circle,
        onTap: () async {
          await showDialog(
            barrierDismissible: true,
            context: context,
            builder: (context) => EnhancementsPickerDialogPage(
              mapping: mapping,
              slotNumber: AnkiMapping.autoModeSlotNumber,
              field: field,
            ),
          );
          setState(() {});
        },
      );
    } else {
      return JidoujishoIconButton(
        isWideTapArea: true,
        size: textTheme.titleLarge?.fontSize,
        tooltip: removeEnhancementLabel,
        enabledColor: theme.colorScheme.primary,
        icon: enhancement.icon,
        onTap: () async {
          appModel.removeAutoFieldEnhancement(mapping: mapping, field: field);
          setState(() {});
        },
      );
    }
  }

  List<Widget> buildManualEnhancementEditButtons(
      {required AnkiMapping mapping, required Field field}) {
    List<Widget> buttons = [];

    for (int i = 0; i < appModel.maximumFieldEnhancements; i++) {
      Widget button = buildManualEnhancementEditButton(
        mapping: mapping,
        field: field,
        slotNumber: i,
      );

      buttons.add(button);
    }

    return buttons.reversed.toList();
  }

  List<Widget> buildManualEnhancementButtons(
      {required AnkiMapping mapping, required Field field}) {
    List<Widget> buttons = [];

    for (int i = 0; i < appModel.maximumFieldEnhancements; i++) {
      Widget button = buildManualEnhancementButton(
        mapping: mapping,
        field: field,
        slotNumber: i,
      );

      buttons.add(button);
    }

    return buttons.reversed.toList();
  }

  Widget buildManualEnhancementButton({
    required AnkiMapping mapping,
    required Field field,
    required int slotNumber,
  }) {
    String? enhancementName =
        (mapping.enhancements![field.uniqueKey] ?? {})[slotNumber];
    Enhancement? enhancement;

    if (enhancementName != null) {
      enhancement = appModel.enhancements[field]![enhancementName];
    }

    if (enhancement == null) {
      return const SizedBox.shrink();
    } else {
      return JidoujishoIconButton(
        isWideTapArea: true,
        busy: true,
        size: textTheme.titleLarge?.fontSize,
        tooltip: enhancement.getLocalisedLabel(appModel),
        icon: enhancement.icon,
        onTap: () async {
          await enhancement!.enhanceCreatorParams(
            context: context,
            ref: ref,
            appModel: appModel,
            creatorModel: creatorModel,
            cause: EnhancementTriggerCause.manual,
          );
        },
      );
    }
  }

  Widget buildManualEnhancementEditButton({
    required AnkiMapping mapping,
    required Field field,
    required int slotNumber,
  }) {
    String? enhancementName =
        (mapping.enhancements![field.uniqueKey] ?? {})[slotNumber];
    Enhancement? enhancement;

    if (enhancementName != null) {
      enhancement = appModel.enhancements[field]![enhancementName];
    }

    if (enhancement == null) {
      return JidoujishoIconButton(
        isWideTapArea: true,
        size: textTheme.titleLarge?.fontSize,
        tooltip: assignManualEnhancementLabel,
        icon: Icons.add_circle,
        onTap: () async {
          await showDialog(
            barrierDismissible: true,
            context: context,
            builder: (context) => EnhancementsPickerDialogPage(
              mapping: mapping,
              slotNumber: slotNumber,
              field: field,
            ),
          );
          setState(() {});
        },
      );
    } else {
      return JidoujishoIconButton(
        isWideTapArea: true,
        size: textTheme.titleLarge?.fontSize,
        tooltip: removeEnhancementLabel,
        enabledColor: theme.colorScheme.primary,
        icon: enhancement.icon,
        onTap: () async {
          appModel.removeFieldEnhancement(
            mapping: mapping,
            field: field,
            slotNumber: slotNumber,
          );
          setState(() {});
        },
      );
    }
  }

  Widget buildTextField({
    required AnkiMapping mapping,
    required Field field,
    required bool isCollapsed,
  }) {
    if (!isCardEditing) {
      return TextFormField(
        onTap: () {
          FocusScope.of(context).requestFocus(FocusNode());
        },
        enableInteractiveSelection: false,
        readOnly: true,
        decoration: InputDecoration(
          prefixIcon: widget.editEnhancements
              ? buildAutoEnhancementEditButton(
                  mapping: mapping,
                  field: field,
                )
              : buildRemoveFieldButton(
                  mapping: mapping,
                  field: field,
                  isCollapsed: isCollapsed,
                ),
          suffixIcon: widget.editEnhancements
              ? Padding(
                  padding: Spacing.of(context).insets.onlyRight.small,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.min,
                    children: buildManualEnhancementEditButtons(
                      mapping: mapping,
                      field: field,
                    ),
                  ),
                )
              : null,
          labelText: field.getLocalisedLabel(appModel),
          hintText: field.getLocalisedDescription(appModel),
        ),
        selectionControls: selectionControls,
      );
    } else {
      return TextFormField(
        onChanged: (value) {
          setState(() {});
        },
        maxLines: field.maxLines,
        controller: creatorModel.getFieldController(field),
        decoration: InputDecoration(
          prefixIcon: Icon(
            field.icon,
            size: textTheme.titleLarge?.fontSize,
          ),
          suffixIcon: (mapping.enhancements![field.uniqueKey] ?? {}).isNotEmpty
              ? Padding(
                  padding: Spacing.of(context).insets.onlyRight.small,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.min,
                    children: buildManualEnhancementButtons(
                      mapping: mapping,
                      field: field,
                    ),
                  ),
                )
              : null,
          labelText: field.getLocalisedLabel(appModel),
        ),
        selectionControls: selectionControls,
      );
    }
  }

  Widget buildAddTextField({
    required AnkiMapping mapping,
    required bool isCollapsed,
  }) {
    return TextFormField(
      enableInteractiveSelection: false,
      onTap: () {
        FocusScope.of(context).requestFocus(FocusNode());
      },
      readOnly: true,
      decoration: InputDecoration(
        prefixIcon: buildAddFieldButton(
          mapping: mapping,
          isCollapsed: isCollapsed,
        ),
        labelText: addField,
        hintText: addFieldHint,
      ),
      selectionControls: selectionControls,
    );
  }

  List<Widget> buildActions() {
    if (!isCardEditing) {
      return [];
    } else {
      return [
        buildCloseOnExportButton(),
        const Space.small(),
        buildSearchClearButton(),
        const Space.small(),
        buildManageEnhancementsButton(),
        const Space.small(),
        buildSwitchProfilesButton(),
        const Space.extraSmall(),
      ];
    }
  }

  Widget buildSwitchProfilesButton() {
    return JidoujishoIconButton(
      key: _profileMenuKey,
      tooltip: appModel.translate('switch_profiles'),
      icon: Icons.switch_account,
      onTapDown: openProfilesMenu,
    );
  }

  Widget buildManageEnhancementsButton() {
    return JidoujishoIconButton(
      tooltip: appModel.translate('enhancements'),
      icon: Icons.auto_fix_high,
      onTap: () async {
        await appModel.openCreatorEnhancementsEditor();
        setState(() {});
      },
    );
  }

  /// Allows user to toggle whether or not to filter for videos with
  /// closed captions.
  Widget buildCloseOnExportButton() {
    ValueNotifier<bool> notifier =
        ValueNotifier<bool>(appModel.closeCreatorOnExport);

    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (context, value, child) {
        return JidoujishoIconButton(
          size: Theme.of(context).textTheme.titleLarge?.fontSize,
          tooltip: closeOnExportLabel,
          enabledColor: value ? Colors.red : null,
          icon: Icons.exit_to_app,
          onTap: () {
            appModel.toggleCloseCreatorOnExport();
            notifier.value = appModel.closeCreatorOnExport;

            Fluttertoast.showToast(
              msg: appModel.closeCreatorOnExport
                  ? closeOnExportOnToast
                  : closeOnExportOffToast,
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
            );
          },
        );
      },
    );
  }

  PopupMenuItem<VoidCallback> buildPopupItem({
    required String label,
    required Function() action,
    IconData? icon,
    Color? color,
  }) {
    return PopupMenuItem<VoidCallback>(
      child: Row(
        children: [
          if (icon != null)
            Icon(
              icon,
              size: textTheme.bodyMedium?.fontSize,
              color: color,
            ),
          if (icon != null) const Space.normal(),
          Text(
            label,
            style: TextStyle(color: color),
          ),
        ],
      ),
      value: action,
    );
  }

  Rect _getWidgetGlobalRect(GlobalKey key) {
    RenderBox renderBox = key.currentContext?.findRenderObject() as RenderBox;
    var offset = renderBox.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
        offset.dx, offset.dy, renderBox.size.width, renderBox.size.height);
  }

  final GlobalKey _profileMenuKey = GlobalKey();
  final GlobalKey _scaffoldKey = GlobalKey();

  void openProfilesMenu(TapDownDetails details) async {
    RelativeRect position = RelativeRect.fromRect(
        _getWidgetGlobalRect(_profileMenuKey),
        _getWidgetGlobalRect(_scaffoldKey));
    Function()? selectedAction = await showMenu(
      context: context,
      position: position,
      items: getProfileItems(),
    );

    selectedAction?.call();
  }

  List<PopupMenuItem<VoidCallback>> getProfileItems() {
    return appModel.mappings.map((mapping) {
      return buildPopupItem(
        label: mapping.label,
        action: () async {
          await appModel.setLastSelectedMapping(mapping);
          setState(() {});
        },
      );
    }).toList();
  }
}

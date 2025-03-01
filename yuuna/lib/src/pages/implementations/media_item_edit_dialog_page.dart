import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:spaces/spaces.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// The content of the dialog upon selecting 'Edit' in the
/// [MediaItemDialogPage].
class MediaItemEditDialogPage extends BasePage {
  /// Create an instance of this page.
  const MediaItemEditDialogPage({
    required this.item,
    super.key,
  });

  /// The [MediaItem] pertaining to the page.
  final MediaItem item;

  @override
  BasePageState createState() => _MediaItemEditDialogPageState();
}

class _MediaItemEditDialogPageState
    extends BasePageState<MediaItemEditDialogPage> {
  String get undoLabel => appModel.translate('undo');
  String get pickImageLabel => appModel.translate('pick_image');
  String get dialogCancelLabel => appModel.translate('dialog_cancel');
  String get dialogSaveLabel => appModel.translate('dialog_save');

  MediaSource get mediaSource => widget.item.getMediaSource(appModel: appModel);
  ImageProvider? _defaultImageProvider;
  ImageProvider? _coverImageProvider;

  File? _newFile;

  final TextEditingController _nameOverrideController = TextEditingController();
  final TextEditingController _coverOverrideController =
      TextEditingController(text: '-');

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (_defaultImageProvider == null) {
      String? overrideTitle =
          mediaSource.getOverrideTitleFromMediaItem(widget.item);
      String title = overrideTitle ?? widget.item.title;
      _nameOverrideController.text = title;

      _defaultImageProvider = mediaSource.getDisplayThumbnailFromMediaItem(
        appModel: appModel,
        item: widget.item,
        noOverride: true,
      );
      _coverImageProvider = mediaSource.getDisplayThumbnailFromMediaItem(
        appModel: appModel,
        item: widget.item,
      );
    }

    return AlertDialog(
      contentPadding: MediaQuery.of(context).orientation == Orientation.portrait
          ? Spacing.of(context).insets.all.big
          : Spacing.of(context).insets.all.normal,
      content: buildContent(),
      actions: actions,
    );
  }

  Widget buildTitle() {
    return Text(mediaSource.getDisplayTitleFromMediaItem(widget.item));
  }

  Widget buildContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: double.maxFinite, height: 1),
        TextField(
          controller: _nameOverrideController,
          maxLines: null,
          decoration: InputDecoration(
            suffixIcon: JidoujishoIconButton(
              tooltip: undoLabel,
              isWideTapArea: true,
              icon: Icons.undo,
              onTap: () async {
                _nameOverrideController.text = widget.item.title;
                FocusScope.of(context).unfocus();
              },
            ),
          ),
        ),
        TextField(
          readOnly: true,
          controller: _coverOverrideController,
          style: const TextStyle(color: Colors.transparent),
          decoration: InputDecoration(
            floatingLabelBehavior: FloatingLabelBehavior.always,
            suffixIcon: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Padding(
                    child: Image(
                        image: _coverImageProvider ?? _defaultImageProvider!),
                    padding: Spacing.of(context).insets.all.small,
                  ),
                ),
                const SizedBox(width: 5),
                JidoujishoIconButton(
                  tooltip: pickImageLabel,
                  isWideTapArea: true,
                  icon: Icons.file_upload,
                  onTap: () async {
                    ImagePicker imagePicker = ImagePicker();
                    final pickedFile = await imagePicker.pickImage(
                        source: ImageSource.gallery);
                    _newFile = File(pickedFile!.path);
                    _coverImageProvider = FileImage(_newFile!);

                    setState(() {});
                  },
                ),
                JidoujishoIconButton(
                  tooltip: undoLabel,
                  isWideTapArea: true,
                  icon: Icons.undo,
                  onTap: () async {
                    _newFile = null;
                    _coverImageProvider = null;

                    setState(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> get actions => [
        buildCancelButton(),
        buildSaveButton(),
      ];

  Widget buildCancelButton() {
    return TextButton(
      child: Text(
        dialogCancelLabel,
      ),
      onPressed: executeCancel,
    );
  }

  Widget buildSaveButton() {
    return TextButton(
      child: Text(
        dialogSaveLabel,
      ),
      onPressed: executeSave,
    );
  }

  void executeCancel() async {
    Navigator.pop(context);
  }

  void executeSave() async {
    await mediaSource.setOverrideTitleFromMediaItem(
      item: widget.item,
      title: _nameOverrideController.text,
    );
    if (_newFile != null) {
      await mediaSource.setOverrideThumbnailFromMediaItem(
        appModel: appModel,
        item: widget.item,
        file: _newFile,
      );
    }

    Navigator.pop(context);
    Navigator.pop(context);
    mediaSource.mediaType.refreshTab();
  }
}

import 'package:chisa/media/media_source.dart';
import 'package:chisa/media/media_type.dart';
import 'package:chisa/util/center_icon_message.dart';
import 'package:chisa/util/marquee.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chisa/models/app_model.dart';

class MediaSourcesDialog extends StatefulWidget {
  const MediaSourcesDialog({
    required this.mediaType,
    Key? key,
    this.manageAllowed = false,
  }) : super(key: key);

  final MediaType mediaType;
  final bool manageAllowed;

  @override
  State<StatefulWidget> createState() => MediaSourcesDialogState();
}

class MediaSourcesDialogState extends State<MediaSourcesDialog> {
  ScrollController scrollController = ScrollController();

  late AppModel appModel;

  @override
  Widget build(BuildContext context) {
    appModel = Provider.of<AppModel>(context);
    MediaSource source = appModel.getCurrentMediaTypeSource(widget.mediaType);
    bool isShown = appModel.getMediaSourceShown(source);

    return AlertDialog(
      contentPadding:
          const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 10),
      shape: const RoundedRectangleBorder(),
      content: buildContent(),
      actions: (widget.manageAllowed)
          ? <Widget>[
              if (isShown)
                TextButton(
                  child: Text(
                    appModel.translate('dialog_hide'),
                  ),
                  onPressed: () async {
                    await appModel.setMediaSourceShown(
                        source: source, shown: false);
                    setState(() {});
                  },
                ),
              if (!isShown)
                TextButton(
                  child: Text(
                    appModel.translate('dialog_show'),
                  ),
                  onPressed: () async {
                    await appModel.setMediaSourceShown(
                        source: source, shown: true);
                    setState(() {});
                  },
                ),
              TextButton(
                child: Text(
                  appModel.translate('dialog_close'),
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ]
          : [],
    );
  }

  Widget buildContent() {
    List<MediaSource> mediaSources =
        appModel.getMediaSourcesByType(widget.mediaType);

    return SizedBox(
      width: double.maxFinite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (mediaSources.isEmpty) showEmptyMessage() else showSourcesList(),
        ],
      ),
    );
  }

  Widget showEmptyMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: showCenterIconMessage(
        context: context,
        label: appModel.translate('source_list_empty'),
        icon: Icons.perm_media,
        jumpingDots: false,
      ),
    );
  }

  Widget showSourcesList() {
    String currentMediaSource =
        appModel.getCurrentMediaTypeSourceName(widget.mediaType);
    List<MediaSource> mediaSources =
        appModel.getMediaSourcesByType(widget.mediaType);

    if (!widget.manageAllowed) {
      mediaSources
          .removeWhere((source) => !appModel.getMediaSourceShown(source));
    }

    return RawScrollbar(
      controller: scrollController,
      thumbColor:
          (appModel.getIsDarkMode()) ? Colors.grey[700] : Colors.grey[400],
      child: ListView.builder(
        controller: scrollController,
        shrinkWrap: true,
        itemCount: mediaSources.length,
        itemBuilder: (context, index) {
          MediaSource source = mediaSources[index];

          double opacity = 1;
          if (!appModel.getMediaSourceShown(source)) {
            opacity = 0.5;
          }

          return ListTile(
            dense: true,
            selected: currentMediaSource == source.sourceName,
            selectedTileColor: Theme.of(context).selectedRowColor,
            title: Row(
              children: [
                Icon(
                  source.icon,
                  size: 20,
                  color: appModel.getIsDarkMode()
                      ? Colors.white.withOpacity(opacity)
                      : Colors.black.withOpacity(opacity),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: Marquee(
                      text: source.sourceName,
                      style: TextStyle(
                        fontSize: 16,
                        color: appModel.getIsDarkMode()
                            ? Colors.white.withOpacity(opacity)
                            : Colors.black.withOpacity(opacity),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            onTap: () async {
              await appModel.setCurrentMediaTypeSourceName(
                widget.mediaType,
                source.sourceName,
              );
              if (!widget.manageAllowed) {
                Navigator.pop(context);
              }
              setState(() {});
            },
          );
        },
      ),
    );
  }
}

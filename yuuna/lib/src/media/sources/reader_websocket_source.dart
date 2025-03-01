import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_floating_search_bar/material_floating_search_bar.dart';
import 'package:nowplaying/nowplaying.dart';
import 'package:spaces/spaces.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/models.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A media source that allows the user to fetch lyrics from Google.
class ReaderWebsocketSource extends ReaderMediaSource {
  /// Define this media source.
  ReaderWebsocketSource._privateConstructor()
      : super(
          uniqueKey: 'reader_websocket',
          sourceName: 'WebSocket',
          description: 'Select and mine text received from a WebSocket server.',
          icon: Icons.webhook,
          implementsSearch: false,
          implementsHistory: false,
        );

  /// Get the singleton instance of this media type.
  static ReaderWebsocketSource get instance => _instance;

  static final ReaderWebsocketSource _instance =
      ReaderWebsocketSource._privateConstructor();

  /// Current server address.
  String? get serverAddress => _serverAddress;
  String? _serverAddress;

  /// List of received messages from the server.
  List<String> messages = [];

  /// Manual search action.
  void setServerAddress({
    required String address,
  }) {
    _channel = WebSocketChannel.connect(
      Uri.parse(address),
    )..stream.asBroadcastStream().listen((message) {
        _controller.add(null);
        messages.add(message);
      }, onError: (_) {
        clearServerAddress();
        mediaType.refreshTab();
      });
  }

  /// Clear server action.
  void clearServerAddress() {
    _controller.add(null);
    messages = [];
    _channel?.sink.close();
    _channel = null;
  }

  /// Communicates override changes.

  WebSocketChannel? _channel;

  @override
  Future<void> onSearchBarTap({
    required BuildContext context,
    required WidgetRef ref,
    required AppModel appModel,
  }) async {}

  /// Communicates  changes.
  Stream<void> get stream => _controller.stream;
  final StreamController<void> _controller = StreamController.broadcast();

  @override
  Future<void> onSourceExit({
    required AppModel appModel,
    required BuildContext context,
    required WidgetRef ref,
  }) async {}

  @override
  BaseSourcePage buildLaunchPage({MediaItem? item}) {
    throw UnsupportedError('WebSocket source does not launch any page');
  }

  @override
  Future<void> prepareResources() async {
    NowPlaying.instance.start();
  }

  @override
  List<Widget> getActions({
    required BuildContext context,
    required WidgetRef ref,
    required AppModel appModel,
  }) {
    return [
      if (isActive)
        buildClearButton(
          context: context,
          ref: ref,
          appModel: appModel,
        ),
      buildConnectButton(
        context: context,
        ref: ref,
        appModel: appModel,
      ),
    ];
  }

  @override
  BasePage buildHistoryPage({MediaItem? item}) {
    return const ReaderWebsocketPage();
  }

  /// Whether or not artist and title are non-null and override the current
  /// media.
  bool get isActive => _channel != null;

  /// Menu bar action.
  Widget buildClearButton(
      {required BuildContext context,
      required WidgetRef ref,
      required AppModel appModel}) {
    String clearTitle = appModel.translate('clear_text_title');

    return FloatingSearchBarAction(
      child: JidoujishoIconButton(
        size: Theme.of(context).textTheme.titleLarge?.fontSize,
        tooltip: clearTitle,
        icon: Icons.clear_all,
        onTap: () {
          showClearPrompt(
            appModel: appModel,
            context: context,
            ref: ref,
          );
        },
      ),
    );
  }

  /// Shows when the clear button is pressed.
  void showClearPrompt(
      {required BuildContext context,
      required WidgetRef ref,
      required AppModel appModel}) async {
    String dialogClearLabel = appModel.translate('dialog_clear');
    String dialogCancelLabel = appModel.translate('dialog_cancel');
    String clearTitle = appModel.translate('clear_text_title');
    String clearDescription = appModel.translate('clear_text_description');

    Widget alertDialog = AlertDialog(
      contentPadding: MediaQuery.of(context).orientation == Orientation.portrait
          ? Spacing.of(context).insets.exceptBottom.big
          : Spacing.of(context).insets.exceptBottom.normal,
      title: Text(clearTitle),
      content: Text(
        clearDescription,
      ),
      actions: <Widget>[
        TextButton(
          child: Text(
            dialogClearLabel,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          onPressed: () async {
            messages = [];
            _controller.add(null);

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

  /// Shows when the close button is pressed.
  void showDisconnectPrompt(
      {required BuildContext context,
      required WidgetRef ref,
      required AppModel appModel}) async {
    String dialogCloseLabel = appModel.translate('dialog_close');
    String dialogCancelLabel = appModel.translate('dialog_cancel');
    String closeTitle = appModel.translate('close_connection_title');
    String closeDescription =
        appModel.translate('close_connection_description');

    Widget alertDialog = AlertDialog(
      contentPadding: MediaQuery.of(context).orientation == Orientation.portrait
          ? Spacing.of(context).insets.exceptBottom.big
          : Spacing.of(context).insets.exceptBottom.normal,
      title: Text(closeTitle),
      content: Text(
        closeDescription,
      ),
      actions: <Widget>[
        TextButton(
          child: Text(
            dialogCloseLabel,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          onPressed: () async {
            clearServerAddress();
            mediaType.refreshTab();

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

  /// Menu bar action.
  Widget buildConnectButton(
      {required BuildContext context,
      required WidgetRef ref,
      required AppModel appModel}) {
    String connectDisconnectLabel = appModel.translate('connect_disconnect');

    return FloatingSearchBarAction(
      child: JidoujishoIconButton(
        size: Theme.of(context).textTheme.titleLarge?.fontSize,
        tooltip: connectDisconnectLabel,
        enabledColor: isActive ? Colors.red : null,
        icon: Icons.leak_add,
        onTap: () {
          showConnectDialog(
            context: context,
            ref: ref,
            appModel: appModel,
          );
        },
      ),
    );
  }

  /// Set the last used server address.
  Future<void> setLastAddress(String address) async {
    await setPreference<String>(key: 'last_address', value: address);
  }

  /// Get the last used server address.
  String get lastAddress =>
      getPreference<String>(key: 'last_address', defaultValue: '');

  /// Dialog for menu action.
  void showConnectDialog(
      {required BuildContext context,
      required WidgetRef ref,
      required AppModel appModel}) async {
    if (isActive) {
      showDisconnectPrompt(
        context: context,
        ref: ref,
        appModel: appModel,
      );
    } else {
      await showDialog(
        context: context,
        builder: (context) => WebsocketDialogPage(
          address: lastAddress,
          onConnect: (address) {
            Navigator.pop(context);
            setLastAddress(address);
            setServerAddress(
              address: address,
            );

            mediaType.refreshTab();
            _controller.add(null);
          },
        ),
      );
    }
  }
}

import 'dart:ui';

import 'package:chewie/src/chewie_player.dart';
import 'package:chewie/src/cupertino_controls.dart';
import 'package:chewie/src/material_controls.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ext_video_player/ext_video_player.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

class PlayerWithControls extends StatelessWidget {
  const PlayerWithControls({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ChewieController chewieController = ChewieController.of(context);

    double _calculateAspectRatio(BuildContext context) {
      final size = MediaQuery.of(context).size;
      final width = size.width;
      final height = size.height;

      return width > height ? width / height : height / width;
    }

    Widget _buildControls(
      BuildContext context,
      ChewieController chewieController,
    ) {
      final controls = Theme.of(context).platform == TargetPlatform.android
          ? const MaterialControls()
          : const MaterialControls();
      return chewieController.showControls
          ? chewieController.customControls ?? controls
          : Container();
    }

    Stack _buildPlayerWithControls(
        ChewieController chewieController, BuildContext context) {
      return Stack(
        children: <Widget>[
          chewieController.placeholder ?? Container(),
          Center(
            child: SizedBox.expand(
              child: VlcPlayer(
                controller: chewieController.videoPlayerController,
                aspectRatio: chewieController.aspectRatio,
                placeholder: chewieController.placeholder,
              ),
            ),
          ),
          chewieController.overlay ?? Container(),
          if (!chewieController.isFullScreen)
            _buildControls(context, chewieController)
          else
            SafeArea(
              child: _buildControls(context, chewieController),
            ),
        ],
      );
    }

    return Center(
      child: SizedBox(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        child: AspectRatio(
          aspectRatio: _calculateAspectRatio(context),
          child: _buildPlayerWithControls(chewieController, context),
        ),
      ),
    );
  }
}

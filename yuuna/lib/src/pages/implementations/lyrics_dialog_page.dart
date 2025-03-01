import 'package:flutter/material.dart';
import 'package:spaces/spaces.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// Used by the Reader Lyrics Source.
class LyricsDialogPage extends BasePage {
  /// Create an instance of this page.
  const LyricsDialogPage({
    required this.title,
    required this.artist,
    required this.onSearch,
    super.key,
  });

  /// Media title.
  final String title;

  /// Media artist.
  final String artist;

  /// On search action.
  final Function(String, String) onSearch;

  @override
  BasePageState createState() => _LyricsDialogPageState();
}

class _LyricsDialogPageState extends BasePageState<LyricsDialogPage> {
  String get lyricsTitleLabel => appModel.translate('lyrics_title');
  String get lyricsArtistLabel => appModel.translate('lyrics_artist');
  String get dialogSearchLabel => appModel.translate('dialog_search');
  String get clearLabel => appModel.translate('clear');

  late final TextEditingController _titleController;
  late final TextEditingController _artistController;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: widget.title);
    _artistController = TextEditingController(text: widget.artist);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: Spacing.of(context).insets.all.big,
      content: buildContent(),
      actions: actions,
    );
  }

  List<Widget> get actions => [buildSearchButton()];

  Widget buildContent() {
    return SingleChildScrollView(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * (1 / 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              controller: _titleController,
              decoration: InputDecoration(
                floatingLabelBehavior: FloatingLabelBehavior.always,
                labelText: lyricsTitleLabel,
                suffixIcon: JidoujishoIconButton(
                  size: 18,
                  tooltip: clearLabel,
                  onTap: _titleController.clear,
                  icon: Icons.clear,
                ),
              ),
            ),
            TextField(
              controller: _artistController,
              decoration: InputDecoration(
                floatingLabelBehavior: FloatingLabelBehavior.always,
                labelText: lyricsArtistLabel,
                suffixIcon: JidoujishoIconButton(
                  size: 18,
                  tooltip: clearLabel,
                  onTap: _artistController.clear,
                  icon: Icons.clear,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget buildSearchButton() {
    return TextButton(
      child: Text(
        dialogSearchLabel,
      ),
      onPressed: executeSearch,
    );
  }

  void executeSearch() async {
    widget.onSearch(
      _titleController.text,
      _artistController.text,
    );
  }
}

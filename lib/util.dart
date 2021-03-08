import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:ext_video_player/ext_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:share/share.dart';
import 'package:subtitle_wrapper_package/data/models/subtitle.dart';
import 'package:unofficial_jisho_api/api.dart';
import 'package:xml2json/xml2json.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'package:jidoujisho/main.dart';

bool isNumeric(String s) {
  if (s == null) {
    return false;
  }
  return double.parse(s) != null;
}

Future<DictionaryEntry> getWeblioEntry(String searchTerm) async {
  var client = http.Client();
  http.Response response =
      await client.get('https://ejje.weblio.jp/content/$searchTerm');

  var document = parser.parse(response.body);

  bool isValidWord = document.getElementsByClassName("KejjeOs").isNotEmpty;
  print(isValidWord);
  DictionaryEntry entry;

  if (isValidWord) {
    var details = document.getElementsByClassName("kiji").first;

    String word = document.getElementById("h1Query").innerHtml;
    String reading = details.getElementsByClassName("KejjeHt").first.text;
    String meaning = "";

    var definitions = details.getElementsByClassName("level0");
    definitions[0].text;

    for (int i = 0; i < definitions.length; i++) {
      String nextLine = definitions[i].text;
      if (nextLine[0].contains(new RegExp(r'[a-z]'))) {
        meaning = meaning + " " + nextLine + "\n";
      } else {
        meaning = meaning + nextLine + "\n";
      }
    }

    entry = DictionaryEntry(
      word: word,
      reading: reading,
      meaning: meaning,
    );

    debugPrint(meaning, wrapWidth: 1024);
  } else {
    print("INVALID WORD - SEARCHING ALTERNATIVE");
    var crosslink = document.getElementsByClassName("crosslink");
    var level0 = document.getElementsByClassName("level0");

    if (level0.isNotEmpty) {
      entry = await getWeblioEntry(crosslink.first.text);
    } else if (document.getElementById("h1Query") != null) {
      String word = document.getElementById("h1Query").innerHtml;
      String reading = "";
      String meaning =
          document.getElementsByClassName("content-explanation ej").first.text;

      entry = DictionaryEntry(
        word: word,
        reading: reading,
        meaning: meaning,
      );
    } else {
      return null;
    }
  }

  return entry;
}

String getDefaultSubtitles(File file, List<File> internalSubtitles) {
  if (internalSubtitles.isNotEmpty) {
    return internalSubtitles.first.readAsStringSync();
  } else {
    return "";
  }
}

String timedTextToSRT(String timedText) {
  final Xml2Json xml2Json = Xml2Json();

  xml2Json.parse(timedText);
  var jsonString = xml2Json.toBadgerfish();
  var data = jsonDecode(jsonString);

  List<dynamic> lines = (data["transcript"]["text"]);

  String convertedLines = "";
  int lineCount = 0;

  lines.forEach((line) {
    String convertedLine = timedLineToSRT(line, lineCount++);
    convertedLines = convertedLines + convertedLine;
  });

  return convertedLines;
}

String timedLineToSRT(Map<String, dynamic> line, int lineCount) {
  double start = double.parse(line["\@start"]);
  double duration = double.parse(line["\@dur"]);
  String text = line["\$"] ?? "";

  text = text.replaceAll("\\n", "\n");
  text = text.replaceAll("&#39;", "'");
  text = text.replaceAll("&quot;", "\"");

  String startTime = formatTimeString(start);
  String endTime = formatTimeString(start + duration);
  String lineNumber = lineCount.toString();

  String srtLine = "$lineNumber\n$startTime --> $endTime\n$text\n\n";

  return srtLine;
}

Future exportCurrentFrame(VideoPlayerController controller) async {
  File imageFile = File(previewImageDir);
  if (imageFile.existsSync()) {
    imageFile.deleteSync();
  }

  Duration currentTime = controller.value.position;
  String formatted = getTimestampFromDuration(currentTime);

  final FlutterFFmpeg _flutterFFmpeg = new FlutterFFmpeg();

  String inputPath = controller.dataSource;
  String exportPath = "\"$appDirPath/exportImage.jpg\"";

  String command =
      "-loglevel quiet -ss $formatted -y -i \"$inputPath\" -frames:v 1 -q:v 2 $exportPath";

  await _flutterFFmpeg.execute(command);

  return;
}

List<File> extractWebSubtitle(String webSubtitle) {
  List<File> files = [];

  String subPath = "$appDirPath/extractWebSrt.srt";
  File subFile = File(subPath);
  if (subFile.existsSync()) {
    subFile.deleteSync();
  }

  subFile.createSync();
  subFile.writeAsStringSync(webSubtitle);
  files.add(subFile);

  return files;
}

Future exportCurrentAudio(
    VideoPlayerController controller, Subtitle subtitle) async {
  File audioFile = File(previewAudioDir);
  if (audioFile.existsSync()) {
    audioFile.deleteSync();
  }

  String timeStart;
  String timeEnd;
  String audioIndex;

  timeStart = getTimestampFromDuration(subtitle.startTime);
  timeEnd = getTimestampFromDuration(subtitle.endTime);

  audioIndex = controller.getCurrentAudioIndex().toString();

  final FlutterFFmpeg _flutterFFmpeg = new FlutterFFmpeg();

  String inputPath = controller.dataSource;
  String outputPath = "\"$appDirPath/exportAudio.mp3\"";
  String command =
      "-loglevel quiet -ss $timeStart -to $timeEnd -y -i \"$inputPath\" -map 0:a:$audioIndex $outputPath";

  await _flutterFFmpeg.execute(command);

  return;
}

Future<List<File>> extractSubtitles(File file) async {
  String inputPath = file.path;
  List<File> files = [];

  final FlutterFFmpeg _flutterFFmpeg = new FlutterFFmpeg();

  for (int i = 0; i < 10; i++) {
    String outputPath = "\"$appDirPath/extractSrt$i.srt\"";
    String command =
        "-loglevel quiet -i \"$inputPath\" -map 0:s:$i $outputPath";

    String subPath = "$appDirPath/extractSrt$i.srt";
    File subFile = File(subPath);

    if (subFile.existsSync()) {
      subFile.deleteSync();
    }

    await _flutterFFmpeg.execute(command);

    if (await subFile.exists()) {
      if (subFile.readAsStringSync().isEmpty) {
        subFile.deleteSync();
      } else {
        files.add(subFile);
      }
    }
  }

  return files;
}

Future<String> extractNonSrtSubtitles(File file) async {
  final FlutterFFmpeg _flutterFFmpeg = new FlutterFFmpeg();

  String inputPath = file.path;
  String outputPath = "\"$appDirPath/extractNonSrt.srt\"";
  String command =
      "-loglevel quiet -f ass -c:s ass -i \"$inputPath\" -map 0:s:0 -c:s subrip $outputPath";

  String subPath = "$appDirPath/extractNonSrt.srt";
  File subFile = File(subPath);

  if (subFile.existsSync()) {
    subFile.deleteSync();
  }

  await _flutterFFmpeg.execute(command);
  return subFile.readAsStringSync();
}

Future exportToAnki(
  BuildContext context,
  VideoPlayerController controller,
  Subtitle subtitle,
  DictionaryEntry dictionaryEntry,
) async {
  await exportCurrentFrame(controller);
  await exportCurrentAudio(controller, subtitle);

  showAnkiDialog(context, subtitle.text, dictionaryEntry);
}

void showAnkiDialog(
  BuildContext context,
  String sentence,
  DictionaryEntry dictionaryEntry,
) {
  TextEditingController _sentenceController =
      new TextEditingController(text: sentence);
  TextEditingController _wordController =
      new TextEditingController(text: dictionaryEntry.word);
  TextEditingController _readingController =
      new TextEditingController(text: dictionaryEntry.reading);
  TextEditingController _meaningController =
      new TextEditingController(text: dictionaryEntry.meaning);

  Widget displayField(
    String labelText,
    String hintText,
    IconData icon,
    TextEditingController controller,
  ) {
    return TextFormField(
      keyboardType: TextInputType.multiline,
      maxLines: null,
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        suffixIcon: IconButton(
          iconSize: 12,
          onPressed: () => controller.clear(),
          icon: Icon(Icons.clear),
        ),
        labelText: labelText,
        hintText: hintText,
      ),
    );
  }

  Widget sentenceField = displayField(
    "文",
    "ここにカードの前面または文章を入力してください",
    Icons.format_align_center_rounded,
    _sentenceController,
  );
  Widget wordField = displayField(
    "単語",
    "ここでカードの後ろに単語を入力してください",
    Icons.speaker_notes_outlined,
    _wordController,
  );
  Widget readingField = displayField(
    "読み方",
    "ここでカードの後ろに読み方を入力してください",
    Icons.surround_sound_outlined,
    _readingController,
  );
  Widget meaningField = displayField(
    "意味",
    "ここでカードの後ろに意味を入力してください",
    Icons.translate_rounded,
    _meaningController,
  );

  AudioPlayer audioPlayer = AudioPlayer();
  imageCache.clear();

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        contentPadding: EdgeInsets.all(8),
        content: SingleChildScrollView(
          child: Column(
            children: [
              Image.file(File(previewImageDir)),
              sentenceField,
              wordField,
              readingField,
              meaningField,
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text(
              'オーディオを再生',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: TextButton.styleFrom(
              textStyle: TextStyle(
                color: Colors.white,
              ),
            ),
            onPressed: () async {
              await audioPlayer.stop();
              await audioPlayer.play(previewAudioDir, isLocal: true);
            },
          ),
          TextButton(
            child: Text(
              'キャンセル',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: TextButton.styleFrom(
              textStyle: TextStyle(
                color: Colors.white,
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          TextButton(
            child: Text(
              'エクスポート',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: TextButton.styleFrom(
              textStyle: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            onPressed: () {
              exportAnkiCard(
                _sentenceController.text,
                _wordController.text,
                _readingController.text,
                _meaningController.text,
              );
              Navigator.pop(context);
            },
          ),
        ],
      );
    },
  );
}

void exportAnkiCard(
    String sentence, String answer, String reading, String meaning) {
  String frontText;
  String backText;

  DateTime now = DateTime.now();
  String newFileName =
      "jidoujisho-" + DateFormat('yyyyMMddTkkmmss').format(now);

  File imageFile = File(previewImageDir);
  File audioFile = File(previewAudioDir);

  String newImagePath =
      "storage/emulated/0/AnkiDroid/collection.media/$newFileName.jpg";
  String newAudioPath =
      "storage/emulated/0/AnkiDroid/collection.media/$newFileName.mp3";

  String addImage = "";
  String addAudio = "";

  if (imageFile.existsSync()) {
    imageFile.copySync(newImagePath);
    addImage = "<img src=\"$newFileName.jpg\">";
  }
  if (audioFile.existsSync()) {
    audioFile.copySync(newAudioPath);
    addAudio = "[sound:$newFileName.mp3]";
  }

  frontText =
      "$addAudio\n$addImage\n<p style=\"font-size:30px;\">$sentence</p>";
  backText =
      "<p style=\"margin: 0\">$reading</h6>\n<h2 style=\"margin: 0\">$answer</h2><p><small>$meaning</p></small>";

  Share.share(
    backText,
    subject: frontText,
  );
}

class DictionaryEntry {
  String word;
  String reading;
  String meaning;

  DictionaryEntry({
    this.word,
    this.reading,
    this.meaning,
  });
}

List<DictionaryEntry> importCustomDictionary() {
  List<DictionaryEntry> entries = [];

  for (int i = 0; i < 999; i++) {
    String outputPath =
        "storage/emulated/0/Android/data/com.lrorpilla.jidoujisho/files/term_bank_$i.json";
    File dictionaryFile = File(outputPath);

    if (dictionaryFile.existsSync()) {
      List<dynamic> dictionary = jsonDecode(dictionaryFile.readAsStringSync());
      dictionary.forEach((entry) {
        entries.add(DictionaryEntry(
          word: entry[0].toString(),
          reading: entry[1].toString(),
          meaning: entry[5].toString(),
        ));
      });
    }
  }

  return entries;
}

List<String> getAllImportedWords() {
  List<String> allWords = [];
  for (DictionaryEntry entry in customDictionary) {
    allWords.add(entry.word);
  }

  return allWords;
}

Future<DictionaryEntry> getWordDetails(String searchTerm) async {
  bool forceJisho = searchTerm.contains("@usejisho@");
  searchTerm = searchTerm.replaceAll("@usejisho@", "");

  String removeLastNewline(String n) => n = n.substring(0, n.length - 2);
  bool hasDuplicateReading(String readings, String reading) =>
      readings.contains("$reading; ");

  JishoAPIResult results = await searchForPhrase(searchTerm);
  JishoResult bestResult = results.data.first;

  List<JishoJapaneseWord> words = bestResult.japanese;
  List<JishoWordSense> senses = bestResult.senses;

  String exportTerm = "";
  String exportReadings = "";
  String exportMeanings = "";

  words.forEach((word) {
    String term = word.word;
    String reading = word.reading;

    if (!hasDuplicateReading(exportTerm, term)) {
      exportTerm = "$exportTerm$term; ";
    }
    if (!hasDuplicateReading(exportReadings, reading)) {
      exportReadings = "$exportReadings$reading; ";
    }

    if (term == null) {
      exportTerm = "";
    }
  });

  if (exportReadings.isNotEmpty) {
    exportReadings = removeLastNewline(exportReadings);
  }
  if (exportTerm.isNotEmpty) {
    exportTerm = removeLastNewline(exportTerm);
  } else {
    if (exportReadings.isNotEmpty) {
      exportTerm = exportReadings;
    } else {
      exportTerm = bestResult.slug;
    }
  }

  if (exportReadings == "null" ||
      exportReadings == searchTerm && bestResult.slug == exportReadings) {
    exportReadings = "";
  }

  int i = 0;

  senses.forEach(
    (sense) {
      i++;

      List<String> allParts = sense.parts_of_speech;
      List<String> allDefinitions = sense.english_definitions;

      String partsOfSpeech = "";
      String definitions = "";

      allParts.forEach(
        (part) => {partsOfSpeech = "$partsOfSpeech $part; "},
      );
      allDefinitions.forEach(
        (definition) => {definitions = "$definitions $definition; "},
      );

      if (partsOfSpeech.isNotEmpty) {
        partsOfSpeech = removeLastNewline(partsOfSpeech);
      }
      if (definitions.isNotEmpty) {
        definitions = removeLastNewline(definitions);
      }

      exportMeanings = "$exportMeanings$i) $definitions -$partsOfSpeech \n";
    },
  );
  exportMeanings = removeLastNewline(exportMeanings);

  DictionaryEntry dictionaryEntry;

  print("SEARCH TERM: $searchTerm");
  print("EXPORT TERM: $exportTerm");

  if (customDictionary.isEmpty || forceJisho) {
    dictionaryEntry = DictionaryEntry(
      word: exportTerm ?? searchTerm,
      reading: exportReadings,
      meaning: exportMeanings,
    );
  } else {
    int resultIndex;

    final searchResult = customDictionaryFuzzy.search(searchTerm, 1);
    print("SEARCH RESULT: $searchResult");

    if (searchResult.isNotEmpty && searchResult.first.score == 0) {
      resultIndex = searchResult.first.matches.first.arrayIndex;

      dictionaryEntry = DictionaryEntry(
        word: customDictionary[resultIndex].word,
        reading: customDictionary[resultIndex].reading,
        meaning: customDictionary[resultIndex].meaning,
      );

      return dictionaryEntry;
    } else {
      words.forEach((word) {
        String term = word.word;

        if (term != null) {
          final termResult = customDictionaryFuzzy.search(term, 1);

          if (termResult.isNotEmpty && termResult.first.score == 0.0) {
            resultIndex = termResult.first.matches.first.arrayIndex;
            print("TERM RESULT: $searchResult");
          }
        }
      });
    }

    if (resultIndex == null) {
      resultIndex = searchResult.first.matches.first.arrayIndex;
    }

    dictionaryEntry = DictionaryEntry(
      word: exportTerm ?? searchTerm,
      reading: exportReadings,
      meaning: exportMeanings,
    );
  }

  return dictionaryEntry;
}

Future<String> getPlayerYouTubeInfo(String webURL) async {
  var videoID = YoutubePlayer.convertUrlToId(webURL);
  if (videoID != null) {
    YoutubeExplode yt = YoutubeExplode();
    var streamManifest = await yt.videos.streamsClient.getManifest(webURL);
    var streamInfo = streamManifest.muxed.withHighestBitrate();
    var streamURL = streamInfo.url.toString();

    return streamURL;
  } else {
    return null;
  }
}

Future<bool> checkYouTubeClosedCaptionAvailable(String videoID) async {
  String httpSubs = await http
      .read("https://www.youtube.com/api/timedtext?lang=en&v=" + videoID);
  return (httpSubs.isNotEmpty);
}

String getTimestampFromDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  String threeDigits(int n) => n.toString().padLeft(3, "0");

  String hours = twoDigits(duration.inHours);
  String mins = twoDigits(duration.inMinutes.remainder(60));
  String secs = twoDigits(duration.inSeconds.remainder(60));
  String mills = threeDigits(duration.inMilliseconds.remainder(1000));
  return "$hours:$mins:$secs.$mills";
}

String getYouTubeDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, "0");

  String hours = twoDigits(duration.inHours);
  String mins = twoDigits(duration.inMinutes.remainder(60));
  String secs = twoDigits(duration.inSeconds.remainder(60));

  if (duration.inHours != 0) {
    return "  $hours:$mins:$secs  ";
  } else if (duration.inMinutes != 0) {
    return "  $mins:$secs  ";
  } else {
    return "  0:$secs";
  }
}

String getTimeAgoFormatted(DateTime videoDate) {
  final int diffInHours = DateTime.now().difference(videoDate).inHours;

  String timeAgo = '';
  String timeUnit = '';
  int timeValue = 0;

  if (diffInHours < 1) {
    final diffInMinutes = DateTime.now().difference(videoDate).inMinutes;
    timeValue = diffInMinutes;
    timeUnit = '分';
  } else if (diffInHours < 24) {
    timeValue = diffInHours;
    timeUnit = '時間';
  } else if (diffInHours >= 24 && diffInHours < 24 * 7) {
    timeValue = (diffInHours / 24).floor();
    timeUnit = '日';
  } else if (diffInHours >= 24 * 7 && diffInHours < 24 * 30) {
    timeValue = (diffInHours / (24 * 7)).floor();
    timeUnit = '週間';
  } else if (diffInHours >= 24 * 30 && diffInHours < 24 * 12 * 30) {
    timeValue = (diffInHours / (24 * 30)).floor();
    timeUnit = 'か月';
  } else {
    timeValue = (diffInHours / (24 * 365)).floor();
    timeUnit = '年';
  }

  timeAgo = timeValue.toString() + ' ' + timeUnit;

  return timeAgo + '前';
}

String getViewCountFormatted(int num) {
  if (num > 9999 && num < 999999) {
    return "${(num / 10000).toStringAsFixed(1)}万";
  } else if (num > 999999 && num < 99999999) {
    return "${(num / 10000).toStringAsFixed(0)}万";
  } else if (num > 99999999 && num < 999999999) {
    return "${(num / 100000000).toStringAsFixed(1)}億";
  } else if (num > 999999999) {
    return "${(num / 100000000).toStringAsFixed(0)}億";
  } else {
    return num.toString();
  }
}

String formatTimeString(double time) {
  double msDouble = time * 1000;
  int milliseconds = (msDouble % 1000).floor();
  int seconds = (time % 60).floor();
  int minutes = (time / 60 % 60).floor();
  int hours = (time / 60 / 60 % 60).floor();

  String millisecondsPadded = milliseconds.toString().padLeft(3, "0");
  String secondsPadded = seconds.toString().padLeft(2, "0");
  String minutesPadded = minutes.toString().padLeft(2, "0");
  String hoursPadded = hours.toString().padLeft(2, "0");

  String formatted = hoursPadded +
      ":" +
      minutesPadded +
      ":" +
      secondsPadded +
      "," +
      millisecondsPadded;
  return formatted;
}

Future<List<Video>> searchYouTubeVideos(String searchQuery) async {
  YoutubeExplode yt = YoutubeExplode();
  SearchList searchResults = await yt.search.getVideos(searchQuery);

  List<Video> videos = [];
  for (Video video in searchResults) {
    videos.add(video);
  }

  return videos;
}

Future<List<Video>> searchYouTubeTrendingVideos() {
  YoutubeExplode yt = YoutubeExplode();
  return yt.playlists.getVideos("PLrEnWoR732-DtKgaDdnPkezM_nDidBU9H").toList();
}

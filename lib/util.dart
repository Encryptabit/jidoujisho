import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:auto_orientation/auto_orientation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:mecab_dart/mecab_dart.dart';
import 'package:path/path.dart' as path;
import 'package:subtitle_wrapper_package/data/models/style/subtitle_style.dart';
import 'package:ve_dart/ve_dart.dart';
import 'package:wakelock/wakelock.dart';

import 'package:jidoujisho/globals.dart';
import 'package:jidoujisho/preferences.dart';

enum JidoujishoPlayerMode {
  localFile,
  youtubeStream,
  networkStream,
}

class VideoHistoryPosition {
  String url;
  int position;

  VideoHistoryPosition(this.url, this.position);

  Map<String, dynamic> toMap() {
    return {
      "url": this.url,
      "position": this.position,
    };
  }

  VideoHistoryPosition.fromMap(Map<String, dynamic> map) {
    this.url = map['url'];
    this.position = map['position'];
  }

  @override
  String toString() {
    return "HistoryPosition ($url)";
  }
}

class VideoHistory {
  String url;
  String heading;
  String subheading;
  String thumbnail;
  String channelId;
  int duration;

  VideoHistory(
    this.url,
    this.heading,
    this.subheading,
    this.thumbnail,
    this.channelId,
    this.duration,
  );

  Map<String, dynamic> toMap() {
    return {
      "url": this.url,
      "heading": this.heading,
      "subheading": this.subheading,
      "thumbnail": this.thumbnail,
      "channelId": this.channelId,
      "duration": this.duration,
    };
  }

  VideoHistory.fromMap(Map<String, dynamic> map) {
    this.url = map['url'];
    this.heading = map['heading'];
    this.subheading = map['subheading'];
    this.thumbnail = map['thumbnail'];
    this.channelId = map['channelId'];
    this.duration = map['duration'];
  }

  @override
  String toString() {
    return "History ($url)";
  }
}

bool hasExternalSubtitles(File file) {
  String subtitlePath = getExternalSubtitles(file).path;
  File subtitleFile = File(subtitlePath);

  return subtitleFile.existsSync();
}

File getExternalSubtitles(File file) {
  String videoDir = path.dirname(file.path);
  String videoBasename = path.basenameWithoutExtension(file.path);
  String subtitlePath;

  subtitlePath = "$videoDir/$videoBasename.srt";
  if (File(subtitlePath).existsSync()) {
    return File(subtitlePath);
  }

  subtitlePath = "$videoDir/$videoBasename.ass";
  if (File(subtitlePath).existsSync()) {
    return File(subtitlePath);
  }

  subtitlePath = "$videoDir/$videoBasename.ssa";
  if (File(subtitlePath).existsSync()) {
    return File(subtitlePath);
  }

  return File(subtitlePath);
}

List<File> extractWebSubtitle(String webSubtitle) {
  List<File> files = [];

  String subPath = "$gAppDirPath/extractWebSrt.srt";
  File subFile = File(subPath);
  if (subFile.existsSync()) {
    subFile.deleteSync();
  }

  subFile.createSync();
  subFile.writeAsStringSync(webSubtitle);
  files.add(subFile);

  return files;
}

Future<List<File>> extractSubtitles(String inputPath) async {
  List<File> files = [];
  final FlutterFFmpeg _flutterFFmpeg = FlutterFFmpeg();

  for (int i = 0; i < 10; i++) {
    String outputPath = "\"$gAppDirPath/extractSrt$i.srt\"";
    String command =
        "-loglevel quiet -i \"$inputPath\" -map 0:s:$i $outputPath";

    String subPath = "$gAppDirPath/extractSrt$i.srt";
    File subFile = File(subPath);

    if (subFile.existsSync()) {
      subFile.deleteSync();
    }

    await _flutterFFmpeg.execute(command);

    if (await subFile.exists()) {
      if (subFile.readAsStringSync().isEmpty) {
        subFile.deleteSync();
        break;
      } else {
        files.add(subFile);
      }
    } else {
      break;
    }
  }

  return files;
}

// Future<File> extractSingleSubtitle(String inputPath, int i) async {
//   final FlutterFFmpeg _flutterFFmpeg = FlutterFFmpeg();

//   String outputPath = "\"$gAppDirPath/extractSrt$i.srt\"";
//   String command = "-loglevel quiet -i \"$inputPath\" -map 0:s:$i $outputPath";

//   String subPath = "$gAppDirPath/extractSrt$i.srt";
//   File subFile = File(subPath);

//   if (subFile.existsSync()) {
//     subFile.deleteSync();
//   }

//   await _flutterFFmpeg.execute(command);

//   if (await subFile.exists()) {
//     if (subFile.readAsStringSync().isEmpty) {
//       subFile.deleteSync();
//       return null;
//     } else {
//       return subFile;
//     }
//   } else {
//     return null;
//   }
// }

String sanitizeSrtNewlines(String text) {
  List<String> split = text.split("\n");

  for (int i = 0; i < 10; i++) {
    for (int i = 1; i < split.length; i++) {
      String currentLine = split[i];
      String previousLine = split[i - 1];

      if (previousLine.contains("-->") && currentLine.trim().isEmpty) {
        split.removeAt(i);
        split.removeAt(i - 1);
        split.removeAt(i - 2);
      }
    }
  }

  return split.join("\n");
}

String sanitizeVttNewlines(String text) {
  List<String> split = text.split("\n ");

  for (int i = 0; i < 10; i++) {
    for (int i = 1; i < split.length; i++) {
      String currentLine = split[i];
      String previousLine = split[i - 1];

      if (previousLine.contains("-->") && currentLine.trim().isEmpty) {
        split.removeAt(i);
      }
      if (previousLine.contains("-->") && currentLine.trim().isEmpty) {
        split.removeAt(i);
      }
    }
  }

  return split.join("\n");
}

Future<File> extractExternalSubtitles(File file) async {
  if (!file.existsSync()) {
    return null;
  } else if (file.path.toLowerCase().endsWith("srt")) {
    return file;
  }

  final FlutterFFmpeg _flutterFFmpeg = FlutterFFmpeg();

  String inputPath = file.path;
  String outputPath = "\"$gAppDirPath/extractExternal.srt\"";
  String command =
      "-loglevel quiet -f ass -c:s ass -i \"$inputPath\" -map 0:s:0 -c:s subrip $outputPath";

  String subPath = "$gAppDirPath/extractExternal.srt";
  File subFile = File(subPath);

  if (subFile.existsSync()) {
    subFile.deleteSync();
  }

  await _flutterFFmpeg.execute(command);
  return subFile;
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
    return "  0:$secs  ";
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
    timeUnit = 'minute';
  } else if (diffInHours < 24) {
    timeValue = diffInHours;
    timeUnit = 'hour';
  } else if (diffInHours >= 24 && diffInHours < 24 * 7) {
    timeValue = (diffInHours / 24).floor();
    timeUnit = 'day';
  } else if (diffInHours >= 24 * 7 && diffInHours < 24 * 30) {
    timeValue = (diffInHours / (24 * 7)).floor();
    timeUnit = 'week';
  } else if (diffInHours >= 24 * 30 && diffInHours < 24 * 12 * 30) {
    timeValue = (diffInHours / (24 * 30)).floor();
    timeUnit = 'month';
  } else {
    timeValue = (diffInHours / (24 * 365)).floor();
    timeUnit = 'year';
  }

  timeAgo = timeValue.toString() + ' ' + timeUnit;
  timeAgo += timeValue > 1 ? 's' : '';

  return timeAgo + ' ago';
}

String getViewCountFormatted(int num) {
  if (num > 999 && num < 99999) {
    return "${(num / 1000).toStringAsFixed(1)}K";
  } else if (num > 99999 && num < 999999) {
    return "${(num / 1000).toStringAsFixed(0)}K";
  } else if (num > 999999 && num < 999999999) {
    return "${(num / 1000000).toStringAsFixed(1)}M";
  } else if (num > 999999999) {
    return "${(num / 1000000000).toStringAsFixed(1)}B";
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

List<List<Word>> getLinesFromWords(BuildContext context, SubtitleStyle style,
    List<Word> words, double fontSize) {
  List<List<Word>> lines = [];
  List<Word> working = [];
  String concatenate = "";
  TextPainter textPainter;
  double width = MediaQuery.of(context).size.width;
  words.add(Word("", "", Grammar.Unassigned, "", Pos.TBD, "", TokenNode("")));

  for (int i = 0; i < words.length; i++) {
    Word word = words[i];
    textPainter = TextPainter()
      ..text = TextSpan(
        text: concatenate + word.word,
        style: TextStyle(fontSize: fontSize),
      )
      ..textDirection = TextDirection.ltr
      ..layout(minWidth: 0, maxWidth: double.infinity);

    if (word.word.contains('␜') ||
        i == words.length - 1 ||
        textPainter.width >=
            width - style.position.left - style.position.right - 20) {
      List<Word> line = [];
      for (int i = 0; i < working.length; i++) {
        line.add(working[i]);
      }

      lines.add(line);
      working = [];
      concatenate = "";

      working.add(word);
      concatenate += word.word;
    } else {
      working.add(word);
      concatenate += word.word;
    }
  }

  return lines;
}

List<List<int>> getIndexesFromWords(
  BuildContext context,
  SubtitleStyle style,
  List<Word> words,
  double fontSize,
) {
  words.add(Word("", "", Grammar.Unassigned, "", Pos.TBD, "", TokenNode("")));

  List<List<int>> lines = [];
  List<int> working = [];
  String concatenate = "";
  TextPainter textPainter;

  double width = MediaQuery.of(context).size.width;

  for (int i = 0; i < words.length; i++) {
    Word word = words[i];
    textPainter = TextPainter()
      ..text = TextSpan(
          text: concatenate + word.word,
          style: TextStyle(
            fontSize: fontSize,
          ))
      ..textDirection = TextDirection.ltr
      ..layout(minWidth: 0, maxWidth: double.infinity);

    if (word.word.contains('␜') ||
        i == words.length - 1 ||
        textPainter.width >=
            width - style.position.left - style.position.right) {
      List<int> line = [];
      for (int i = 0; i < working.length; i++) {
        line.add(working[i]);
      }

      lines.add(line);
      working = [];
      concatenate = "";

      working.add(i);
      concatenate += word.word;
    } else {
      working.add(i);
      concatenate += word.word;
    }
  }

  return lines;
}

String getBetterNumberTag(String text) {
  text = text.replaceAll("50)", "㊿");
  text = text.replaceAll("49)", "㊾");
  text = text.replaceAll("48)", "㊽");
  text = text.replaceAll("47)", "㊼");
  text = text.replaceAll("46)", "㊻");
  text = text.replaceAll("45)", "㊺");
  text = text.replaceAll("44)", "㊹");
  text = text.replaceAll("43)", "㊸");
  text = text.replaceAll("42)", "㊷");
  text = text.replaceAll("41)", "㊶");
  text = text.replaceAll("40)", "㊵");
  text = text.replaceAll("39)", "㊴");
  text = text.replaceAll("38)", "㊳");
  text = text.replaceAll("37)", "㊲");
  text = text.replaceAll("36)", "㊱");
  text = text.replaceAll("35)", "㉟");
  text = text.replaceAll("34)", "㉞");
  text = text.replaceAll("33)", "㉝");
  text = text.replaceAll("32)", "㉜");
  text = text.replaceAll("31)", "㉛");
  text = text.replaceAll("30)", "㉚");
  text = text.replaceAll("29)", "㉙");
  text = text.replaceAll("28)", "㉘");
  text = text.replaceAll("27)", "㉗");
  text = text.replaceAll("26)", "㉖");
  text = text.replaceAll("25)", "㉕");
  text = text.replaceAll("24)", "㉔");
  text = text.replaceAll("23)", "㉓");
  text = text.replaceAll("22)", "㉒");
  text = text.replaceAll("21)", "㉑");
  text = text.replaceAll("20)", "⑳");
  text = text.replaceAll("19)", "⑲");
  text = text.replaceAll("18)", "⑱");
  text = text.replaceAll("17)", "⑰");
  text = text.replaceAll("16)", "⑯");
  text = text.replaceAll("15)", "⑮");
  text = text.replaceAll("14)", "⑭");
  text = text.replaceAll("13)", "⑬");
  text = text.replaceAll("12)", "⑫");
  text = text.replaceAll("11)", "⑪");
  text = text.replaceAll("10)", "⑩");
  text = text.replaceAll("9)", "⑨");
  text = text.replaceAll("8)", "⑧");
  text = text.replaceAll("7)", "⑦");
  text = text.replaceAll("6)", "⑥");
  text = text.replaceAll("5)", "⑤");
  text = text.replaceAll("4)", "④");
  text = text.replaceAll("3)", "③");
  text = text.replaceAll("2)", "②");
  text = text.replaceAll("1)", "①");

  return text;
}

String getMonolingualNumberTag(String text) {
  text = text.replaceAll("(50)", "\n㊿ ");
  text = text.replaceAll("(49)", "\n㊾ ");
  text = text.replaceAll("(48)", "\n㊽ ");
  text = text.replaceAll("(47)", "\n㊼ ");
  text = text.replaceAll("(46)", "\n㊻ ");
  text = text.replaceAll("(45)", "\n㊺ ");
  text = text.replaceAll("(44)", "\n㊹ ");
  text = text.replaceAll("(43)", "\n㊸ ");
  text = text.replaceAll("(42)", "\n㊷ ");
  text = text.replaceAll("(41)", "\n㊶ ");
  text = text.replaceAll("(40)", "\n㊵ ");
  text = text.replaceAll("(39)", "\n㊴ ");
  text = text.replaceAll("(38)", "\n㊳ ");
  text = text.replaceAll("(37)", "\n㊲ ");
  text = text.replaceAll("(36)", "\n㊱ ");
  text = text.replaceAll("(35)", "\n㉟ ");
  text = text.replaceAll("(34)", "\n㉞ ");
  text = text.replaceAll("(33)", "\n㉝ ");
  text = text.replaceAll("(32)", "\n㉜ ");
  text = text.replaceAll("(31)", "\n㉛ ");
  text = text.replaceAll("(30)", "\n㉚ ");
  text = text.replaceAll("(29)", "\n㉙ ");
  text = text.replaceAll("(28)", "\n㉘ ");
  text = text.replaceAll("(27)", "\n㉗ ");
  text = text.replaceAll("(26)", "\n㉖ ");
  text = text.replaceAll("(25)", "\n㉕ ");
  text = text.replaceAll("(24)", "\n㉔ ");
  text = text.replaceAll("(23)", "\n㉓ ");
  text = text.replaceAll("(22)", "\n㉒ ");
  text = text.replaceAll("(21)", "\n㉑ ");
  text = text.replaceAll("(20)", "\n⑳ ");
  text = text.replaceAll("(19)", "\n⑲ ");
  text = text.replaceAll("(18)", "\n⑱ ");
  text = text.replaceAll("(17)", "\n⑰ ");
  text = text.replaceAll("(16)", "\n⑯ ");
  text = text.replaceAll("(15)", "\n⑮ ");
  text = text.replaceAll("(14)", "\n⑭ ");
  text = text.replaceAll("(13)", "\n⑬ ");
  text = text.replaceAll("(12)", "\n⑫ ");
  text = text.replaceAll("(11)", "\n⑪ ");
  text = text.replaceAll("(10)", "\n⑩ ");
  text = text.replaceAll("(9)", "\n⑨ ");
  text = text.replaceAll("(8)", "\n⑧ ");
  text = text.replaceAll("(7)", "\n⑦ ");
  text = text.replaceAll("(6)", "\n⑥ ");
  text = text.replaceAll("(5)", "\n⑤ ");
  text = text.replaceAll("(4)", "\n④ ");
  text = text.replaceAll("(3)", "\n③ ");
  text = text.replaceAll("(2)", "\n② ");
  text = text.replaceAll("(1)", "\n① ");

  return text;
}

// bool isCharacterFullWidthNumber(String number) {
//   switch (number.substring(0, 0)) {
//     case "１":
//     case "２":
//     case "３":
//     case "４":
//     case "５":
//     case "６":
//     case "７":
//     case "８":
//     case "９":
//     case "０":
//       return true;
//     default:
//       return false;
//   }
// }

Future<List<String>> scrapeBingImages(
    BuildContext context, String searchTerm) async {
  List<String> entries = [];

  var client = http.Client();
  http.Response response = await client.get(Uri.parse(
      'https://www.bing.com/images/search?q=$searchTerm&FORM=HDRSC2'));
  var document = parser.parse(response.body);

  List<dom.Element> imgElements = document.getElementsByClassName("iusc");

  if (imgElements == null) {
    return [];
  }

  for (dom.Element imgElement in imgElements) {
    Map<dynamic, dynamic> imgMap = jsonDecode(imgElement.attributes["m"]);
    String imageURL = imgMap["turl"];
    entries.add(imageURL);

    precacheImage(new NetworkImage(imageURL), context);
  }

  return entries;
}

String stripLatinCharactersFromText(String subtitleText) {
  subtitleText =
      subtitleText.replaceAll(RegExp(r'(?![×])[A-zÀ-ú\u0160-\u0161œû]'), "○");
  subtitleText = subtitleText.replaceAll(
      RegExp(r"[-!%^&*_+|=`;'?,.\/"
          '"'
          "]"),
      "○");

  List<String> splitText = subtitleText.split("\n");
  splitText.removeWhere((line) {
    line = line.replaceAll(":", " ");
    line = line.replaceAll("(", " ");
    line = line.replaceAll(")", " ");
    line = line.replaceAll("[", " ");
    line = line.replaceAll("]", " ");
    line = line.replaceAll("{", " ");
    line = line.replaceAll("}", " ");
    line = line.replaceAll("<", " ");
    line = line.replaceAll(">", " ");
    line = line.replaceAll("\$", " ");
    line = line.replaceAll("…", " ");
    line = line.replaceAll("~", " ");
    line = line.replaceAll("’", " ");
    line = line.replaceAll("○", " ");
    line = line.replaceAll("«", " ");
    line = line.replaceAll("»", " ");
    line = line.replaceAll("“", " ");
    line = line.replaceAll("”", " ");
    line = line.replaceAll("—", " ");
    line = line.replaceAll("♪", " ");
    line = line.replaceAll(RegExp(r"[0-9]"), " ");
    line = line.trim();

    return line.isEmpty;
  });
  subtitleText = splitText.join("\n");

  return subtitleText;
}

class BlurWidgetOptions {
  double width;
  double height;
  double left;
  double top;
  Color color;
  double blurRadius;
  bool visible;

  BlurWidgetOptions(
    this.width,
    this.height,
    this.left,
    this.top,
    this.color,
    this.blurRadius,
    this.visible,
  );
}

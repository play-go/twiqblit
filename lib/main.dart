// ignore_for_file: depend_on_referenced_packages, non_constant_identifier_names, empty_catches, use_build_context_synchronously, no_leading_underscores_for_local_identifiers

import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:twiqblit/db.dart';
import 'package:window_manager/window_manager.dart';
import 'package:fluent_ui/fluent_ui.dart' as fl;
// import 'dart:io' show Directory, Platform, File;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:open_file/open_file.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tdtx_nf_icons/tdtx_nf_icons.dart';
import 'package:archive/archive_io.dart';
import 'dart:io';
import 'dart:ui' as uii;
import 'package:xterm/xterm.dart';
import 'theme.dart';
import 'package:provider/provider.dart';
import 'package:filter_list/filter_list.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:local_notifier/local_notifier.dart';
// import 'package:flutter/rendering.dart';

//Directory.current.path
//Platform.environment['APPDATA']!
String gendir = "${Platform.environment['APPDATA']!}\\twiqblit";
String gdir = "${Platform.environment['APPDATA']!}\\.vc";
String gameplace = "${Platform.environment['APPDATA']!}\\.vc\\versions";
String modsplace = "${Platform.environment['APPDATA']!}\\.vc\\content";
String worldsplace = "${Platform.environment['APPDATA']!}\\.vc\\worlds";
String tempfile = "${Platform.environment['APPDATA']!}\\.vc\\temp.file";
String version = "v1.3.6";

DateFormat formatter = DateFormat('dd.MM.yyyy');
bool moddown = false;
Downloader? versDown;
bool showmaterials = true;
bool showmodpage = true;
double wighperc = 0;
double heigperc = 0;
String needupdate = "";
bool lautext = false;
String lautextt = "TB";

SharedPreferencesHelper prefs = SharedPreferencesHelper();

const List<String> accentColorNames = [
  'Yellow',
  'Orange',
  'Red',
  'Magenta',
  'Purple',
  'Blue',
  'Teal',
  'Green',
];

Future<void> copyDirectory(Directory source, Directory destination) async {
  await for (var entity in source.list(recursive: false)) {
    if (entity is Directory) {
      var newDirectory = Directory(
          path.join(destination.absolute.path, path.basename(entity.path)));
      await newDirectory.create();
      await copyDirectory(entity.absolute, newDirectory);
    } else if (entity is File) {
      await entity
          .copy(path.join(destination.path, path.basename(entity.path)));
    }
  }
}

Future<String> extractZipArchive(
    String zipFilePath, String destinationDirPath) async {
  final zipFile = File(zipFilePath);
  if (!await zipFile.exists()) {
    throw Exception('Архив не существует: $zipFilePath');
  }

  final bytes = await zipFile.readAsBytes();

  final archive = ZipDecoder().decodeBytes(bytes, verify: false);

  final destinationDir = Directory(destinationDirPath);
  if (!await destinationDir.exists()) {
    await destinationDir.create(recursive: true);
  }
  String res = "";
  bool bres = false;
  for (final file in archive) {
    final filePath = path.join(destinationDirPath, file.name);
    if (file.isFile) {
      final outFile = File(filePath);
      await outFile.create(recursive: true);
      await outFile.writeAsBytes(file.content as List<int>);
    } else {
      if (!bres) {
        res = file.name.split("/").first;
        if (await Directory("$destinationDirPath/$res").exists()) {
          throw Exception("Мод конфликтует с другими папками модов");
        }
        bres = true;
      } else {
        String a = file.name.split("/").first;
        if (await Directory("$destinationDirPath/$a").exists() && a != res) {
          throw Exception("Мод конфликтует с другими папками модов");
        }
      }
      final dir = Directory(filePath);
      await dir.create(recursive: true);
    }
  }

  return res;
}

Widget _buildColorBlock(AppTheme appTheme, fl.AccentColor color, int Num) {
  return Padding(
    padding: const EdgeInsets.all(2.0),
    child: fl.Button(
      onPressed: () {
        prefs.setInt('color', Num);
        appTheme.color = color;
      },
      style: fl.ButtonStyle(
        padding: const fl.WidgetStatePropertyAll(EdgeInsets.zero),
        backgroundColor: fl.WidgetStateProperty.resolveWith((states) {
          if (states.isPressed) {
            return color.light;
          } else if (states.isHovered) {
            return color.lighter;
          }
          return color;
        }),
      ),
      child: fl.Container(
        height: 40,
        width: 40,
        alignment: AlignmentDirectional.center,
        child: appTheme.color == color
            ? fl.Icon(
                fl.FluentIcons.check_mark,
                color: color.basedOnLuminance(),
                size: 22.0,
              )
            : null,
      ),
    ),
  );
}

class User {
  final String? name;
  final int? id;
  User({this.name, this.id});
}

class ObservableList<T> {
  final List<T> _list = [];

  final StreamController<T> _controller = StreamController<T>.broadcast();

  Stream<T> get onItemAdded => _controller.stream;

  void add(T item) {
    _list.add(item);
    _controller.add(item);
  }

  List<T> get items => List.unmodifiable(_list);

  void dispose() {
    _controller.close();
  }
}

void termss(line) {
  final RegExp logRegExp = RegExp(r'^\[(\w)\]\s+([\d/: .+-]+)\s+\[(.*?)\]\s+(.*)$');
        final Match? match = logRegExp.firstMatch(line);

        if (match != null) {
          String color;
          switch (match.group(1)) {
            case 'I':
              color = '\x1B[34m';
              break;
            case 'W':
              color = '\x1B[93m';
              break;
            case 'E':
              color = '\x1B[31m';
              break;
            default:
              color = '\x1B[0m';
          }
          terminal.write(
              "$color[${match.group(1)}] \x1B[33m${match.group(2)}  \x1B[90m[${match.group(3)}] \x1B[0m${match.group(4)}");
        } else {
          terminal.write(line);
        }
        terminal.nextLine();
}

class Downloader {
  final String url;
  final String filePath;
  late http.Client client;
  late File file;
  var inss = () async {};
  bool ended = false;
  bool paused = false;
  dynamic speedd, bytes, maxbytes;
  double percent = 0.0;
  int totalBytes = 0;
  final startTime = DateTime.now();
  StreamSubscription<List<int>>? subscription;
  IOSink? fileSink;

  Downloader({required this.url, required this.filePath, required this.inss}) {
    client = http.Client();
    file = File(filePath);
    try {
      file.deleteSync();
    } catch (err) {}
    file.createSync();
    fileSink = file.openWrite();
  }

  Future<void> startDownload({bool deletefile = true}) async {
    try {
      final request = http.Request('GET', Uri.parse(url));
      request.headers.clear();
      request.headers.addAll({"content-type": "application/vnd.github+json"});
      final response = await client.send(request);
      var totalFileLength = int.parse(response.headers['content-length']!);
      subscription = response.stream.listen(
        (List<int> chunk) {
          fileSink!.add(chunk);
          totalBytes += chunk.length;
          double percentDownloaded = (totalBytes / totalFileLength * 100);
          final elapsedSeconds = DateTime.now().difference(startTime).inSeconds;
          double speed = (totalBytes / elapsedSeconds) / 1024;
          bytes = totalBytes;
          maxbytes = totalFileLength;
          speedd = speed.toStringAsFixed(0);
          percent = percentDownloaded;
        },
        onDone: () async {
          await fileSink!.close();
          await subscription!.cancel();
          ended = true;
          await inss();
          if (deletefile) {
            await file.delete();
          }
        },
        onError: (e) {
        },
        cancelOnError: true,
      );
    } catch (e) {}
  }

  void pauseDownload() {
    if (paused) {
      subscription?.resume();
      paused = false;
    } else {
      subscription?.pause();
      paused = true;
    }

  }

  void resumeDownload() {
    subscription?.resume();
  }

  void cancelDownload() async {
    await subscription?.cancel();
    await fileSink?.close();
    client.close();
  }
}

final _appTheme = AppTheme();
int itemcount = 16;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // await flutter_acrylic.Window.initialize();
  await Directory(gameplace).create(recursive: true);
  _appTheme.color = fl.Colors
      .accentColors[await prefs.getInt("color", 6)];
  _appTheme.mode = ThemeMode.dark;
  itemcount = await prefs.getInt("icount", 16);
  
  await WindowManager.instance.ensureInitialized();

  windowManager.waitUntilReadyToShow().then((_) async {
    windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );

    await windowManager.center();
    await windowManager.setPreventClose(true);
    await windowManager.setSkipTaskbar(false);
  });
  // await windowManager.setIcon("/assets/icons/icon.ico");
  await localNotifier.setup(
    appName: 'TwiqBlit',
    shortcutPolicy: ShortcutPolicy.requireCreate,
  );
  await windowManager.hide();
  
  runApp(Phoenix(child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
        value: _appTheme,
        builder: (context, child) {
          final appTheme = context.watch<AppTheme>();
          return fl.FluentApp(
            title: 'TwiqBlit',
            locale: const Locale("ru"),
            builder: (context, child) {
              return Directionality(
                textDirection: appTheme.textDirection,
                child: fl.NavigationPaneTheme(
                  data: const fl.NavigationPaneThemeData(),
                  child: child!,
                ),
              );
            },
            darkTheme: fl.FluentThemeData(
                accentColor: appTheme.color, brightness: fl.Brightness.dark),
            theme: fl.FluentThemeData(
                accentColor: appTheme.color, brightness: fl.Brightness.dark),
            home: const MyHomePage(),
          );
        });
  }
}

bool needres = false;

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

Terminal terminal = Terminal(maxLines: 10000);

class _MyHomePageState extends State<MyHomePage> with WindowListener {
  int _selectedRail = 0;
  int _selectedG = 0;
  bool registred = false;
  bool butdis = false;
  bool download = false;
  bool closeonplay = true;
  bool offline = false;
  bool itemcountchanged = false;
  Timer? timer, timerr, timerrr;
  List<fl.ComboBoxItem> verlist = [];
  Map tver = {};
  Map offtver = {};
  int ascdescfilter = 1;
  List<User> selectedFilter = [];
  String dropdownItem = "Не выбрано";
  String selectedVersion = "";
  String dropdownValue = "";
  List gamelist = [];
  List<User> filtercat = [];
  String modslistfilter = "";
  int numberof = 1;
  int maxpage = 1;
  List modslist = [];
  fl.TextEditingController? playername;
  fl.TextEditingController? lautextt;
  fl.TextEditingController? checkbyname;
  String filtername = "";
  List listmods = [];
  List listmodsdir = [];
  List listmodsdate = [];
  List insmodsdir = [];
  List insworldsname = [];
  List insworlds = [];
  List insmods = [];
  List<Widget> end = [];
  List<Widget> endinst = [];
  List<Widget> endworl = [];

  void setselectedg(index) {
    _selectedG;
    setState(() => _selectedG = index);
  }

  int checklist(List i, List b) {
    if (i.length == 1 && b.length > 1) {
      if (int.tryParse(i[0])! > int.tryParse(b[1])!) {
        return 1;
      } else if (int.tryParse(i[0])! < int.tryParse(b[1])!) {
        return -1;
      }
    } else if (b.length == 1 && i.length > 1) {
      if (int.tryParse(i[1])! > int.tryParse(b[0])!) {
        return 1;
      } else if (int.tryParse(i[1])! < int.tryParse(b[0])!) {
        return -1;
      }
    }
    if (int.tryParse(i[0])! > int.tryParse(b[0])!) {
      return 1;
    } else if (int.tryParse(i[0])! < int.tryParse(b[0])!) {
      return -1;
    } else {
      if (int.tryParse(i[1])! > int.tryParse(b[1])!) {
        return 1;
      } else if (int.tryParse(i[1])! < int.tryParse(b[1])!) {
        return -1;
      } else {
        if (int.tryParse(i[2])! > int.tryParse(b[2])!) {
          return 1;
        } else if (int.tryParse(i[2])! > int.tryParse(b[2])!) {
          return -1;
        } else {
          if (i.length > 3 && b.length > 3) {
            if (int.tryParse(i[4])! > int.tryParse(b[4])!) {
              return 1;
            } else if (int.tryParse(i[4])! > int.tryParse(b[4])!) {
              return -1;
            }
          } else if (i.length > 3 && b.length <= 3) {
            return 1;
          } else if (b.length > 3 && i.length <= 3) {
            return -1;
          }
          if (int.tryParse(i[2])! > int.tryParse(b[2])!) {
            return 1;
          } else if (int.tryParse(i[2])! > int.tryParse(b[2])!) {
            return -1;
          }
          return 0;
        }
      }
    }
  }

  @override
  void initState() {
    windowManager.addListener(this);
    terminal.write(
        "Терминал существует только для \x1B[34mотображения вывода из игры\x1B[0m. Работает как во время работы игры, так и после");
    terminal.nextLine();
    terminal.write(
        "\x1B[31mЕсли игра будет запущена снова, терминал полностью очистится");
    // terminal.nextLine();
    // terminal.write();
    

    () async {
      if ((await prefs.getString("playername", "Player")).toString().isNotEmpty) {
      playername = fl.TextEditingController(
          text: await prefs.getString("playername", "Player"));
    } else {
      playername = fl.TextEditingController(text: "Player");
    }
    lautextt =
        fl.TextEditingController(text:await prefs.getString("lautextt", "TB"));
    lautext = await prefs.getBool("lautext", false);
    showmaterials = await prefs.getBool("showmaterial", false);
    closeonplay = await prefs.getBool("closeonplay", false);
      await windowManager.setResizable(true);
      await windowManager.setMinimumSize(const uii.Size(790, 400));
      await windowManager.setSize(const uii.Size(1000, 600));
      await windowManager.center();
      await windowManager.show();
      // final appTheme = context.watch<AppTheme>();

      // await flutter_acrylic.Window.setEffect(
      //     effect: flutter_acrylic.WindowEffect.acrylic,
      //     color:
      //         fl.FluentTheme.of(context).micaBackgroundColor.withOpacity(0.05));
      setState(() {});
      butdis = true;
      selectedVersion = "";
      verlist.clear();
      offline = false;
      try {
        List a = jsonDecode((await http.get(
          Uri.parse(
              "https://api.github.com/repos/MihailRis/VoxelEngine-Cpp/releases"),
          headers: <String, String>{
            'Content-Type': 'application/vnd.github+json',
          },
        ))
            .body);

        List b = jsonDecode((await http.get(
          Uri.parse(
              "https://api.github.com/repos/play-go/only-releases/releases"),
          headers: <String, String>{
            'Content-Type': 'application/vnd.github+json',
          },
        ))
            .body);
        List linside = [];
        for (var file in (await Directory(gameplace).list().toList())) {
          linside.add(file.path.split("\\").last);
        }
        for (Map i in a) {
          String id = jsonEncode(
              i["name"].toString().replaceAll(RegExp(r"v"), "").split("."));
          if (linside.contains(i["tag_name"])) {
            verlist.add(fl.ComboBoxItem(
              value: id,
              child: Text("Версия ${i['name']}",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ));
            linside.removeAt(linside.indexOf(i["tag_name"]));
          } else {
            verlist.add(fl.ComboBoxItem(
              value: id,
              child: Text("Версия ${i['name']}"),
            ));
          }
          tver.addAll({id: i});
        }
        for (Map i in b) {
          List id_d = i["name"].toString().split("-").last.split(".");
          id_d.add("1");
          String id = jsonEncode(id_d);
          if (id.length == 8) {
            continue;
          }
          i['name'] = i['name'].toString().split("-").last;
          i["tag_name"] =
              "workshop ${i["tag_name"].toString().split("-").last}";
          if (linside.contains(i["tag_name"])) {
            verlist.add(fl.ComboBoxItem(
              value: id,
              child: Text(
                "DevWorkshop ${i['name']}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ));
            linside.removeAt(linside.indexOf(i["tag_name"]));
          } else {
            verlist.add(fl.ComboBoxItem(
              value: id,
              child: Text("DevWorkshop ${i['name']}"),
            ));
          }
          tver.addAll({id: i});
        }
        var isd = 0;
        for (var en in linside) {
          verlist.add(fl.ComboBoxItem(
            value: '["${100 + isd}"]',
            child: Text(
              "$en",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ));
          tver.addAll({
            '["${100 + isd}"]': {"tag_name": en}
          });
          isd++;
        }
        verlist.sort(
            (a, b) => checklist(jsonDecode(a.value), jsonDecode(b.value)));
        verlist = verlist.reversed.toList();

        try {
          List cats = jsonDecode((await http.get(
            Uri.parse("https://voxelworld.ru/api/v1/tags?type=mods"),
            headers: <String, String>{
              'Content-Type': 'application/json',
            },
          ))
              .body)["data"];
          showmodpage = true;
          for (var i in cats) {
            filtercat.add(User(id: i['id'], name: i['title']));
          }
          updatelistmods(1);
        } catch (e) {
          showmodpage = false;
        }
        setState(
            () => selectedVersion = verlist.first.value ?? selectedVersion);
      } catch (error) {
        await fl.displayInfoBar(context, builder: (context, close) {
          return const fl.InfoBar(
            style: fl.InfoBarThemeData(),
            title:
                Text('Не удалось настроить соединение! Включён оффлайн режим'),
            severity: fl.InfoBarSeverity.info,
          );
        });
        offline = true;
        var a = Directory(gameplace).list();
        int i = 0;
        for (var file in (await a.toList())) {
          verlist.add(fl.ComboBoxItem(
            value: i.toString(),
            child: Text(file.path.split("\\").last),
          ));
          offtver[i.toString()] = file.path.split("\\").last;
          i++;
        }
        verlist = verlist.reversed.toList();
        if (verlist.isNotEmpty) {
          selectedVersion = verlist.first.value ?? selectedVersion;
        } else {
          selectedVersion = "";
          butdis = false;
        }
        setState(() {});
      }
      butdis = false;
      setState(() {});
      // verlist.sort((a, b) => int.tryParse(a.value)! - int.tryParse(b.value)!);
    }();
    () async {
      try {
        List a = jsonDecode((await http.get(
          Uri.parse("https://api.github.com/repos/play-go/twiqblit/releases"),
          headers: <String, String>{
            'Content-Type': 'application/vnd.github+json',
          },
        ))
            .body);
        if ("v${a.first["tag_name"]}" != version) {
          needupdate = jsonDecode((await http.get(
            Uri.parse(a.first["assets_url"]),
            headers: <String, String>{
              'Content-Type': 'application/vnd.github+json',
            },
          ))
                  .body)
              .first["browser_download_url"]
              .toString();
          await fl.displayInfoBar(context, builder: (context, close) {
            return const fl.InfoBar(
              isLong: true,
              style: fl.InfoBarThemeData(),
              title: Text(
                  'Найдено новое обновление лаунчера! Обновиться можно через настройки...'),
              severity: fl.InfoBarSeverity.warning,
            );
          });
        }
      } catch (e) {}
    }();
    super.initState();

    timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (download) {
        setState(() {});
      }
    });

    timerr = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      reloadcontent(false);
    });

    // timerrr = Timer.periodic(const Duration(milliseconds: 5000), (timer) {
    //   updatevkladka();
    //   setState(() {});
    // });
  }

  List tempmods = [],
      tempdirmods = [],
      tempdirdate = [],
      tempinsmodsdir = [],
      tempinsworldsname = [],
      tempworlds = [],
      tempinsmods = [];

  void reloadcontent([bool doit = true]) async {
    tempmods = [];
    tempdirmods = [];
    tempdirdate = [];
    tempinsmodsdir = [];
    tempinsworldsname = [];
    tempworlds = [];
    tempinsmods = [];
    if (Directory(modsplace).existsSync()) {
      Directory(modsplace).listSync(recursive: true).forEach((entity) {
        if (entity is File && entity.path.endsWith('launcher.json')) {
          try {
            final jsonMap = jsonDecode(entity.readAsStringSync());
            tempmods.add(jsonMap["id"]);
            tempdirdate.add(jsonMap['last']);
            tempdirmods.add(entity.path);
          } catch (e) {}
        }
      });
      Directory(modsplace).listSync(recursive: true).forEach((entity) {
        if (entity is File && entity.path.endsWith('package.json')) {
          try {
            final jsonMap = jsonDecode(entity.readAsStringSync());
            tempinsmodsdir.add(entity.path);
            tempinsmods.add(jsonMap);
          } catch (e) {}
        }
      });
    }
    if (Directory(worldsplace).existsSync()) {
      Directory(worldsplace).listSync(recursive: true).forEach((entity) {
        if (entity is File && entity.path.endsWith('world.json')) {
          try {
            final jsonMap = jsonDecode(entity.readAsStringSync());
            tempworlds.add(entity.path.replaceAll("world.json", ""));
            tempinsworldsname.add(jsonMap);
          } catch (e) {}
        }
      });
    }

    listmods.clear();
    listmodsdate.clear();
    insmods.clear();
    listmods.addAll(tempmods);
    listmodsdate.addAll(tempdirdate);
    insmods.addAll(tempinsmods);
    if (listmodsdir.length != tempdirmods.length) {
      listmodsdir.clear();
      listmodsdir.addAll(tempdirmods);
      updatevkladka();
    } else {
      listmodsdir.clear();
      listmodsdir.addAll(tempdirmods);
    }
    if (insmodsdir.length != tempinsmodsdir.length) {
      insmodsdir.clear();
      insmodsdir.addAll(tempinsmodsdir);
      updateinstmods();
    } else {
      insmodsdir.clear();
      insmodsdir.addAll(tempinsmodsdir);
    }

    if (insworlds.length != tempworlds.length) {
      insworlds.clear();
      insworlds.addAll(tempworlds);
      insworldsname.clear();
      insworldsname.addAll(tempinsworldsname);
      updateworlds();
    } else {
      insworlds.clear();
      insworlds.addAll(tempworlds);
      insworldsname.clear();
      insworldsname.addAll(tempinsworldsname);
    }

    if (doit) {
      setState(() {});
    }
  }

  void deletever() async {
    if (!offline) {
      await showDialog<String>(
        context: context,
        builder: (context) => fl.ContentDialog(
          title: const Text('Вы уверенны?'),
          content: Text(
              "Вы безвозвратно удалите версию ${tver[selectedVersion]["tag_name"]}"),
          actions: [
            fl.FilledButton(
              style: const fl.ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(Colors.redAccent)),
              child: const Text('Удалить'),
              onPressed: () async {
                Navigator.pop(context, 'User canceled dialog');
                try {
                  await Directory(
                          "$gdir\\versions\\${tver[selectedVersion]["tag_name"]}")
                      .delete(recursive: true);
                  await fl.displayInfoBar(context, builder: (context, close) {
                    return fl.InfoBar(
                      style: const fl.InfoBarThemeData(),
                      title: Text(
                          'Версия ${tver[selectedVersion]["tag_name"]} успешно удалена'),
                      severity: fl.InfoBarSeverity.success,
                    );
                  });
                } catch (error) {
                  await fl.displayInfoBar(context, builder: (context, close) {
                    return fl.InfoBar(
                      style: const fl.InfoBarThemeData(),
                      title: Text(
                          'Не удалось удалить версию ${tver[selectedVersion]["tag_name"]}'),
                      severity: fl.InfoBarSeverity.error,
                    );
                  });
                }
                reloadvers();
              },
            ),
            fl.Button(
              child: const Text('Отмена'),
              onPressed: () => Navigator.pop(context, 'User canceled dialog'),
            ),
          ],
        ),
      );
      setState(() {});
    } else {
      await showDialog<String>(
        context: context,
        builder: (context) => fl.ContentDialog(
          title: const Text('Вы уверенны?'),
          content: Text(
              "Вы безвозвратно удалите версию ${offtver[selectedVersion]}"),
          actions: [
            fl.FilledButton(
              style: const fl.ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(Colors.redAccent)),
              child: const Text('Удалить'),
              onPressed: () async {
                Navigator.pop(context, 'User canceled dialog');
                try {
                  await Directory(
                          "$gdir\\versions\\${offtver[selectedVersion]}")
                      .delete(recursive: true);
                  await fl.displayInfoBar(context, builder: (context, close) {
                    return fl.InfoBar(
                      style: const fl.InfoBarThemeData(),
                      title: Text(
                          'Версия ${offtver[selectedVersion]} успешно удалена'),
                      severity: fl.InfoBarSeverity.success,
                    );
                  });
                } catch (error) {
                  await fl.displayInfoBar(context, builder: (context, close) {
                    return fl.InfoBar(
                      style: const fl.InfoBarThemeData(),
                      title: Text(
                          'Не удалось удалить версию ${offtver[selectedVersion]}'),
                      severity: fl.InfoBarSeverity.error,
                    );
                  });
                }
                reloadvers();
              },
            ),
            fl.Button(
              child: const Text('Отмена'),
              onPressed: () => Navigator.pop(context, 'User canceled dialog'),
            ),
          ],
        ),
      );
      setState(() {});
    }
  }

  void deletecontent(name, namepack) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => fl.ContentDialog(
        title: const Text('Вы уверены?'),
        content: Text('Вы безвозвратно удалите контент пак "$namepack"'),
        actions: [
          fl.FilledButton(
            style: const fl.ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(Colors.redAccent)),
            child: const Text('Удалить'),
            onPressed: () {
              Navigator.pop(context, true);
            },
          ),
          fl.Button(
            child: const Text('Отмена'),
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
    if (result == true) {
      try {
        await Directory(name.toString().replaceAll("\\launcher.json", ""))
            .delete(recursive: true);

        fl.displayInfoBar(
          context,
          builder: (context, close) {
            return fl.InfoBar(
              style: const fl.InfoBarThemeData(),
              title: Text('Контент пак "$namepack" успешно удалён'),
              severity: fl.InfoBarSeverity.success,
            );
          },
        );
      } catch (error) {
        fl.displayInfoBar(
          context,
          builder: (context, close) {
            return fl.InfoBar(
              style: const fl.InfoBarThemeData(),
              title: Text('Не удалось удалить контент пак "$namepack"'),
              severity: fl.InfoBarSeverity.error,
            );
          },
        );
      }

      reloadcontent();
    }

    setState(() {});
  }

  void deleteworld(name, namepack) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => fl.ContentDialog(
        title: const Text('Вы уверены?'),
        content: Text('Вы безвозвратно удалите мир "$namepack"'),
        actions: [
          fl.FilledButton(
            style: const fl.ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(Colors.redAccent)),
            child: const Text('Удалить'),
            onPressed: () {
              Navigator.pop(context, true);
            },
          ),
          fl.Button(
            child: const Text('Отмена'),
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
    if (result == true) {
      try {
        await Directory(name.toString().replaceAll("\\launcher.json", ""))
            .delete(recursive: true);

        fl.displayInfoBar(
          context,
          builder: (context, close) {
            return fl.InfoBar(
              style: const fl.InfoBarThemeData(),
              title: Text('Мир "$namepack" успешно удалён'),
              severity: fl.InfoBarSeverity.success,
            );
          },
        );
      } catch (error) {
        fl.displayInfoBar(
          context,
          builder: (context, close) {
            return fl.InfoBar(
              style: const fl.InfoBarThemeData(),
              title: Text('Не удалось удалить мир "$namepack"'),
              severity: fl.InfoBarSeverity.error,
            );
          },
        );
      }

      updateworlds();
    }

    setState(() {});
  }

  void copyworld(name, namepack, colorr) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => fl.ContentDialog(
        title: const Text('Вы уверены?'),
        content: Text(
            'Мир "$namepack" будет скопирован и превратиться в "$namepack - копия"'),
        actions: [
          fl.FilledButton(
            style:
                fl.ButtonStyle(backgroundColor: WidgetStatePropertyAll(colorr)),
            child: const Text('Скопировать'),
            onPressed: () {
              Navigator.pop(context, true);
            },
          ),
          fl.Button(
            child: const Text('Отмена'),
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
    if (result == true) {
      try {
        var a_orig = name.toString().replaceAll("\\launcher.json", "");
        var a = name.toString().replaceAll("\\launcher.json", "");
        a = a.substring(0, a.length - 1);
        var b = "";
        while (true) {
          a += " - copy";
          b += " - copy";
          if (!await Directory(a).exists()) {
            break;
          }
        }
        await Directory(a).create();
        // print(a.substring(0, a.length - 1));
        await copyDirectory(Directory(a_orig), Directory(a));
        var c = jsonDecode(File("$a\\world.json").readAsStringSync());
        c["name"] += b;
        await File("$a\\world.json").writeAsString(jsonEncode(c));

        fl.displayInfoBar(
          context,
          builder: (context, close) {
            return fl.InfoBar(
              style: const fl.InfoBarThemeData(),
              title: Text('Мир "$namepack" успешно скопирован'),
              severity: fl.InfoBarSeverity.success,
            );
          },
        );
      } catch (error) {
        fl.displayInfoBar(
          context,
          builder: (context, close) {
            return fl.InfoBar(
              style: const fl.InfoBarThemeData(),
              title: Text('Не удалось скопировать мир "$namepack"'),
              severity: fl.InfoBarSeverity.error,
            );
          },
        );
      }

      updateworlds();
    }

    setState(() {});
  }

  void reloadvers([bool change = false]) async {
    butdis = true;
    setState(() {});
    if (change && offline == false) {
      selectedVersion = "";
    }
    verlist.clear();
    offline = false;
    try {
      List a = jsonDecode((await http.get(
        Uri.parse(
            "https://api.github.com/repos/MihailRis/VoxelEngine-Cpp/releases"),
        headers: <String, String>{
          'Content-Type': 'application/vnd.github+json',
        },
      ))
          .body);

      List b = jsonDecode((await http.get(
        Uri.parse(
            "https://api.github.com/repos/play-go/only-releases/releases"),
        headers: <String, String>{
          'Content-Type': 'application/vnd.github+json',
        },
      ))
          .body);
      List linside = [];
      for (var file in (await Directory(gameplace).list().toList())) {
        linside.add(file.path.split("\\").last);
      }
      for (Map i in a) {
        String id = jsonEncode(
            i["name"].toString().replaceAll(RegExp(r"v"), "").split("."));
        if (linside.contains(i["tag_name"])) {
          verlist.add(fl.ComboBoxItem(
            value: id,
            child: Text("Версия ${i['name']}",
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ));
          linside.removeAt(linside.indexOf(i["tag_name"]));
        } else {
          verlist.add(fl.ComboBoxItem(
            value: id,
            child: Text("Версия ${i['name']}"),
          ));
        }
        tver.addAll({id: i});
      }
      for (Map i in b) {
        List id_d = i["name"].toString().split("-").last.split(".");
        id_d.add("1");
        String id = jsonEncode(id_d);
        if (id.length == 8) {
          continue;
        }
        i['name'] = i['name'].toString().split("-").last;
        i["tag_name"] = "workshop ${i["tag_name"].toString().split("-").last}";
        if (linside.contains(i["tag_name"])) {
          verlist.add(fl.ComboBoxItem(
            value: id,
            child: Text(
              "DevWorkshop ${i['name']}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ));
          linside.removeAt(linside.indexOf(i["tag_name"]));
        } else {
          verlist.add(fl.ComboBoxItem(
            value: id,
            child: Text("DevWorkshop ${i['name']}"),
          ));
        }
        tver.addAll({id: i});
      }
      var isd = 0;
      for (var en in linside) {
        verlist.add(fl.ComboBoxItem(
          value: '["${100 + isd}"]',
          child: Text(
            "$en",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ));
        tver.addAll({
          '["${100 + isd}"]': {"tag_name": en}
        });
        isd++;
      }
      verlist
          .sort((a, b) => checklist(jsonDecode(a.value), jsonDecode(b.value)));
      verlist = verlist.reversed.toList();

      try {
        List cats = jsonDecode((await http.get(
          Uri.parse("https://voxelworld.ru/api/v1/tags?type=mods"),
          headers: <String, String>{
            'Content-Type': 'application/json',
          },
        ))
            .body)["data"];
        showmodpage = true;
        for (var i in cats) {
          filtercat.add(User(id: i['id'], name: i['title']));
        }
        updatelistmods(1);
      } catch (e) {
        showmodpage = false;
      }
      setState(() => selectedVersion = verlist.first.value ?? selectedVersion);
    } catch (error) {
      await fl.displayInfoBar(context, builder: (context, close) {
        return const fl.InfoBar(
          style: fl.InfoBarThemeData(),
          title: Text('Не удалось настроить соединение! Включён оффлайн режим'),
          severity: fl.InfoBarSeverity.info,
        );
      });
      offline = true;
      var a = Directory(gameplace).list();
      int i = 0;
      for (var file in (await a.toList())) {
        verlist.add(fl.ComboBoxItem(
          value: i.toString(),
          child: Text(file.path.split("\\").last),
        ));
        offtver[i.toString()] = file.path.split("\\").last;
        i++;
      }
      verlist = verlist.reversed.toList();
      if (verlist.isNotEmpty) {
        selectedVersion = verlist.first.value ?? selectedVersion;
      } else {
        selectedVersion = "";
        butdis = false;
      }
      setState(() {});
    }
    butdis = false;
    setState(() {});
    // verlist.sort((a, b) => int.tryParse(a.value)! - int.tryParse(b.value)!);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    timer!.cancel();
    timerr!.cancel();
    timerrr!.cancel();
    // windowManager.destroy();
    super.dispose();
  }

  Color invert(Color color) {
    final r = 255 - color.red;
    final g = 255 - color.green;
    final b = 255 - color.blue;

    return Color.fromARGB((color.opacity * 255).round(), r, g, b);
  }

  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose && mounted) {
      windowManager.destroy();
    }
  }

  void changeversion(e) {
    setState(() => selectedVersion = e.toString());
  }

  void installversion() async {
    String url = '';
    for (Map l in jsonDecode((await http.get(
      Uri.parse(tver[selectedVersion]["assets_url"]),
      headers: <String, String>{
        'Content-Type': 'application/vnd.github+json',
      },
    ))
        .body)) {
      if (l.isNotEmpty && l["name"].toString().split(".").last == "zip") {
        url = l["browser_download_url"];
      }
    }
    if (url != "") {
      await File(tempfile).create();
      versDown = Downloader(
          filePath: tempfile,
          url: url,
          inss: () async {
            String gamedir = "$gameplace\\${tver[selectedVersion]["tag_name"]}";
            await Directory(gamedir).create();
            var inputStream = File(tempfile).readAsBytesSync();
            var archive = ZipDecoder().decodeBytes(inputStream, verify: true);
            for (var file in archive.files) {
              if (file.isFile &&
                  file.name.startsWith(archive.files.first.name)) {
                File(
                    "$gamedir\\${file.name.replaceAll(archive.files.first.name, "").replaceAll("/", "\\")}")
                  ..createSync(recursive: true)
                  ..writeAsBytesSync(file.content as List<int>);
              }
            }
            await archive.clear();
            await fl.displayInfoBar(context, builder: (context, close) {
              return const fl.InfoBar(
                style: fl.InfoBarThemeData(),
                title: Text('Установлено! Теперь вы можете запустить игру'),
                severity: fl.InfoBarSeverity.success,
              );
            });
            download = false;
            setState(() {});
            reloadvers(false);
          });
      versDown!.startDownload();
      download = true;

      setState(() {});
    } else {
      await fl.displayInfoBar(context, builder: (context, close) {
        return const fl.InfoBar(
          style: fl.InfoBarThemeData(),
          title: Text('Не удалось начать скачивание!'),
          severity: fl.InfoBarSeverity.error,
        );
      });
      download = false;
      setState(() {});
    }
  }

  void cancelinstall() {
    download = false;
    versDown!.cancelDownload();
    setState(() {});
  }

  

  void startgame() async {
    // ProcessManager mgr = new LocalProcessManager();
    terminal = Terminal(maxLines: 10000);
    setState(() {});
    String tv;
    if (!offline) {
      tv = tver[selectedVersion]["tag_name"];
    } else {
      tv = offtver[selectedVersion];
    }
    if (File("$gameplace\\$tv\\Workshop_mod_win64.exe").existsSync()) {
      butdis = true;
      if (closeonplay) {
        await windowManager.hide();
      }
      setState(() {});
      Process a = await Process.start(
          "$gameplace\\$tv\\Workshop_mod_win64.exe", ["--dir", "../../"],
          runInShell: false, workingDirectory: "$gameplace\\$tv");
      a.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(termss);
      a.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        terminal.write("\x1B[93m${line.trim()}\x1B[0m");
        terminal.nextLine();
      });
      await a.exitCode;
      butdis = false;
      await windowManager.show();
      a.kill();
      setState(() {});
    } else if (File("$gameplace\\$tv\\VoxelCore.exe").existsSync()) {
      butdis = true;
      if (closeonplay) {
        await windowManager.hide();
      }
      setState(() {});
      Process a = await Process.start(
          "$gameplace\\$tv\\VoxelCore.exe", ["--dir", "../../"],
          runInShell: false, workingDirectory: "$gameplace\\$tv");
      a.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(termss);
      a.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        terminal.write("\x1B[93m${line.trim()}\x1B[0m");
        terminal.nextLine();
      });
      await a.exitCode;
      butdis = false;
      await windowManager.show();
      a.kill();
      setState(() {});
    } else if (File("$gameplace\\$tv\\VoxelEngine.exe").existsSync()) {
      butdis = true;
      if (closeonplay) {
        await windowManager.hide();
      }
      setState(() {});
      Process a = await Process.start(
          "$gameplace\\$tv\\VoxelEngine.exe", ["--dir", "../../"],
          runInShell: false, workingDirectory: "$gameplace\\$tv");
      a.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(termss);
      a.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        terminal.write("\x1B[93m${line.trim()}\x1B[0m");
        terminal.nextLine();
      });
      await a.exitCode;
      butdis = false;
      await windowManager.show();
      a.kill();
      setState(() {});
    } else {
      await fl.displayInfoBar(context, builder: (context, close) {
        return const fl.InfoBar(
          style: fl.InfoBarThemeData(),
          title: Text('Не найден exe файл для запуска игры!'),
          severity: fl.InfoBarSeverity.error,
        );
      });
    }
  }

  Widget progressbar() {
    if (download) {
      return SizedBox(
        width: 280,
        child: fl.ProgressBar(value: versDown!.percent),
      );
    } else {
      return const SizedBox(height: 5);
    }
  }

  void updatevkladka() async {
    end.clear();
    setState(() {});
    for (var i in modslist) {
      var expanderKey = GlobalKey<fl.ExpanderState>();
      end.add(SizedBox(
          width: 450,
          child: fl.Expander(
            key: expanderKey,
            // icon: Icon(fl.FluentIcons.info),
            trailing: !listmods.contains(i['id'])
                ? fl.IconButton(
                    icon: const fl.Icon(fl.FluentIcons.download),
                    onPressed: !moddown
                        ? () async {
                            moddown = true;
                            updatevkladka();
                            setState(() {});

                            Downloader(
                                url:
                                    "https://voxelworld.ru/api/v1/mods/${i['id']}/version/${jsonDecode((await http.get(
                                  Uri.parse(
                                      'https://voxelworld.ru/api/v1/versions/${i['id']}?type=mods&page=${jsonDecode((await http.get(
                                    Uri.parse(
                                        'https://voxelworld.ru/api/v1/versions/${i['id']}?type=mods&page=1&item_count=1'),
                                    headers: <String, String>{
                                      'Content-Type': 'application/json',
                                    },
                                  )).body)['meta']['last_page']}&item_count=1'),
                                  headers: <String, String>{
                                    'Content-Type': 'application/json',
                                  },
                                )).body)['data'].first['id']}/download",
                                filePath: tempfile,
                                inss: () async {
                                  // var inputStream =
                                  //     File(tempfile).readAsBytesSync();
                                  // var archive = ZipDecoder().decodeBytes(
                                  //     inputStream,
                                  //     verify:
                                  //         true);
                                  // for (var file
                                  //     in archive.files) {
                                  //   if (file
                                  //       .isFile) {
                                  //     print(file.name);
                                  //     File("$modsplace\\${utf8.decode(file.name.codeUnits, allowMalformed: true).replaceAll("/", "\\")}")
                                  //       ..createSync(recursive: true)
                                  //       ..writeAsBytesSync(file.content as List<int>);
                                  //   }
                                  // }
                                  // await archive
                                  //     .clear();
                                  // await inputStream
                                  //     .close();
                                  try {
                                    String a = await extractZipArchive(
                                        tempfile, modsplace);
                                    DateTime now = DateTime.now();
                                    Map data = {
                                      'id': i['id'],
                                      'last': formatter.format(now),
                                    };
                                    String jsonContent = jsonEncode(data);
                                    final file =
                                        File('$modsplace/$a/launcher.json');
                                    await file.writeAsString(jsonContent);
                                    await fl.displayInfoBar(context,
                                        builder: (context, close) {
                                      return const fl.InfoBar(
                                        style: fl.InfoBarThemeData(),
                                        title: Text(
                                            'Контент пак установлен! Теперь вы можете запустить игру'),
                                        severity: fl.InfoBarSeverity.success,
                                      );
                                    });
                                  } catch (err) {
                                    await fl.displayInfoBar(context,
                                        builder: (context, close) {
                                      return fl.InfoBar(
                                        style: const fl.InfoBarThemeData(),
                                        title: Text(err
                                            .toString()
                                            .replaceAll("Exception: ", "")),
                                        severity: fl.InfoBarSeverity.error,
                                      );
                                    });
                                  }
                                  moddown = false;
                                  reloadcontent();
                                  updatevkladka();
                                  setState(() {});
                                }).startDownload();
                          }
                        : null,
                  )
                : fl.IconButton(
                    icon: const fl.Icon(fl.FluentIcons.delete),
                    onPressed: () {
                      deletecontent(
                          listmodsdir[listmods.indexOf(i['id'])], i['title']);
                    },
                  ),
            header: Row(children: [
              Image.network(
                Uri.parse(
                        "https://voxelworld.ru/${i['pathLogo']}") //['author']['avatar']
                    .toString(),
                cacheHeight: 50,
                cacheWidth: 50,
                width: 50,
                height: 50,
              ),
              const SizedBox(width: 5),
              // Text(
              //   i["title"].toString(),
              //   overflow: TextOverflow.clip,
              //   maxLines: 1,
              //   softWrap: false,
              // )
              Flexible(
                child: Container(
                  padding: const EdgeInsets.only(right: 13.0),
                  child: Column(children: [
                    Row(children: [
                      SizedBox(
                          width: 450 - 180,
                          child: Text(
                            i['title'].toString().trim(),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ))
                    ]),
                    () {
                      List<Widget> res = [];
                      for (var i in i['tags']) {
                        res.add(fl.Card(
                            padding: EdgeInsets.zero,
                            child: Text(
                              i['title'],
                            )));
                      }
                      final ScrollController _firstController =
                          ScrollController();
                      return Row(children: [
                        SizedBox(
                            width: 450 - 180,
                            child: Scrollbar(
                                controller: _firstController,
                                child: SingleChildScrollView(
                                    controller: _firstController,
                                    scrollDirection: Axis.horizontal,
                                    child: Padding(
                                        padding: EdgeInsets.zero,
                                        child: Wrap(
                                            direction: Axis.horizontal,
                                            spacing: 5,
                                            children: res)))))
                      ]);
                    }(),
                  ]),
                ),
              ),
            ]),
            content: SizedBox(
              height: (!listmods.contains(i['id'])) ? 170 : 180,
              child: Column(
                children: [
                  Text(i["title"],
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  SingleChildScrollView(
                      child:
                          SizedBox(height: 107, child: Text(i["description"]))),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                              radius: 15,
                              backgroundImage: NetworkImage(
                                Uri.parse(
                                        "https://voxelworld.ru/${i['author']['avatar'].toString().replaceAll("https://voxelworld.ru/", "")}") //['author']['avatar']
                                    .toString(),
                              )),
                          const SizedBox(
                            width: 10,
                          ),
                          RichText(
                              text: TextSpan(
                                  text: i["author"]["name"],
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () async {
                                      await launchUrl(Uri.parse(
                                          'https://voxelworld.ru/profile/${i["author"]["id"]}'));
                                    })),
                        ],
                      ),
                      Row(
                        children: [
                          Row(children: [
                            const fl.Icon(
                              fl.FluentIcons.download,
                              size: 12,
                            ),
                            const SizedBox(width: 3),
                            Text(i["downloads"].toString(),
                                style: const TextStyle(fontWeight: FontWeight.bold))
                          ]),
                          const SizedBox(width: 5),
                          Row(children: [
                            const SizedBox(width: 5),
                            const fl.Icon(
                              fl.FluentIcons.heart,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(i["likes"].toString(),
                                style: const TextStyle(fontWeight: FontWeight.bold))
                          ]),
                        ],
                      )
                    ],
                  ),
                  // Text(() {
                  //   print(i["lastUpdateMessage"]);
                  //   var a = i["lastUpdateMessage"].toString().split(" ");

                  //   a[3] = getDayWord(int.tryParse(a[2])!);
                  //   return a.join(" ");
                  // }(),
                  if (i["lastUpdateDate"] != null)
                    Text(
                        "Последнее обновление ${DateTime.now().difference(DateTime.parse(i["lastUpdateDate"])).inDays} дней назад",
                        style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 8)),
                  const SizedBox(height: 1),
                  () {
                    if (listmods.contains(i['id'])) {
                      return Text(
                          "Скачано ${DateTime.now().difference(formatter.parseStrict(listmodsdate[listmods.indexOf(i['id'])])).inDays} дней назад",
                          style: const TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 8));
                    } else {
                      return const SizedBox();
                    }
                  }()
                ],
              ),
            ),
          )));
      // expanderKey.currentState?.isExpanded =
      //     false;
    }
  }

  void updatelistmods(int page) async {
    numberof = page;
    try {
      String filtres = "";
      for (var i in selectedFilter) {
        filtres += "tag_id[]=${i.id}&";
      }
      String titleset = "";
      try {
        if (filtername.isNotEmpty) {
          titleset = "title=$filtername";
        }
      } catch (e) {}
      Map cats = jsonDecode((await http.get(
        Uri.parse(
            "https://voxelworld.ru/api/v1/mods?$filtres$titleset&sort=$ascdescfilter&sortOrder=desc&page=$numberof&item_count=$itemcount"),
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
      ))
          .body);
      maxpage = (cats["meta"]["total"] / itemcount).ceil();
      modslist.clear();
      for (var i in cats['data']) {
        modslist.add(i);
      }
      updatevkladka();
      setState(() {});
    } catch (e) {
      await fl.displayInfoBar(context, builder: (context, close) {
        return const fl.InfoBar(
          style: fl.InfoBarThemeData(),
          title: Text(
              'Ошибка при обновлении страници модов! Проверьте соединение!'),
          severity: fl.InfoBarSeverity.error,
        );
      });
    }
  }

  void updateworlds() {
    endworl.clear();
    setState(() {});
    for (var i in insworlds) {
      var insd = insworldsname[insworlds.indexOf(i)]['name'];
      var f = File("$i\\preview.png");
      endworl.add(SizedBox(
          width: 295,
          height: 65,
          child: fl.Card(
              padding: EdgeInsets.zero,
              child: fl.ListTile(
                  trailing: Row(children: [
                    fl.IconButton(
                        icon: Icon(
                          TDTxNFIcons.nf_cod_copy,
                        ),
                        onPressed: () {
                          copyworld(
                              i, insd, fl.FluentTheme.of(context).accentColor);
                        }),
                    fl.IconButton(
                        icon: Icon(TDTxNFIcons.nf_cod_trash,
                            color: Colors.redAccent),
                        onPressed: () {
                          deleteworld(i, insd);
                        })
                  ]),
                  leading: f.existsSync() ? Image.file(f) : null,
                  title: Text(
                    insd.toString().trim(),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  )))));
    }
  }

  void updateinstmods() {
    endinst.clear();
    setState(() {});
    var insss = "~";
    for (var i in insmodsdir) {
      var ind = insmods[insmodsdir.indexOf(i)];
      try {
        insss = DateTime.now()
            .difference(formatter.parseStrict(listmodsdate[listmodsdir.indexOf(
                i.toString().replaceAll("package.json", "launcher.json"))]))
            .inDays
            .toString();
      } catch (err) {
        insss = "~";
      }
      var f = File(i.toString().replaceAll("package.json", "icon.png"));
      endinst.add(SizedBox(
          width: 295,
          height: 65,
          child: fl.Card(
              padding: EdgeInsets.zero,
              child: fl.ListTile(
                  trailing: fl.IconButton(
                      icon: Icon(TDTxNFIcons.nf_cod_trash,
                          color: Colors.redAccent),
                      onPressed: () {
                        deletecontent(
                            i.toString().replaceAll("package.json", ""),
                            ind['title'].toString().trim());
                      }),
                  leading: f.existsSync() ? Image.file(f) : null,
                  subtitle: Text("Скачано $insss дней назад"),
                  title: Text(
                    ind['title'].toString().trim(),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  )))));
    }
  }

  Widget modpages() {
    return Row(children: [
      fl.IconButton(
        icon: const Icon(fl.FluentIcons.previous),
        onPressed: (numberof > 1)
            ? () {
                setState(() {
                  if (numberof > 1) {
                    numberof--;
                    updatelistmods(numberof);
                  }
                });
              }
            : null,
      ),
      const SizedBox(width: 5),
      Text(numberof.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          textAlign: TextAlign.center),
      const SizedBox(width: 5),
      fl.IconButton(
        style: const fl.ButtonStyle(),
        icon: const Icon(fl.FluentIcons.next),
        onPressed: (numberof < maxpage)
            ? () {
                setState(() {
                  if (numberof < maxpage) {
                    numberof++;
                    updatelistmods(numberof);
                  }
                });
              }
            : null,
      ),
    ]);
  }

  Widget playbutton() {
    if (selectedVersion.isNotEmpty) {
      if (!offline) {
        if (Directory("$gameplace\\${tver[selectedVersion]["tag_name"]}")
            .existsSync()) {
          return fl.FilledButton(
            onPressed: butdis ? null : startgame,
            child: Text(
              "Запустить",
              style: GoogleFonts.montserrat(),
            ),
          );
        } else {
          if (download) {
            return fl.FilledButton(
              style: fl.ButtonStyle(
                  backgroundColor: fl.WidgetStatePropertyAll(
                      Theme.of(context).primaryColor)),
              onPressed: butdis ? null : cancelinstall,
              child: Text(
                "Отменить",
                style: GoogleFonts.montserrat(),
              ),
            );
          } else {
            if (tver[selectedVersion]["assets_url"] != null) {
              return fl.FilledButton(
                onPressed: butdis ? null : installversion,
                child: Text(
                  "Установить",
                  style: GoogleFonts.montserrat(),
                ),
              );
            } else {
              return fl.FilledButton(
                onPressed: null,
                child: Text(
                  "Установить",
                  style: GoogleFonts.montserrat(),
                ),
              );
            }
          }
        }
      } else {
        return fl.FilledButton(
          onPressed: butdis ? null : startgame,
          child: Text(
            "Запустить",
            style: GoogleFonts.montserrat(),
          ),
        );
      }
    } else {
      if (butdis) {
        return fl.FilledButton(
          onPressed: null,
          child: Text(
            "Загрузка...",
            style: GoogleFonts.montserrat(),
          ),
        );
      } else {
        return fl.FilledButton(
          onPressed: null,
          child: Text(
            "Выберите версию",
            style: GoogleFonts.montserrat(),
          ),
        );
      }
    }
  }

  final ScrollController _ffirstController = ScrollController();

  String appTitle = "TwiqBlit";
  @override
  Widget build(BuildContext context) {
    final appTheme = context.watch<AppTheme>();
    final theme = fl.FluentTheme.of(context);
    uii.Size size = MediaQuery.of(context).size;
    wighperc = (size.width / 100);
    heigperc = (size.height / 100);
    return fl.NavigationView(
        appBar: fl.NavigationAppBar(
            height: heigperc * 6,
            automaticallyImplyLeading: false,
            title: DragToMoveArea(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text("$appTitle $version",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: appTheme.color,
                    )),
              ),
            ),
            actions: const WindowButtons()),
        transitionBuilder: (child, animation) {
          return fl.SuppressPageTransition(
            child: child,
          );
        },
        pane: fl.NavigationPane(
          size: const fl.NavigationPaneSize(compactWidth: 60),
          displayMode: fl.PaneDisplayMode.compact,
          menuButton: Container(),
          // fl.StickyNavigationIndicator
          indicator: const fl.NoAnimNavigationIndicator(),
          footerItems: [
            fl.PaneItem(
                body: Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(
                      child: Container(
                          padding: const EdgeInsets.all(0),
                          child: !lautext
                              ? const Image(
                                  fit: BoxFit.cover,
                                  image: AssetImage('assets/menuimage.png'))
                              : Container(
                                  alignment: Alignment.center,
                                  child: Text(lautextt?.text ?? "",
                                      style: const TextStyle(
                                          fontSize: 175,
                                          fontWeight: FontWeight.bold)),
                                ))),
                  const Positioned.fill(
                      child: fl.Acrylic(
                    shadowColor: Colors.blueAccent,
                    luminosityAlpha: 0.9,
                    blurAmount: 10,
                  )),
                  Positioned.fill(
                      child: Padding(
                    padding: const EdgeInsets.all(0),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      width: size.width,
                      child: Scrollbar(
                        controller: _ffirstController,
                        child: SingleChildScrollView(
                            controller: _ffirstController,
                            scrollDirection: Axis.vertical,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Настройки лаунчера",
                                    style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 25)),
                                const SizedBox(height: 5),
                                fl.Checkbox(
                                  checked: closeonplay,
                                  content: const Text(
                                    "Скрывать лаунчер при запуске игры",
                                    textAlign: TextAlign.center,
                                  ),
                                  onChanged: (v) => setState(() {
                                    prefs.setBool("closeonplay", v!);
                                    closeonplay = v;
                                  }),
                                ),
                                const SizedBox(height: 5),
                                fl.Checkbox(
                                  checked: showmaterials,
                                  content: const Text(
                                    "Показывать используемые материалы",
                                    textAlign: TextAlign.center,
                                  ),
                                  onChanged: (v) => setState(() {
                                    prefs.setBool("showmaterial", v!);
                                    showmaterials = v;
                                  }),
                                ),
                                const SizedBox(height: 5),
                                fl.InfoLabel(
                                    label:
                                        "количество модов на одной странице ${itemcountchanged
                                                ? "(требуется перезапуск)"
                                                : ""}",
                                    isHeader: false,
                                    child: SizedBox(
                                        width: 110,
                                        child: fl.NumberBox(
                                          min: 0,
                                          max: 100,
                                          value: itemcount,
                                          onChanged: (value) async {
                                            if (value != null &&
                                                !value.isNaN &&
                                                !value.isNegative) {
                                              itemcountchanged = true;
                                              itemcount = value;
                                              prefs.setInt("icount", value);
                                            } else {
                                              itemcount = await prefs.getInt("icount", 15);
                                            }
                                            setState(() {});
                                          },
                                          clearButton: false,
                                          mode: fl
                                              .SpinButtonPlacementMode.compact,
                                        ))),
                                const SizedBox(height: 5),
                                fl.Checkbox(
                                  checked: lautext,
                                  content: const Text(
                                    "Скрыть изображение на фоне",
                                    textAlign: TextAlign.center,
                                  ),
                                  onChanged: (v) => setState(() {
                                    prefs.setBool("lautext", v!);
                                    lautext = v;
                                  }),
                                ),
                                lautext
                                    ? Column(children: [
                                        const SizedBox(height: 5),
                                        fl.InfoLabel(
                                            label: "буквы на заднем фоне",
                                            isHeader: false,
                                            child: SizedBox(
                                                width: 110,
                                                child: fl.TextBox(
                                                  controller: lautextt,
                                                  placeholder: "TB",
                                                  onChanged: (value) {
                                                    // lautextt?.text =
                                                    //     value;
                                                    prefs.setString("lautextt", value);
                                                    setState(() {});
                                                  },
                                                )))
                                      ])
                                    : Container(),
                                const SizedBox(height: 8),
                                Row(children: [
                                  fl.FilledButton(
                                    child: const Text("Перезапустить лаунчер"),
                                    onPressed: () async {
                                      await showDialog<String>(
                                        context: context,
                                        builder: (context) => fl.ContentDialog(
                                          title: const Text('Вы уверенны?'),
                                          content: fl.HyperlinkButton(
                                            child: const Text("X_x"),
                                            onPressed: () async {
                                              await launchUrl(Uri.parse(
                                                  "https://www.youtube.com/watch?v=dQw4w9WgXcQ"));
                                            },
                                          ),
                                          actions: [
                                            fl.FilledButton(
                                              style: const fl.ButtonStyle(
                                                  backgroundColor:
                                                      WidgetStatePropertyAll(
                                                          Colors.redAccent)),
                                              child:
                                                  const Text('Перезапустить'),
                                              onPressed: () async {
                                                Navigator.pop(context,
                                                    'User canceled dialog');
                                                await windowManager.hide();
                                                Phoenix.rebirth(context);
                                              },
                                            ),
                                            fl.Button(
                                              child: const Text('Отмена'),
                                              onPressed: () => Navigator.pop(
                                                  context,
                                                  'User canceled dialog'),
                                            ),
                                          ],
                                        ),
                                      );
                                      setState(() {});
                                    },
                                  ),
                                  const SizedBox(width: 5),
                                  fl.FilledButton(
                                      onPressed: needupdate.isNotEmpty
                                          ? () async {
                                              await windowManager.hide();
                                              LocalNotification(
                                                title: "Скачивание обновления",
                                                body:
                                                    "Не бойтесь! Приложение закрылось для обновления",
                                              ).show();
                                              Downloader(
                                                url: needupdate,
                                                filePath: "$tempfile.exe",
                                                inss: () async {
                                                  LocalNotification(
                                                    title:
                                                        "Установите обновление через инсталлер",
                                                  ).show();
                                                  await Process.start(
                                                      "$tempfile.exe", [],
                                                      runInShell: true,
                                                      workingDirectory:
                                                          gdir);
                                                  await windowManager.destroy();
                                                },
                                              ).startDownload(
                                                  deletefile: false);
                                            }
                                          : null,
                                      style: needupdate.isNotEmpty
                                          ? const fl.ButtonStyle(
                                              backgroundColor:
                                                  WidgetStatePropertyAll(
                                                      Colors.blueAccent))
                                          : null,
                                      child: const Text("Обновить лаунчер")),
                                  const SizedBox(width: 5),
                                  fl.FilledButton(
                                    style: const fl.ButtonStyle(
                                        backgroundColor: WidgetStatePropertyAll(
                                            Colors.redAccent)),
                                    onPressed: () async {
                                      await showDialog<String>(
                                        context: context,
                                        builder: (context) => fl.ContentDialog(
                                          title:
                                              const Text('Вы точно уверенны?'),
                                          content: const Text(
                                              "Вы ещё удалите папку .vc в которой все ваши данные🥺"),
                                          actions: [
                                            fl.FilledButton(
                                              style: const fl.ButtonStyle(
                                                  backgroundColor:
                                                      WidgetStatePropertyAll(
                                                          Colors.redAccent)),
                                              child: const Text(
                                                  'Да, я хочу удалить TwiqBlit'),
                                              onPressed: () async {
                                                Navigator.pop(context,
                                                    'User canceled dialog');
                                                await windowManager.hide();
                                                LocalNotification(
                                                  title:
                                                      "Change da world... my final message. Goodbye",
                                                ).show();
                                                await Directory(gdir)
                                                    .delete(recursive: true);

                                                await Process.start(
                                                    "unins000.exe", [],
                                                    runInShell: true,
                                                    workingDirectory: Platform
                                                        .resolvedExecutable
                                                        .replaceAll(
                                                            "\\twiqblit.exe",
                                                            ""));
                                                await windowManager.destroy();
                                              },
                                            ),
                                            fl.Button(
                                                child: const Text(
                                                    'Неееет, я случайно нажал'),
                                                onPressed: () async {
                                                  Navigator.pop(context,
                                                      'User canceled dialog');
                                                  await fl.displayInfoBar(
                                                      context, builder:
                                                          (context, close) {
                                                    return const fl.InfoBar(
                                                      isLong: true,
                                                      style:
                                                          fl.InfoBarThemeData(),
                                                      title: Text(':)'),
                                                      severity: fl
                                                          .InfoBarSeverity
                                                          .success,
                                                    );
                                                  });
                                                }),
                                          ],
                                        ),
                                      );
                                      setState(() {});
                                    },
                                    child: const Text("Удалить лаунчер"),
                                  ),
                                ]),
                                const SizedBox(height: 20),
                                Text("Настройки игры",
                                    style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 25)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    fl.FilledButton(
                                      child: const Text("Удалить screenshots"),
                                      onPressed: () async {
                                        await showDialog<String>(
                                          context: context,
                                          builder: (context) =>
                                              fl.ContentDialog(
                                            title: const Text('Вы уверенны?'),
                                            content: const Text(
                                                "Вы безвозвратно удалите папку screenshots (т.е все скриншоты из игры и со всех версий)..."),
                                            actions: [
                                              fl.FilledButton(
                                                style: const fl.ButtonStyle(
                                                    backgroundColor:
                                                        WidgetStatePropertyAll(
                                                            Colors.redAccent)),
                                                child: const Text('Удалить'),
                                                onPressed: () async {
                                                  Navigator.pop(context,
                                                      'User canceled dialog');
                                                  try {
                                                    await Directory(
                                                            "$gdir\\screenshots")
                                                        .delete(
                                                            recursive: true);
                                                    await fl.displayInfoBar(
                                                        context, builder:
                                                            (context, close) {
                                                      return const fl.InfoBar(
                                                        style: fl
                                                            .InfoBarThemeData(),
                                                        title: Text(
                                                            'Папка screenshots успешно удалена'),
                                                        severity: fl
                                                            .InfoBarSeverity
                                                            .success,
                                                      );
                                                    });
                                                  } catch (error) {
                                                    await fl.displayInfoBar(
                                                        context, builder:
                                                            (context, close) {
                                                      return const fl.InfoBar(
                                                        style: fl
                                                            .InfoBarThemeData(),
                                                        title: Text(
                                                            'Не удалось удалить папку screenshots'),
                                                        severity: fl
                                                            .InfoBarSeverity
                                                            .error,
                                                      );
                                                    });
                                                  }
                                                },
                                              ),
                                              fl.Button(
                                                child: const Text('Отмена'),
                                                onPressed: () => Navigator.pop(
                                                    context,
                                                    'User canceled dialog'),
                                              ),
                                            ],
                                          ),
                                        );
                                        setState(() {});
                                      },
                                    ),
                                    const SizedBox(width: 5),
                                    fl.FilledButton(
                                      child: const Text("Удалить worlds"),
                                      onPressed: () async {
                                        await showDialog<String>(
                                          context: context,
                                          builder: (context) =>
                                              fl.ContentDialog(
                                            title: const Text('Вы уверенны?'),
                                            content: const Text(
                                                "Вы безвозвратно удалите папку worlds (т.е все миры из игры и со всех версий)..."),
                                            actions: [
                                              fl.FilledButton(
                                                style: const fl.ButtonStyle(
                                                    backgroundColor:
                                                        WidgetStatePropertyAll(
                                                            Colors.redAccent)),
                                                child: const Text('Удалить'),
                                                onPressed: () async {
                                                  Navigator.pop(context,
                                                      'User canceled dialog');
                                                  try {
                                                    await Directory(
                                                            "$gdir\\worlds")
                                                        .delete(
                                                            recursive: true);
                                                    await fl.displayInfoBar(
                                                        context, builder:
                                                            (context, close) {
                                                      return const fl.InfoBar(
                                                        style: fl
                                                            .InfoBarThemeData(),
                                                        title: Text(
                                                            'Папка worlds успешно удалена'),
                                                        severity: fl
                                                            .InfoBarSeverity
                                                            .success,
                                                      );
                                                    });
                                                  } catch (error) {
                                                    await fl.displayInfoBar(
                                                        context, builder:
                                                            (context, close) {
                                                      return const fl.InfoBar(
                                                        style: fl
                                                            .InfoBarThemeData(),
                                                        title: Text(
                                                            'Не удалось удалить папку worlds'),
                                                        severity: fl
                                                            .InfoBarSeverity
                                                            .error,
                                                      );
                                                    });
                                                  }
                                                },
                                              ),
                                              fl.Button(
                                                child: const Text('Отмена'),
                                                onPressed: () => Navigator.pop(
                                                    context,
                                                    'User canceled dialog'),
                                              ),
                                            ],
                                          ),
                                        );
                                        setState(() {});
                                      },
                                    ),
                                    const SizedBox(width: 5),
                                    fl.FilledButton(
                                      child: const Text("Удалить version"),
                                      onPressed: () async {
                                        await showDialog<String>(
                                          context: context,
                                          builder: (context) =>
                                              fl.ContentDialog(
                                            title: const Text('Вы уверенны?'),
                                            content: const Text(
                                                "Вы безвозвратно удалите папку versions (т.е все сохранённые версии игры)..."),
                                            actions: [
                                              fl.FilledButton(
                                                style: const fl.ButtonStyle(
                                                    backgroundColor:
                                                        WidgetStatePropertyAll(
                                                            Colors.redAccent)),
                                                child: const Text('Удалить'),
                                                onPressed: () async {
                                                  Navigator.pop(context,
                                                      'User canceled dialog');
                                                  try {
                                                    selectedVersion = "";
                                                    await Directory(
                                                            "$gdir\\versions")
                                                        .delete(
                                                            recursive: true);
                                                    await Directory(
                                                            "$gdir\\versions")
                                                        .create(
                                                            recursive: true);
                                                    await fl.displayInfoBar(
                                                        context, builder:
                                                            (context, close) {
                                                      return const fl.InfoBar(
                                                        style: fl
                                                            .InfoBarThemeData(),
                                                        title: Text(
                                                            'Папка versions успешно удалена'),
                                                        severity: fl
                                                            .InfoBarSeverity
                                                            .success,
                                                      );
                                                    });
                                                    reloadvers();
                                                  } catch (error) {
                                                    await fl.displayInfoBar(
                                                        context, builder:
                                                            (context, close) {
                                                      return const fl.InfoBar(
                                                        style: fl
                                                            .InfoBarThemeData(),
                                                        title: Text(
                                                            'Не удалось удалить папку versions'),
                                                        severity: fl
                                                            .InfoBarSeverity
                                                            .error,
                                                      );
                                                    });
                                                  }
                                                },
                                              ),
                                              fl.Button(
                                                child: const Text('Отмена'),
                                                onPressed: () => Navigator.pop(
                                                    context,
                                                    'User canceled dialog'),
                                              ),
                                            ],
                                          ),
                                        );
                                        setState(() {});
                                      },
                                    )
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Text("Тема",
                                    style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 25)),
                                fl.Card(
                                    child: Column(children: [
                                  Text("Цветовая схема",
                                      style: GoogleFonts.montserrat(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                  Wrap(children: [
                                    ...List.generate(
                                        fl.Colors.accentColors.length, (index) {
                                      final color =
                                          fl.Colors.accentColors[index];
                                      return Tooltip(
                                        message: accentColorNames[index],
                                        child: _buildColorBlock(
                                            appTheme, color, index),
                                      );
                                    }),
                                  ])
                                ])),
                              ],
                            )),
                      ),
                    ),
                  )),
                  showmaterials
                      ? Container(
                          padding: const EdgeInsets.all(10),
                          alignment: Alignment.topRight,
                          child: SizedBox(
                            width: 450,
                            height: 160,
                            child: fl.Card(
                              child: Column(children: [
                                const Text("Используемые материалы",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                const SizedBox(
                                  height: 8,
                                ),
                                Row(children: [
                                  const Text("TwiqBlit (этот лаунчер) (by play-go)",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 5),
                                  fl.IconButton(
                                    icon: Icon(TDTxNFIcons.nf_fa_github),
                                    onPressed: () async {
                                      await launchUrl(Uri.parse(
                                          "https://github.com/play-go/twiqblit"));
                                    },
                                  ),
                                  fl.IconButton(
                                    icon: Icon(TDTxNFIcons.nf_fa_youtube),
                                    onPressed: () async {
                                      await launchUrl(Uri.parse(
                                          "https://www.youtube.com/@KaBoTYT"));
                                    },
                                  )
                                ]),
                                Row(children: [
                                  const Text("Voxel Core (by MihailRis)",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 5),
                                  fl.IconButton(
                                    icon: Icon(TDTxNFIcons.nf_fa_github),
                                    onPressed: () async {
                                      await launchUrl(Uri.parse(
                                          "https://github.com/MihailRis/VoxelEngine-Cpp"));
                                    },
                                  ),
                                  fl.IconButton(
                                    icon: Icon(TDTxNFIcons.nf_fa_youtube),
                                    onPressed: () async {
                                      await launchUrl(Uri.parse(
                                          "https://youtube.com/MihailRis"));
                                    },
                                  )
                                ]),
                                Row(children: [
                                  const Text(
                                      "Workshop mod (aka DevWorkshop) (by clasher113)",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 5),
                                  fl.IconButton(
                                    icon: Icon(TDTxNFIcons.nf_fa_github),
                                    onPressed: () async {
                                      await launchUrl(Uri.parse(
                                          "https://github.com/clasher113/VoxelEngine-Cpp"));
                                    },
                                  ),
                                ]),
                                Row(children: [
                                  const Text("VoxelWorld (by zellrus)",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 5),
                                  fl.IconButton(
                                    icon: Icon(TDTxNFIcons.nf_cod_browser),
                                    onPressed: () async {
                                      await launchUrl(
                                          Uri.parse("https://voxelworld.ru/"));
                                    },
                                  ),
                                ]),
                              ]),
                            ),
                          ))
                      : Container()
                ]),
                icon: Icon(fl.FluentIcons.settings,
                    color: theme.accentColor, size: 25),
                title: const Text("Настройки"))
          ],
          items: [
            fl.PaneItem(
                body: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                        child: Container(
                            padding: const EdgeInsets.all(0),
                            child: !lautext
                                ? const Image(
                                    fit: BoxFit.cover,
                                    image: AssetImage('assets/menuimage.png'))
                                : Container(
                                    alignment: Alignment.center,
                                    child: Text(lautextt?.text ?? "",
                                        style: const TextStyle(
                                            fontSize: 175,
                                            fontWeight: FontWeight.bold)),
                                  ))),
                    const Positioned.fill(
                        child: fl.Acrylic(
                      shadowColor: Colors.blueAccent,
                      luminosityAlpha: 0.9,
                      blurAmount: 10,
                    )),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(0),
                        child: Container(
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: 350,
                              height: 225,
                              child: fl.Card(
                                // backgroundColor: Theme.of(context)
                                //     .colorScheme
                                //     .secondary
                                //     .withAlpha(20),
                                child: Column(
                                  children: [
                                    fl.TextBox(
                                      controller: playername,
                                      placeholder:
                                          "Имя пользователя (нет функционала)",
                                      readOnly: download,
                                      onChanged: (value) {
                                        if (value.isEmpty) {
                                          butdis = true;
                                        } else {
                                          butdis = false;
                                        }
                                        prefs.setString("playername", value);
                                        setState(() {});
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    fl.ComboBox(
                                      value: selectedVersion,
                                      items: verlist,
                                      onChanged:
                                          download ? null : changeversion,
                                      placeholder: Container(width: 280),
                                    ),
                                    const SizedBox(height: 12),
                                    progressbar(),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                        width: size.width,
                                        height: 50,
                                        child: playbutton()),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        fl.Button(
                                            style: const fl.ButtonStyle(
                                                iconSize:
                                                    fl.WidgetStatePropertyAll(
                                                        25)),
                                            onPressed: () {
                                              OpenFile.open(gdir);
                                            },
                                            child: Icon(
                                                TDTxNFIcons.nf_cod_folder)),
                                        const SizedBox(width: 10),
                                        fl.Button(
                                            style: const fl.ButtonStyle(
                                                iconSize:
                                                    fl.WidgetStatePropertyAll(
                                                        25)),
                                            onPressed: !download && !butdis
                                                ? () {
                                                    reloadvers();
                                                  }
                                                : null,
                                            child: Icon(
                                                TDTxNFIcons.nf_cod_refresh)),
                                        const SizedBox(width: 10),
                                        fl.Button(
                                            style: const fl.ButtonStyle(
                                                iconSize:
                                                    fl.WidgetStatePropertyAll(
                                                        25)),
                                            onPressed: verlist.isNotEmpty &&
                                                    !butdis &&
                                                    Directory(() {
                                                      try {
                                                        return "$gameplace\\${tver[selectedVersion]["tag_name"]}";
                                                      } catch (e) {
                                                        return "C:\\";
                                                      }
                                                    }())
                                                        .existsSync()
                                                ? () {
                                                    deletever();
                                                  }
                                                : null,
                                            child:
                                                Icon(TDTxNFIcons.nf_cod_trash,
                                                    color: verlist.isNotEmpty &&
                                                            !butdis &&
                                                            Directory(() {
                                                              try {
                                                                return "$gameplace\\${tver[selectedVersion]["tag_name"]}";
                                                              } catch (e) {
                                                                return "C:\\";
                                                              }
                                                            }())
                                                                .existsSync()
                                                        ? Colors.redAccent
                                                        : Colors.grey))
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            )),
                      ),
                    )
                  ],
                ),
                title: const Text("Меню"),
                icon: Icon(TDTxNFIcons.nf_cod_game,
                    color: theme.accentColor, size: 26)),
            // fl.PaneItem(
            //     body: Stack(clipBehavior: Clip.none, children: [
            //       Positioned.fill(
            //           child: Container(
            //               padding: const EdgeInsets.all(0),
            //               child: const Image(
            //                   fit: BoxFit.cover,
            //                   image: AssetImage('assets/menuimage.png')))),
            //       Positioned.fill(
            //           child: Padding(
            //               padding: const EdgeInsets.all(0),
            //               child: fl.Acrylic(
            //                   shadowColor: Colors.blueAccent,
            //                   luminosityAlpha: 0.9,
            //                   blurAmount: 10,
            //                   child: Container(
            //                       alignment: Alignment.center,
            //                       child: Text("hello")))))
            //     ]),
            //     title: const Text("Версии"),
            //     icon: const Icon(fl.FluentIcons.folder_open, size: 25)),
            fl.PaneItem(
                body: Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(
                      child: Container(
                          padding: const EdgeInsets.all(0),
                          child: !lautext
                              ? const Image(
                                  fit: BoxFit.cover,
                                  image: AssetImage('assets/menuimage.png'))
                              : Container(
                                  alignment: Alignment.center,
                                  child: Text(lautextt?.text ?? "",
                                      style: const TextStyle(
                                          fontSize: 175,
                                          fontWeight: FontWeight.bold)),
                                ))),
                  const Positioned.fill(
                      child: fl.Acrylic(
                    shadowColor: Colors.blueAccent,
                    luminosityAlpha: 0.9,
                    blurAmount: 10,
                  )),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(0),
                      child: Column(
                        children: [
                          SizedBox(
                              // padding: EdgeInsets.all(5),
                              width: size.width,
                              height: size.height - heigperc * 6,
                              child: TerminalView(
                                terminal,
                                shortcuts: const {
                                  SingleActivator(LogicalKeyboardKey.keyC,
                                          control: true):
                                      CopySelectionTextIntent.copy,
                                  SingleActivator(LogicalKeyboardKey.keyA,
                                          control: true):
                                      SelectAllTextIntent(
                                          SelectionChangedCause.keyboard)
                                },
                                theme: TerminalTheme(
                                  background: Colors.black,
                                  foreground: Colors.white,
                                  cursor:
                                      const Color.fromARGB(255, 255, 255, 255),
                                  black: Colors.black,
                                  red: Colors.red,
                                  green: Colors.green,
                                  yellow:
                                      const Color.fromARGB(255, 248, 236, 128),
                                  blue: Colors.blue,
                                  magenta: Colors.purple,
                                  cyan: Colors.cyan,
                                  white: Colors.white,
                                  brightBlack: Colors.grey,
                                  brightRed: Colors.redAccent,
                                  brightGreen: Colors.lightGreen,
                                  brightYellow: Colors.yellowAccent,
                                  brightBlue: Colors.lightBlue,
                                  brightMagenta: Colors.pink,
                                  brightCyan: Colors.tealAccent,
                                  brightWhite: Colors.white70,
                                  selection: Colors.blue.withOpacity(
                                      0.3),
                                  searchHitBackground: Colors
                                      .yellow,
                                  searchHitBackgroundCurrent: Colors
                                      .orange,
                                  searchHitForeground: Colors
                                      .black,
                                ),
                                readOnly: true,
                                backgroundOpacity: 0.25,
                                autofocus: true,
                              ))
                        ],
                      ),
                    ),
                  ),
                ]),
                title: const Text("Терминал"),
                icon: Icon(TDTxNFIcons.nf_cod_terminal_cmd,
                    color: theme.accentColor, size: 26)),
            if (showmodpage)
              fl.PaneItem(
                body: Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(
                      child: Container(
                          padding: const EdgeInsets.all(0),
                          child: !lautext
                              ? const Image(
                                  fit: BoxFit.cover,
                                  image: AssetImage('assets/menuimage.png'))
                              : Container(
                                  alignment: Alignment.center,
                                  child: Text(lautextt?.text ?? "",
                                      style: const TextStyle(
                                          fontSize: 175,
                                          fontWeight: FontWeight.bold)),
                                ))),
                  const Positioned.fill(
                      child: fl.Acrylic(
                    shadowColor: Colors.blueAccent,
                    luminosityAlpha: 0.9,
                    blurAmount: 10,
                  )),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(0),
                      child: Column(
                        children: [
                          SizedBox(
                              width: size.width,
                              height: size.height - heigperc * 6,
                              child: Column(
                                children: [
                                  Container(
                                    alignment: Alignment.topCenter,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 5, horizontal: 5),
                                    width: size.width,
                                    child: fl.Card(
                                      child: fl.Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          fl.Row(children: [
                                            SizedBox(
                                                height: 35,
                                                child: fl.ComboBox<int>(
                                                  value: ascdescfilter,
                                                  items: const [
                                                    fl.ComboBoxItem(
                                                        value: 1,
                                                        child: Text(
                                                            "По популярности")),
                                                    fl.ComboBoxItem(
                                                        value: 2,
                                                        child: Text(
                                                            "По подпискам")),
                                                    fl.ComboBoxItem(
                                                        value: 3,
                                                        child: Text(
                                                            "По дате добавления")),
                                                    fl.ComboBoxItem(
                                                        value: 4,
                                                        child: Text(
                                                            "Последние обновления")),
                                                  ],
                                                  onChanged: (color) =>
                                                      setState(() {
                                                    ascdescfilter = color!;
                                                    updatelistmods(numberof);
                                                  }),
                                                )),
                                            const SizedBox(
                                              width: 5,
                                            ),
                                            SizedBox(
                                                width: 100,
                                                height: 35,
                                                child: fl.Button(
                                                  child: Text(selectedFilter.isEmpty
                                                      ? "Фильтры"
                                                      : "${selectedFilter.length}x"),
                                                  onPressed: () async {
                                                    await FilterListDialog
                                                        .display<User>(
                                                      context,
                                                      listData: filtercat,
                                                      themeData:
                                                          FilterListThemeData
                                                              .dark(context),
                                                      choiceChipBuilder:
                                                          (context, item,
                                                              isSelected) {
                                                        return fl.Card(
                                                          margin: const EdgeInsets
                                                              .symmetric(
                                                                  vertical: 8,
                                                                  horizontal:
                                                                      5),
                                                          padding:
                                                              const EdgeInsets.all(5),
                                                          borderColor: isSelected!
                                                              ? _appTheme.color
                                                              : theme.resources
                                                                  .cardStrokeColorDefault,
                                                          child: Text(item.name,
                                                              style:
                                                                  const fl.TextStyle(
                                                                      fontSize:
                                                                          15)),
                                                        );
                                                      },
                                                      applyButtonText:
                                                          "Принять",
                                                      allButtonText: "Все",
                                                      insetPadding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 120.0,
                                                              vertical: 80.0),
                                                      width: 500,
                                                      height: 250,
                                                      // borderRadius: 1,
                                                      borderRadius: 5,
                                                      backgroundColor: theme
                                                          .resources
                                                          .cardBackgroundFillColorDefault,
                                                      resetButtonText: "Ресет",
                                                      barrierDismissible: false,
                                                      hideSearchField: true,
                                                      hideSelectedTextCount:
                                                          true,
                                                      hideCloseIcon: true,
                                                      useSafeArea: false,
                                                      useRootNavigator: false,
                                                      hideHeader: true,
                                                      selectedListData:
                                                          selectedFilter,
                                                      choiceChipLabel: (user) =>
                                                          user!.name,
                                                      validateSelectedItem:
                                                          (list, val) => list!
                                                              .contains(val),
                                                      onItemSearch:
                                                          (user, query) {
                                                        return user.name!
                                                            .toLowerCase()
                                                            .contains(query
                                                                .toLowerCase());
                                                      },
                                                      onApplyButtonClick:
                                                          (list) {
                                                        setState(() {
                                                          selectedFilter =
                                                              List.from(list!);
                                                          updatelistmods(1);
                                                        });
                                                        Navigator.pop(context);
                                                      },
                                                    );
                                                  },
                                                ))
                                          ]),
                                          Row(children: [
                                            SizedBox(
                                                height: 35,
                                                width: 200,
                                                child: fl.TextBox(
                                                  controller: checkbyname,
                                                  onChanged: (value) {
                                                    filtername = value;
                                                  },
                                                  placeholder: "Поиск",
                                                  onEditingComplete: () {
                                                    setState(() {
                                                      updatelistmods(1);
                                                    });
                                                  },
                                                )),
                                            const SizedBox(
                                              width: 4,
                                            ),
                                            fl.Card(
                                                margin: EdgeInsets.zero,
                                                padding: EdgeInsets.zero,
                                                child: fl.Tooltip(
                                                    message:
                                                        "Источник: Voxel World",
                                                    child: fl.IconButton(
                                                      icon: Image.network(
                                                        "https://voxelworld.ru/favicon-32x32.png",
                                                        scale: 1.7,
                                                        loadingBuilder:
                                                            (BuildContext
                                                                    context,
                                                                Widget child,
                                                                ImageChunkEvent?
                                                                    loadingProgress) {
                                                          if (loadingProgress ==
                                                              null) {
                                                            return child;
                                                          } else {
                                                            return const SizedBox(
                                                                width: 15,
                                                                height: 15,
                                                                child: fl
                                                                    .ProgressRing());
                                                          }
                                                        },
                                                        errorBuilder: (context,
                                                                error,
                                                                stackTrace) =>
                                                            const SizedBox(
                                                                width: 15,
                                                                height: 15,
                                                                child: fl
                                                                    .ProgressRing()),
                                                      ),
                                                      onPressed: () async {
                                                        await launchUrl(Uri.parse(
                                                            "https://voxelworld.ru/"));
                                                      },
                                                    ))),
                                          ])
                                        ],
                                      ),
                                    ),
                                  ),
                                  Padding(
                                      padding:
                                          const EdgeInsets.symmetric(horizontal: 5),
                                      child: SizedBox(
                                          height:
                                              size.height - heigperc * 6 - 71,
                                          width: uii.Size.infinite.width,
                                          child: SingleChildScrollView(
                                              child: Wrap(
                                                  alignment:
                                                      WrapAlignment.center,
                                                  spacing: 5,
                                                  runSpacing: 5,
                                                  children: end))))
                                ],
                              )),
                        ],
                      ),
                    ),
                  ),
                  Container(
                      alignment: Alignment.bottomCenter,
                      margin: const EdgeInsets.symmetric(vertical: 15),
                      child: SizedBox(
                          width: 100,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              fl.Card(
                                  backgroundColor: theme.resources
                                      .cardBackgroundFillColorSecondary
                                      .withOpacity(0.3),
                                  child: modpages()),
                            ],
                          ))),
                ]),
                title: const Text("Поиск контент-паков"),
                icon: Icon(TDTxNFIcons.nf_cod_cloud_download,
                    color: theme.accentColor, size: 26),
              ),

            fl.PaneItem(
                body: Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(
                      child: Container(
                          padding: const EdgeInsets.all(0),
                          child: !lautext
                              ? const Image(
                                  fit: BoxFit.cover,
                                  image: AssetImage('assets/menuimage.png'))
                              : Container(
                                  alignment: Alignment.center,
                                  child: Text(lautextt?.text ?? "",
                                      style: const TextStyle(
                                          fontSize: 175,
                                          fontWeight: FontWeight.bold)),
                                ))),
                  const Positioned.fill(
                      child: fl.Acrylic(
                    shadowColor: Colors.blueAccent,
                    luminosityAlpha: 0.9,
                    blurAmount: 10,
                  )),
                  Positioned.fill(
                      child: Padding(
                          padding: const EdgeInsets.all(0),
                          child: Container(
                              padding: const EdgeInsets.all(5),
                              child: SingleChildScrollView(
                                child: endinst.isNotEmpty || endworl.isNotEmpty
                                    ? fl.Column(children: [
                                        endinst.isNotEmpty
                                            ? fl.Card(
                                                padding: const EdgeInsets.all(5),
                                                child: Column(children: [
                                                  Container(
                                                      width: size.width,
                                                      alignment:
                                                          Alignment.topCenter,
                                                      child: const Text(
                                                        "Контент-паки",
                                                        style: TextStyle(
                                                            fontSize: 24,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold),
                                                      )),
                                                  SizedBox(
                                                      width: size.width,
                                                      child: Wrap(
                                                        alignment:
                                                            WrapAlignment.start,
                                                        spacing: 5,
                                                        runSpacing: 5,
                                                        children: endinst,
                                                      )),
                                                ]))
                                            : Container(),
                                        endinst.isNotEmpty
                                            ? const SizedBox(height: 5)
                                            : Container(),
                                        // ?
                                        endworl.isNotEmpty
                                            ? fl.Card(
                                                padding: const EdgeInsets.all(5),
                                                child: Column(children: [
                                                  Container(
                                                      width: size.width,
                                                      alignment:
                                                          Alignment.topCenter,
                                                      child: const Text(
                                                        "Миры",
                                                        style: TextStyle(
                                                            fontSize: 24,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold),
                                                      )),
                                                  SizedBox(
                                                      width: size.width,
                                                      child: Wrap(
                                                        alignment:
                                                            WrapAlignment.start,
                                                        spacing: 5,
                                                        runSpacing: 5,
                                                        children: endworl,
                                                      ))
                                                ]))
                                            : Container(),
                                      ])
                                    : Container(
                                        alignment: Alignment.center,
                                        child: const Text("Ничего не найдено",
                                            style: TextStyle(
                                                fontSize: 25,
                                                fontWeight: FontWeight.bold))),
                              ))))
                ]),
                title: const Text("Управление"),
                icon: Icon(TDTxNFIcons.nf_cod_archive,
                    color: theme.accentColor, size: 26)),
          ],
          selected: _selectedRail,
          onChanged: (index) {
            setState(() {
              _selectedRail = index;
            });
          },
        ));
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final fl.FluentThemeData theme = fl.FluentTheme.of(context);
    return SizedBox(
      width: 138,
      height: 50,
      child: WindowCaption(
        brightness: theme.brightness,
        backgroundColor: Colors.transparent,
      ),
    );
  }
}

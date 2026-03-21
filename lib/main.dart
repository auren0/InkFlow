import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:note_app/providers/note_provider.dart';
import 'package:note_app/screens/archive_screen.dart';
import 'package:note_app/screens/create_folder_screen.dart';
import 'package:note_app/screens/folder_screen.dart';
import 'package:note_app/screens/home_screen.dart';
import 'package:note_app/screens/settings_screen.dart';
import 'package:note_app/screens/trash_screen.dart';
import 'package:note_app/services/hive_service.dart';
import 'package:note_app/shared_preferences/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:window_size/window_size.dart' as window;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb || Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    const double width = 600;
    const double height = 700;

    window.setWindowTitle('InkFlow');
    window.setWindowMinSize(const Size(width, height));
    // window.setWindowMaxSize(const Size(width, height));
  }

  await HiveService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NoteProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const NoteApp(),
    ),
  );
}

class NoteApp extends StatelessWidget {
  const NoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: themeProvider.currentTheme,
      home: MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  int _currentScreenIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    SettingsScreen(),
    ArchiveScreen(),
    TrashScreen(),
  ];

  final List<String> _titles = const [
    'Главная',
    'Настройки',
    'Архив',
    'Корзина',
  ];

  void _onDrawerTap(int index) {
    setState(() {
      _currentScreenIndex = index;
    });
    // Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation = Tween<Offset>(begin: Offset(-0.3, 0), end: Offset(0, 0))
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeInOut),
        );
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    super.dispose();
    _slideController.dispose();
    _fadeController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foldersProvider = context.watch<NoteProvider>();
    final folders = foldersProvider.folders;

    return Scaffold(
      appBar: AppBar(
        // leading: Builder(
        //   builder: (context) {
        //     return IconButton(
        //       onPressed: () => Scaffold.of(context).openDrawer(),
        //       icon: Icon(FluentIcons.arrow_swap_24_regular),
        //     );
        //   },
        // ),
        title: Text(
          _titles[_currentScreenIndex],
          style: TextStyle(fontFamily: 'Oswald'),
        ),
        actions: _currentScreenIndex == 0
            ? [
                PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      onTap: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (_) => CreateFolderScreen(),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.folder),
                          const SizedBox(width: 10),
                          const Text(
                            'Создать папку',
                            style: TextStyle(fontFamily: 'Oswald'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ]
            : null,
      ),
      body: MediaQuery.of(context).size.width > 650
          ? Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Colors.white10)),
                  ),
                  child: SizedBox(
                    width: 300,
                    child: Column(
                      children: [
                        _buildDrawerTile(
                          0,
                          FluentIcons.home_24_filled,
                          'Главная',
                        ),

                        const SizedBox(height: 5),

                        _buildDrawerTile(
                          1,
                          FluentIcons.settings_24_filled,
                          'Настройки',
                        ),

                        const SizedBox(height: 5),

                        _buildDrawerTile(
                          2,
                          FluentIcons.archive_24_filled,
                          'Архив',
                        ),

                        const SizedBox(height: 5),

                        _buildDrawerTile(
                          3,
                          FluentIcons.delete_24_filled,
                          'Корзина',
                        ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: IndexedStack(
                    index: _currentScreenIndex,
                    children: _screens,
                  ),
                ),
              ],
            )
          : _screens[_currentScreenIndex],
      // body: IndexedStack(index: _currentScreenIndex, children: _screens),
      drawer: MediaQuery.of(context).size.width > 500
          ? null
          : Drawer(
              child: ListView(
                children: [
                  DrawerHeader(
                    decoration: BoxDecoration(color: Colors.yellow),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: const Text(
                        'Меню',
                        style: TextStyle(
                          fontFamily: 'Oswald',
                          color: Colors.black,
                          fontSize: 35,
                        ),
                      ),
                    ),
                  ),
                  SlideTransition(
                    position: _slideAnimation,
                    child: _buildDrawerTile(
                      0,
                      FluentIcons.home_24_filled,
                      'Главная',
                    ),
                  ),
                  const SizedBox(height: 10),
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildDrawerTile(
                        1,
                        FluentIcons.settings_24_filled,
                        'Настройки',
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: const Divider(),
                  ),
                  _buildDrawerTile(2, FluentIcons.archive_24_filled, 'Архив'),
                  const SizedBox(height: 10),
                  _buildDrawerTile(3, FluentIcons.delete_24_filled, 'Корзина'),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: const Divider(),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: folders.length,
                    itemBuilder: (context, index) {
                      final folder = folders[index];

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: ListTile(
                          onLongPress: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text(
                                  'Выберите вариант',
                                  style: TextStyle(fontFamily: 'Oswald'),
                                ),
                                actions: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16.0,
                                              horizontal: 25.0,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            side: BorderSide(
                                              color: Colors.green,
                                              width: 2,
                                            ),
                                          ),
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                          child: Text(
                                            "Отмена",
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontFamily: 'Oswald',
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16.0,
                                              horizontal: 25.0,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            side: BorderSide(
                                              color: Colors.blue,
                                              width: 2,
                                            ),
                                          ),
                                          onPressed: () {
                                            Navigator.pop(context);
                                            Navigator.push(
                                              context,
                                              CupertinoPageRoute(
                                                builder: (_) =>
                                                    CreateFolderScreen(
                                                      folder: folder,
                                                    ),
                                              ),
                                            );
                                          },
                                          child: const Text(
                                            'Переименовать',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontFamily: 'Oswald',
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16.0,
                                              horizontal: 25.0,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                          onPressed: () {
                                            Navigator.pop(context);
                                            foldersProvider.moveFolderToTrash(
                                              folder,
                                            );
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: const Text(
                                                  'Папка перемещена в корзину',
                                                ),
                                              ),
                                            );
                                          },
                                          child: Text(
                                            "Удалить",
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontFamily: 'Oswald',
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                          leading: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Color(folder.colorValue),
                              border: Border.all(color: Colors.white, width: 2),
                              shape: BoxShape.circle,
                            ),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: Text(
                            folder.title,
                            style: TextStyle(
                              fontFamily: 'Oswald',
                              fontFamilyFallback: ['Apple'],
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (_) => FolderScreen(folder: folder),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDrawerTile(int index, IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ListTile(
        selectedTileColor: Colors.yellow,
        selectedColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(icon),
        title: Text(title, style: TextStyle(fontFamily: 'Oswald')),
        selected: _currentScreenIndex == index,
        onTap: () => _onDrawerTap(index),
      ),
    );
  }
}

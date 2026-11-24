import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:inkflow/l10n/app_localizations.dart';
import 'package:inkflow/providers/note_provider.dart';
import 'package:inkflow/providers/update_provider.dart';
import 'package:inkflow/screens/archive_screen.dart';
import 'package:inkflow/screens/create_folder_screen.dart';
import 'package:inkflow/screens/folder_screen.dart';
import 'package:inkflow/screens/home_screen.dart';
import 'package:inkflow/screens/settings_screen.dart';
import 'package:inkflow/screens/trash_screen.dart';
import 'package:inkflow/services/hive_service.dart';
import 'package:inkflow/shared_preferences/note_settings_provider.dart';
import 'package:inkflow/shared_preferences/theme_provider.dart';
import 'package:inkflow/theme/app_color_scheme.dart';
import 'package:inkflow/theme/app_text_theme.dart';
import 'package:inkflow/widgets/update_dialog.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:window_size/window_size.dart' as window;
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    BrowserContextMenu.disableContextMenu();
  }

  final isDesktop =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS);

  if (isDesktop) {
    const double width = 500;
    const double height = 700;

    window.setWindowTitle('InkFlow');
    window.setWindowMinSize(const Size(width, height));
    // window.setWindowMaxSize(const Size(width, height));
  }

  await HiveService.init();
  await initializeDateFormatting();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NoteProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NoteSettingsProvider()),
        ChangeNotifierProvider(create: (_) => UpdateProvider()),
      ],
      child: const InkFlowApp(),
    ),
  );
}

class InkFlowApp extends StatelessWidget {
  const InkFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    final lightTheme = _buildTheme(themeProvider, brightness: Brightness.light);
    final darkTheme = _buildTheme(
      themeProvider,
      brightness: Brightness.dark,
      oled: themeProvider.isOled,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: themeProvider.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeProvider.currentTheme,
      home: const MainNavigation(),
    );
  }

  ThemeData _buildTheme(
    ThemeProvider themeProvider, {
    required Brightness brightness,
    bool oled = false,
  }) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark()
        : ThemeData.light();

    final textTheme = applyAppFont(
      base.textTheme,
      family: themeProvider.fontFamily,
      bold: themeProvider.boldText,
    );
    final primaryTextTheme = applyAppFont(
      base.primaryTextTheme,
      family: themeProvider.fontFamily,
      bold: themeProvider.boldText,
    );

    var colorScheme = buildAppColorScheme(
      seedColor: themeProvider.primaryColor,
      brightness: brightness,
    );

    if (oled) {
      colorScheme = colorScheme.copyWith(
        surface: Colors.black,
        surfaceDim: Colors.black,
        surfaceBright: const Color(0xFF101010),
        surfaceContainerLowest: Colors.black,
        surfaceContainerLow: const Color(0xFF080808),
        surfaceContainer: const Color(0xFF0D0D0D),
        surfaceContainerHigh: const Color(0xFF141414),
        surfaceContainerHighest: const Color(0xFF1A1A1A),
        onSurface: Colors.white,
        onSurfaceVariant: const Color(0xFFB8B8B8),
        outlineVariant: const Color(0xFF2A2A2A),
      );
    }

    final theme = base.copyWith(
      colorScheme: colorScheme,
      textTheme: textTheme,
      primaryTextTheme: primaryTextTheme,
      listTileTheme: ListTileThemeData(selectedColor: colorScheme.primary),
      switchTheme: buildAppSwitchTheme(colorScheme),
    );

    if (!oled) return theme;

    return theme.copyWith(
      scaffoldBackgroundColor: Colors.black,
      canvasColor: Colors.black,
      cardColor: const Color(0xFF0D0D0D),
      dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF0D0D0D)),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
      ),
      bottomAppBarTheme: const BottomAppBarThemeData(color: Colors.black),
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

  List<String> _screenTitles(BuildContext context) => [
    context.l10n.t('nav.home'),
    context.l10n.t('nav.settings'),
    context.l10n.t('nav.archive'),
    context.l10n.t('nav.trash'),
  ];

  void _onDrawerTap(int index) {
    setState(() {
      _currentScreenIndex = index;
    });
    if (MediaQuery.of(context).size.width < 650) {
      Navigator.pop(context);
    }
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdatesOnStartup();
    });
  }

  Future<void> _checkForUpdatesOnStartup() async {
    final updateProvider = context.read<UpdateProvider>();
    await updateProvider.initialize();

    if (!mounted || !updateProvider.shouldShowStartupDialog) return;

    await showUpdateAvailableDialog(
      context: context,
      updateProvider: updateProvider,
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foldersProvider = context.watch<NoteProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final folders = foldersProvider.folders;
    final l10n = context.l10n;
    final titles = _screenTitles(context);

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
        title: Text(titles[_currentScreenIndex], style: TextStyle()),
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
                          const Icon(FluentIcons.folder_24_regular),
                          const SizedBox(width: 10),
                          Text(l10n.t('folder.create'), style: TextStyle()),
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
                          l10n.t('nav.home'),
                        ),

                        const SizedBox(height: 5),

                        _buildDrawerTile(
                          1,
                          FluentIcons.settings_24_filled,
                          l10n.t('nav.settings'),
                        ),

                        const SizedBox(height: 5),

                        _buildDrawerTile(
                          2,
                          FluentIcons.archive_24_filled,
                          l10n.t('nav.archive'),
                        ),

                        const SizedBox(height: 5),

                        _buildDrawerTile(
                          3,
                          FluentIcons.delete_24_filled,
                          l10n.t('nav.trash'),
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
      drawer: MediaQuery.of(context).size.width < 650
          ? Drawer(
              child: ListView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewPaddingOf(context).bottom,
                ),
                children: [
                  DrawerHeader(
                    decoration: BoxDecoration(
                      color: themeProvider.primaryColor,
                    ),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        l10n.t('nav.menu'),
                        style: TextStyle(
                          color: themeProvider.onPrimaryColor,
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
                      l10n.t('nav.home'),
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
                        l10n.t('nav.settings'),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: const Divider(),
                  ),
                  _buildDrawerTile(
                    2,
                    FluentIcons.archive_24_filled,
                    l10n.t('nav.archive'),
                  ),
                  const SizedBox(height: 10),
                  _buildDrawerTile(
                    3,
                    FluentIcons.delete_24_filled,
                    l10n.t('nav.trash'),
                  ),
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
                                title: Text(
                                  l10n.t('folder.options'),
                                  style: TextStyle(),
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
                                            l10n.t('common.cancel'),
                                            style: TextStyle(
                                              color: Colors.green,
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
                                          child: Text(
                                            l10n.t('folder.rename'),
                                            style: TextStyle(
                                              fontSize: 18,
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
                                                content: Text(
                                                  l10n.t('folder.movedToTrash'),
                                                ),
                                              ),
                                            );
                                          },
                                          child: Text(
                                            l10n.t('common.delete'),
                                            style: TextStyle(
                                              fontSize: 18,
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
                            style: TextStyle(fontFamilyFallback: ['Apple']),
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
            )
          : null,
    );
  }

  Widget _buildDrawerTile(int index, IconData icon, String title) {
    final themeProvider = context.watch<ThemeProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ListTile(
        selectedTileColor: themeProvider.primaryColor,
        selectedColor: themeProvider.onPrimaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(icon),
        title: Text(title, style: TextStyle()),
        selected: _currentScreenIndex == index,
        onTap: () => _onDrawerTap(index),
      ),
    );
  }
}

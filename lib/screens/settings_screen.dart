import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:note_app/shared_preferences/theme_provider.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Тема',
            style: TextStyle(fontFamily: 'Oswald', fontSize: 25),
          ),
          const SizedBox(height: 10),
          ListTile(
            title: const Text(
              'Тёмная тема',
              style: TextStyle(fontFamily: 'Oswald'),
            ),
            subtitle: const Text(
              'Включить темную тему',
              style: TextStyle(fontFamily: 'Oswald'),
            ),
            trailing: Switch(
              activeThumbColor: Colors.yellow,
              value: themeProvider.isDark,
              onChanged: (bool value) {
                themeProvider.toggleTheme();
              },
            ),
          ),
          const SizedBox(height: 10),
          const Divider(),
          const SizedBox(height: 10),
          const Text(
            'Интерфейс',
            style: TextStyle(fontFamily: 'Oswald', fontSize: 25),
          ),
          const SizedBox(height: 10),
          ListTile(
            title: const Text(
              'Цвет интерфейса',
              style: TextStyle(fontFamily: 'Oswald'),
            ),
            subtitle: const Text(
              'Выберите цвет интерфейса',
              style: TextStyle(fontFamily: 'Oswald'),
            ),
            trailing: IconButton(
              onPressed: () {},
              icon: const Icon(FluentIcons.color_fill_24_regular),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:note_app/shared_preferences/theme_provider.dart';
import 'package:note_app/widgets/update_tile.dart';
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
          _themeTile(
            context: context,
            themeProvider: themeProvider,
            theme: AppTheme.light,
            title: 'Светлая',
            subtitle: 'Обычная светлая тема',
            icon: Icons.light_mode_outlined,
          ),
          const SizedBox(height: 5),
          _themeTile(
            context: context,
            themeProvider: themeProvider,
            theme: AppTheme.dark,
            title: 'Тёмная',
            subtitle: 'Тёмный интерфейс',
            icon: Icons.dark_mode_outlined,
          ),
          const SizedBox(height: 5),
          _themeTile(
            context: context,
            themeProvider: themeProvider,
            theme: AppTheme.oled,
            title: 'OLED',
            subtitle: 'Полностью чёрный фон',
            icon: Icons.contrast,
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
              'Основной цвет приложения',
              style: TextStyle(fontFamily: 'Oswald'),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: themeProvider.primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Выбрать цвет',
                  onPressed: () =>
                      _showPrimaryColorDialog(context, themeProvider),
                  icon: const Icon(FluentIcons.color_fill_24_regular),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(),
          const SizedBox(height: 10),
          const UpdateTile(),
        ],
      ),
    );
  }

  Widget _themeTile({
    required BuildContext context,
    required ThemeProvider themeProvider,
    required AppTheme theme,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = themeProvider.appTheme == theme;

    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      selected: isSelected,
      selectedTileColor: themeProvider.primaryColor.withValues(alpha: 0.18),
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontFamily: 'Oswald')),
      subtitle: Text(subtitle, style: const TextStyle(fontFamily: 'Oswald')),
      trailing: isSelected
          ? Icon(Icons.check, color: themeProvider.primaryColor)
          : null,
      onTap: () => themeProvider.setAppTheme(theme),
    );
  }

  Future<void> _showPrimaryColorDialog(
    BuildContext context,
    ThemeProvider themeProvider,
  ) async {
    Color tempColor = themeProvider.primaryColor;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text(
            'Основной цвет приложения',
            style: TextStyle(fontFamily: 'Oswald'),
          ),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerAreaBorderRadius: BorderRadius.circular(10),
              pickerColor: tempColor,
              onColorChanged: (Color color) {
                tempColor = color;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await themeProvider.resetPrimaryColor();
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text(
                'Сбросить',
                style: TextStyle(fontFamily: 'Oswald'),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 14.0,
                  horizontal: 20.0,
                ),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                foregroundColor: theme.colorScheme.onSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Отмена',
                style: TextStyle(fontFamily: 'Oswald', fontSize: 18),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 14.0,
                  horizontal: 20.0,
                ),
                backgroundColor: themeProvider.primaryColor,
                foregroundColor: themeProvider.onPrimaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                await themeProvider.setPrimaryColor(tempColor);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text(
                'Выбрать',
                style: TextStyle(fontFamily: 'Oswald', fontSize: 18),
              ),
            ),
          ],
        );
      },
    );
  }
}

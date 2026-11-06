import 'package:audioplayers/audioplayers.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:note_app/shared_preferences/theme_provider.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String filePath;
  final String audioTitle;
  final ValueChanged<String> onTitleChanged;
  final VoidCallback onDelete;
  final ThemeProvider themeProvider;
  const AudioPlayerWidget({
    super.key,
    required this.filePath,
    required this.audioTitle,
    required this.onTitleChanged,
    required this.onDelete,
    required this.themeProvider,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayer _player = AudioPlayer();
  bool isPlaying = false;
  final TextEditingController _editController = TextEditingController();

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  String? audioTitle;

  // bool _isSeeking = false;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
    audioTitle = widget.audioTitle;
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _setupAudioPlayer() {
    _player.onDurationChanged.listen((d) {
      if (mounted) {
        setState(() => _duration = d);
      }
    });

    _player.onPositionChanged.listen((p) {
      if (mounted) {
        setState(() => _position = p);
      }
    });

    _player.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() => isPlaying = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = widget.themeProvider.primaryColor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: isPlaying ? 'Пауза' : 'Воспроизвести',
                  onPressed: () async {
                    if (isPlaying) {
                      await _player.pause();
                    } else {
                      await _player.play(DeviceFileSource(widget.filePath));
                    }
                    if (mounted) {
                      setState(() {
                        isPlaying = !isPlaying;
                      });
                    }
                  },
                  icon: Icon(
                    isPlaying
                        ? FluentIcons.pause_24_regular
                        : FluentIcons.play_24_regular,
                  ),
                ),
                Expanded(
                  child: Text(
                    audioTitle ?? 'Аудио заметка',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Oswald',
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Переименовать',
                  onPressed: () => _showRenameDialog(context),
                  icon: const Icon(FluentIcons.edit_24_regular),
                ),
                IconButton(
                  tooltip: 'Удалить',
                  onPressed: widget.onDelete,
                  icon: const Icon(FluentIcons.delete_off_24_regular),
                ),
              ],
            ),
            Slider(
              activeColor: primaryColor,
              thumbColor: primaryColor,
              value: _position.inSeconds
                  .clamp(0, _duration.inSeconds)
                  .toDouble(),
              max: _duration.inSeconds.toDouble() > 0
                  ? _duration.inSeconds.toDouble()
                  : 1,
              onChanged: (value) async {
                final pos = Duration(seconds: value.toInt());
                await _player.seek(pos);
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_position),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFamily: 'Oswald',
                  ),
                ),
                Text(
                  _formatDuration(_duration),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFamily: 'Oswald',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _showRenameDialog(BuildContext context) {
    _editController.text = audioTitle ?? 'Аудио заметка';
    final theme = Theme.of(context);
    final primaryColor = widget.themeProvider.primaryColor;
    final onPrimaryColor = widget.themeProvider.onPrimaryColor;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Переименовать аудио заметку',
          style: TextStyle(fontFamily: 'Oswald'),
        ),
        content: Theme(
          data: Theme.of(context).copyWith(
            textSelectionTheme: TextSelectionThemeData(
              selectionColor: primaryColor.withValues(alpha: 0.3),
              selectionHandleColor: primaryColor,
            ),
          ),
          child: TextField(
            style: const TextStyle(fontFamily: 'Oswald'),
            controller: _editController,
            cursorColor: primaryColor,
            decoration: InputDecoration(
              floatingLabelStyle: TextStyle(
                fontFamily: 'Oswald',
                color: widget.themeProvider.isDark
                    ? primaryColor
                    : Colors.black,
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
              focusColor: primaryColor,
              label: const Text(
                'Название',
                style: TextStyle(fontFamily: 'Oswald'),
              ),
              hint: const Text(
                'Введите название',
                style: TextStyle(fontFamily: 'Oswald'),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
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
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text(
              "Отмена",
              style: TextStyle(fontFamily: 'Oswald', fontSize: 18),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                vertical: 14.0,
                horizontal: 20.0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              backgroundColor: primaryColor,
              foregroundColor: onPrimaryColor,
            ),
            onPressed: () {
              final newTitle = _editController.text.isNotEmpty
                  ? _editController.text
                  : 'Аудио заметка';
              widget.onTitleChanged(newTitle);
              setState(() {
                audioTitle = newTitle;
              });
              Navigator.pop(dialogContext);
            },
            child: Text(
              "Переименовать",
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'Oswald',
                color: onPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

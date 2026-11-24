import 'package:audioplayers/audioplayers.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:inkflow/l10n/app_localizations.dart';
import 'package:inkflow/shared_preferences/theme_provider.dart';

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
    final accentColor = theme.colorScheme.primary;
    final l10n = context.l10n;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: isPlaying
                      ? l10n.t('audio.pause')
                      : l10n.t('audio.play'),
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
                    audioTitle ?? l10n.t('audio.title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.t('common.rename'),
                  onPressed: () => _showRenameDialog(context),
                  icon: const Icon(FluentIcons.edit_24_regular),
                ),
                IconButton(
                  tooltip: l10n.t('common.delete'),
                  onPressed: widget.onDelete,
                  icon: const Icon(FluentIcons.delete_off_24_regular),
                ),
              ],
            ),
            Slider(
              activeColor: accentColor,
              thumbColor: accentColor,
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
                  ),
                ),
                Text(
                  _formatDuration(_duration),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
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
    final l10n = context.l10n;
    _editController.text = audioTitle ?? l10n.t('audio.title');
    final theme = Theme.of(context);
    final primaryColor = widget.themeProvider.primaryColor;
    final accentColor = theme.colorScheme.primary;
    final onPrimaryColor = widget.themeProvider.onPrimaryColor;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(l10n.t('audio.renameTitle'), style: TextStyle()),
        content: Theme(
          data: Theme.of(context).copyWith(
            textSelectionTheme: TextSelectionThemeData(
              selectionColor: accentColor.withValues(alpha: 0.3),
              selectionHandleColor: accentColor,
            ),
          ),
          child: TextField(
            style: const TextStyle(),
            controller: _editController,
            cursorColor: accentColor,
            decoration: InputDecoration(
              floatingLabelStyle: TextStyle(color: accentColor),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: accentColor, width: 2),
              ),
              focusColor: accentColor,
              label: Text(l10n.t('audio.name'), style: TextStyle()),
              hint: Text(l10n.t('audio.nameHint'), style: TextStyle()),
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
            child: Text(
              l10n.t('common.cancel'),
              style: TextStyle(fontSize: 18),
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
                  : l10n.t('audio.title');
              widget.onTitleChanged(newTitle);
              setState(() {
                audioTitle = newTitle;
              });
              Navigator.pop(dialogContext);
            },
            child: Text(
              l10n.t('common.rename'),
              style: TextStyle(fontSize: 18, color: onPrimaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

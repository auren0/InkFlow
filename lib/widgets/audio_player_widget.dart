import 'package:audioplayers/audioplayers.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:note_app/shared_preferences/theme_provider.dart';
import 'package:provider/provider.dart';

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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () async {
                    if (isPlaying) {
                      await _player.pause();
                    } else {
                      await _player.play(DeviceFileSource(widget.filePath));
                    }
                    setState(() {
                      isPlaying = !isPlaying;
                    });
                  },
                  icon: Icon(
                    isPlaying
                        ? FluentIcons.pause_24_regular
                        : FluentIcons.play_24_regular,
                  ),
                ),
                Column(
                  children: [
                    Text(
                      audioTitle ?? 'Аудио заметка',
                      style: TextStyle(fontSize: 16, fontFamily: 'Oswald'),
                    ),
                    Slider(
                      activeColor: Colors.yellow,
                      thumbColor: Colors.yellow,
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
                    // Column(
                    //   children: [
                    //     Slider(
                    //       // value: _position.inSeconds
                    //       //     .clamp(0, _duration.inSeconds)
                    //       //     .toDouble(),
                    //       value: _position.inMilliseconds
                    //           .clamp(0, _duration.inMilliseconds)
                    //           .toDouble(),
                    //       max: _duration.inSeconds.toDouble() > 0
                    //           ? _duration.inSeconds.toDouble()
                    //           : 1,
                    //       // onChanged: (value) async {
                    //       //   final pos = Duration(seconds: value.toInt());
                    //       //   await _player.seek(pos);
                    //       // },
                    //       onChanged: (value) {
                    //         setState(() {
                    //           _position = Duration(milliseconds: value.toInt());
                    //         });
                    //       },
                    //       onChangeStart: (_) {
                    //         setState(() {
                    //           _isSeeking = true;
                    //         });
                    //       },
                    //       onChangeEnd: (value) async {
                    //         final newPosition = Duration(
                    //           milliseconds: value.toInt(),
                    //         );

                    //         await _player.seek(newPosition);
                    //         setState(() {
                    //           _isSeeking = false;
                    //           _position = newPosition;
                    //         });
                    //       },
                    //     ),
                    //     // const SizedBox(height: 5),
                    //     Row(
                    //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //       children: [
                    //         Text(
                    //           _formatDuration(_position),
                    //           style: TextStyle(
                    //             fontSize: 12,
                    //             color: Colors.grey[600],
                    //             fontFamily: 'Oswald',
                    //           ),
                    //         ),
                    //         Text(
                    //           _formatDuration(_duration),
                    //           style: TextStyle(
                    //             fontSize: 12,
                    //             color: Colors.grey[600],
                    //             fontFamily: 'Oswald',
                    //           ),
                    //         ),
                    //       ],
                    //     ),
                    //   ],
                    // ),
                  ],
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _showRenameDialog(context),
                  icon: Icon(FluentIcons.edit_24_regular),
                ),
                IconButton(
                  onPressed: widget.onDelete,
                  icon: Icon(FluentIcons.delete_off_24_regular),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    _editController.text = audioTitle ?? 'Аудио заметка';
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Переименовать аудио заметку',
          style: TextStyle(fontFamily: 'Oswald'),
        ),
        content: Theme(
          data: Theme.of(context).copyWith(
            textSelectionTheme: TextSelectionThemeData(
              selectionColor: Colors.yellow.withValues(alpha: 0.3),
              selectionHandleColor: Colors.yellow,
            ),
          ),
          child: TextField(
            style: TextStyle(fontFamily: 'Oswald'),
            controller: _editController,
            cursorColor: Colors.yellow,
            decoration: InputDecoration(
              floatingLabelStyle: TextStyle(
                fontFamily: 'Oswald',
                color: themeProvider.isDark ? Colors.yellow : Colors.black,
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.yellow, width: 2),
                // borderRadius: BorderRadius.circular(10),
              ),
              focusColor: Colors.yellow,
              label: const Text(
                'Название',
                style: TextStyle(fontFamily: 'Oswald'),
              ),
              hint: const Text(
                'Введите название',
                style: TextStyle(fontFamily: 'Oswald'),
              ),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                vertical: 16.0,
                horizontal: 25.0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.yellow, width: 2),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              "Отмена",
              style: TextStyle(
                color: widget.themeProvider.isDark
                    ? Colors.yellow
                    : Colors.black,
                fontFamily: 'Oswald',
                fontSize: 18,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                vertical: 16.0,
                horizontal: 25.0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.yellow, width: 2),
              ),
              backgroundColor: Colors.yellow,
            ),
            onPressed: () {
              final newTitle = _editController.text.isNotEmpty
                  ? _editController.text
                  : 'Аудио заметка';
              widget.onTitleChanged(newTitle);
              setState(() {
                audioTitle = newTitle;
              });
              Navigator.pop(context);
            },
            child: Text(
              "Переименовать",
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'Oswald',
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

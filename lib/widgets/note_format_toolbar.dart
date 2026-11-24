import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:inkflow/l10n/app_localizations.dart';

/// Compact formatting toolbar for the note editor.
///
/// The toolbar watches the [QuillController] so the active state of every
/// button follows the current selection/cursor position. Tapping a button does
/// not move the editor selection: the editor's [FocusNode] is re-focused after
/// every action.
class NoteFormatToolbar extends StatelessWidget {
  const NoteFormatToolbar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.primaryColor,
  });

  final QuillController controller;
  final FocusNode focusNode;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final style = controller.getSelectionStyle();
        final attributes = style.attributes;
        final listType = attributes[Attribute.list.key]?.value as String?;

        bool inlineActive(Attribute attribute) {
          final current = attributes[attribute.key];
          return current != null && current.value == true;
        }

        return Material(
          color: theme.colorScheme.surfaceContainerHighest,
          child: SafeArea(
            top: false,
            bottom: false,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: Row(
                children: [
                  _ToolbarButton(
                    icon: FluentIcons.text_bold_24_regular,
                    tooltip: l10n.t('editor.bold'),
                    active: inlineActive(Attribute.bold),
                    onPressed: () => _toggleInline(Attribute.bold),
                    primaryColor: primaryColor,
                  ),
                  _ToolbarButton(
                    icon: FluentIcons.text_italic_24_regular,
                    tooltip: l10n.t('editor.italic'),
                    active: inlineActive(Attribute.italic),
                    onPressed: () => _toggleInline(Attribute.italic),
                    primaryColor: primaryColor,
                  ),
                  _ToolbarButton(
                    icon: FluentIcons.text_underline_24_regular,
                    tooltip: l10n.t('editor.underline'),
                    active: inlineActive(Attribute.underline),
                    onPressed: () => _toggleInline(Attribute.underline),
                    primaryColor: primaryColor,
                  ),
                  _ToolbarButton(
                    icon: FluentIcons.text_strikethrough_24_regular,
                    tooltip: l10n.t('editor.strikethrough'),
                    active: inlineActive(Attribute.strikeThrough),
                    onPressed: () => _toggleInline(Attribute.strikeThrough),
                    primaryColor: primaryColor,
                  ),
                  const _ToolbarDivider(),
                  _ToolbarButton(
                    icon: FluentIcons.text_bullet_list_ltr_24_regular,
                    tooltip: l10n.t('editor.bulletList'),
                    active: listType == Attribute.ul.value,
                    onPressed: () => _setList(Attribute.ul),
                    primaryColor: primaryColor,
                  ),
                  _ToolbarButton(
                    icon: FluentIcons.text_number_list_ltr_24_regular,
                    tooltip: l10n.t('editor.numberedList'),
                    active: listType == Attribute.ol.value,
                    onPressed: () => _setList(Attribute.ol),
                    primaryColor: primaryColor,
                  ),
                  _ToolbarButton(
                    icon: FluentIcons.task_list_ltr_24_regular,
                    tooltip: l10n.t('editor.checklist'),
                    active:
                        listType == Attribute.checked.value ||
                        listType == Attribute.unchecked.value,
                    onPressed: () => _setList(Attribute.unchecked),
                    primaryColor: primaryColor,
                  ),
                  const _ToolbarDivider(),
                  _ToolbarButton(
                    icon: FluentIcons.arrow_undo_24_regular,
                    tooltip: l10n.t('editor.undo'),
                    enabled: controller.hasUndo,
                    onPressed: controller.undo,
                    primaryColor: primaryColor,
                  ),
                  _ToolbarButton(
                    icon: FluentIcons.arrow_redo_24_regular,
                    tooltip: l10n.t('editor.redo'),
                    enabled: controller.hasRedo,
                    onPressed: controller.redo,
                    primaryColor: primaryColor,
                  ),
                  const _ToolbarDivider(),
                  _ToolbarButton(
                    icon: FluentIcons.text_clear_formatting_24_regular,
                    tooltip: l10n.t('editor.clear'),
                    onPressed: _clearFormatting,
                    primaryColor: primaryColor,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _toggleInline(Attribute attribute) {
    final current = controller.getSelectionStyle().attributes[attribute.key];
    final isActive = current != null && current.value == true;
    controller.formatSelection(
      isActive ? Attribute.clone(attribute, null) : attribute,
    );
    _restoreFocus();
  }

  void _setList(Attribute listAttribute) {
    final current = controller
        .getSelectionStyle()
        .attributes[Attribute.list.key];
    final isSame = current?.value == listAttribute.value;
    controller.formatSelection(
      isSame ? Attribute.clone(Attribute.list, null) : listAttribute,
    );
    _restoreFocus();
  }

  void _clearFormatting() {
    final List<Attribute> attributes = [
      Attribute.bold,
      Attribute.italic,
      Attribute.underline,
      Attribute.strikeThrough,
      Attribute.header,
      Attribute.list,
    ];

    for (final attribute in attributes) {
      controller.formatSelection(Attribute.clone(attribute, null));
    }
    _restoreFocus();
  }

  void _restoreFocus() {
    if (!focusNode.hasFocus) {
      focusNode.requestFocus();
    }
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.primaryColor,
    this.active = false,
    this.enabled = true,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color primaryColor;
  final bool active;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foregroundColor = !enabled
        ? theme.colorScheme.onSurface.withValues(alpha: 0.35)
        : active
        ? primaryColor
        : theme.colorScheme.onSurface;

    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Material(
          color: active
              ? primaryColor.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            canRequestFocus: false,
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              width: 38,
              height: 38,
              child: Icon(icon, size: 20, color: foregroundColor),
            ),
          ),
        ),
      ),
    );
  }
}

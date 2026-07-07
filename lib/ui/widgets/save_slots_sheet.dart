import 'package:flutter/material.dart';
import '../../models/rom.dart';
import '../../models/save_slot.dart';
import '../../services/emulator_service.dart';
import '../l10n_ext.dart';

enum SlotAction { save, load }

class SlotChoice {
  const SlotChoice(this.index, this.action);
  final int index;
  final SlotAction action;
}

Future<SlotChoice?> showSaveSlotsSheet(BuildContext context, Rom rom) {
  return showModalBottomSheet<SlotChoice>(
    context: context,
    showDragHandle: true,
    builder: (context) => _SaveSlotsSheet(rom: rom),
  );
}

class _SaveSlotsSheet extends StatefulWidget {
  const _SaveSlotsSheet({required this.rom});
  final Rom rom;

  @override
  State<_SaveSlotsSheet> createState() => _SaveSlotsSheetState();
}

class _SaveSlotsSheetState extends State<_SaveSlotsSheet> {
  List<SaveSlot> _slots = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final slots =
        await EmulatorService.instance.listSaveSlots(widget.rom.path);
    if (mounted) {
      setState(() {
        _slots = slots;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.saveSlots,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ...List.generate(10, (i) => _slotTile(context, i)),
          ],
        ),
      ),
    );
  }

  Widget _slotTile(BuildContext context, int index) {
    final l10n = context.l10n;
    final match = _slots.where((s) => s.index == index && !s.isAuto);
    final slot = match.isEmpty ? null : match.first;
    final filled = slot != null && !slot.isEmpty;
    return ListTile(
      leading: CircleAvatar(child: Text('$index')),
      title: Text(l10n.slotNumber(index)),
      subtitle: Text(filled
          ? (slot.modified?.toString() ?? '')
          : l10n.emptySlot),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: l10n.saveState,
            onPressed: () =>
                Navigator.of(context).pop(SlotChoice(index, SlotAction.save)),
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: l10n.loadState,
            onPressed: filled
                ? () => Navigator.of(context)
                    .pop(SlotChoice(index, SlotAction.load))
                : null,
          ),
        ],
      ),
    );
  }
}

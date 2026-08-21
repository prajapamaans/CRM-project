import 'package:flutter/material.dart';

class UndoRedoHistory {
  final List<TextEditingValue> _undoStack = [];
  final List<TextEditingValue> _redoStack = [];
  bool _isProcessingHistory = false;
  VoidCallback? _onStateChanged;

  void attach(TextEditingController controller, {VoidCallback? onStateChanged}) {
    _onStateChanged = onStateChanged;
    _undoStack.clear();
    _redoStack.clear();
    _undoStack.add(controller.value);

    controller.addListener(() {
      if (_isProcessingHistory) return;
      final current = controller.value;
      if (_undoStack.isEmpty || _undoStack.last.text != current.text) {
        _undoStack.add(current);
        _redoStack.clear();
        _onStateChanged?.call();
      }
    });
  }

  bool get canUndo => _undoStack.length > 1;
  bool get canRedo => _redoStack.isNotEmpty;

  void undo(TextEditingController controller) {
    if (!canUndo) return;
    _isProcessingHistory = true;
    final current = _undoStack.removeLast();
    _redoStack.add(current);
    final previous = _undoStack.last;
    controller.value = previous;
    _isProcessingHistory = false;
    _onStateChanged?.call();
  }

  void redo(TextEditingController controller) {
    if (!canRedo) return;
    _isProcessingHistory = true;
    final next = _redoStack.removeLast();
    _undoStack.add(next);
    controller.value = next;
    _isProcessingHistory = false;
    _onStateChanged?.call();
  }
}

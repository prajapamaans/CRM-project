import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Brings the widget carrying [itemKey] into view inside [controller]'s list.
///
/// `ListView.builder` only builds what is near the viewport, so an item further
/// down the list has no `BuildContext` to scroll to yet. This pages through the
/// list — a viewport at a time, using the list's own extent rather than any
/// assumed row height — until the item is built, then hands off to
/// [Scrollable.ensureVisible] for the exact final position.
///
/// Returns true once the item is visible. If the item never materialises (it is
/// not in this list), the list is returned to where it started and false is
/// returned, so a missing activity simply leaves the screen as it was.
Future<bool> ensureListItemVisible({
  required ScrollController controller,
  required GlobalKey itemKey,
  double alignment = 0.15,
  Duration duration = const Duration(milliseconds: 320),
  Curve curve = Curves.easeInOut,
  int maxHops = 60,
}) async {
  await WidgetsBinding.instance.endOfFrame;
  if (!controller.hasClients) return false;

  final startOffset = controller.position.pixels;

  // Already built (visible or just outside the viewport): align on it directly.
  final builtContext = itemKey.currentContext;
  if (builtContext != null && builtContext.mounted) {
    await Scrollable.ensureVisible(
      builtContext,
      alignment: alignment,
      duration: duration,
      curve: curve,
    );
    return true;
  }

  // Otherwise sweep from the top so items above the current offset are found too.
  controller.jumpTo(controller.position.minScrollExtent);
  await WidgetsBinding.instance.endOfFrame;

  for (var hop = 0; hop < maxHops; hop++) {
    if (!controller.hasClients) return false;

    final itemContext = itemKey.currentContext;
    if (itemContext != null && itemContext.mounted) {
      await Scrollable.ensureVisible(
        itemContext,
        alignment: alignment,
        duration: duration,
        curve: curve,
      );
      return true;
    }

    final position = controller.position;
    // maxScrollExtent grows as more rows are built, so this keeps making
    // progress on lists whose rows are not a uniform height.
    final next = math.min(
      position.pixels + position.viewportDimension,
      position.maxScrollExtent,
    );
    if (next <= position.pixels) break; // Reached the end of the list.

    controller.jumpTo(next);
    await WidgetsBinding.instance.endOfFrame;
  }

  if (controller.hasClients) {
    controller.jumpTo(
      startOffset.clamp(
        controller.position.minScrollExtent,
        controller.position.maxScrollExtent,
      ),
    );
  }
  return false;
}

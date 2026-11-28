import 'package:flutter/material.dart';

/// How a photo sits in its frame: filling it (cropped around a focal point,
/// -1…1 on each axis) or shown whole over a blurred copy of itself, and how
/// far it's enlarged around that point (1…2). The phone preview shows the
/// result.
class FocalPointField extends StatelessWidget {
  final double x;
  final double y;
  final double zoom;
  final bool whole;
  final void Function(double x, double y, double zoom, bool whole) onChanged;

  const FocalPointField({
    super.key,
    required this.x,
    required this.y,
    required this.zoom,
    required this.whole,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget slider(
      String label,
      String start,
      String end,
      double value,
      ValueChanged<double> set, {
      double min = -1,
      double max = 1,
      int divisions = 40,
      String Function(double)? format,
    }) => Row(
      children: [
        SizedBox(width: 72, child: Text(label)),
        Text(start, style: Theme.of(context).textTheme.bodySmall),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: format?.call(value) ?? value.toStringAsFixed(2),
            onChanged: set,
          ),
        ),
        Text(end, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('裁切與縮放', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                whole
                    ? '整張照片放進框裡，空白處用模糊的同一張照片填滿；縮放可以再放大'
                    : '照片框大小由版型決定；以焦點為中心裁切，縮放可以裁得更近',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (x != 0 || y != 0 || zoom != 1 || whole)
              TextButton(
                onPressed: () => onChanged(0, 0, 1, false),
                child: const Text('重設'),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const SizedBox(width: 72, child: Text('顯示方式')),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('填滿畫面')),
                  ButtonSegment(value: true, label: Text('完整顯示')),
                ],
                selected: {whole},
                onSelectionChanged: (s) => onChanged(x, y, zoom, s.single),
              ),
            ],
          ),
        ),
        slider('水平', '左', '右', x, (v) => onChanged(v, y, zoom, whole)),
        slider('垂直', '上', '下', y, (v) => onChanged(x, v, zoom, whole)),
        slider(
          '縮放',
          '1×',
          '2×',
          zoom,
          (v) => onChanged(x, y, v, whole),
          min: 1,
          max: 2,
          divisions: 20,
          format: (v) => '${v.toStringAsFixed(1)}×',
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

Future<int?> showColorPickerSheet(
  BuildContext context, {
  required Color initialColor,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _ColorPickerSheet(initialColor: initialColor),
  );
}

class _ColorPickerSheet extends StatefulWidget {
  const _ColorPickerSheet({required this.initialColor});

  final Color initialColor;

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late HSVColor _color;

  @override
  void initState() {
    super.initState();
    _color = HSVColor.fromColor(widget.initialColor);
  }

  @override
  Widget build(BuildContext context) {
    final selectedColor = _color.toColor();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '自定义颜色',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selectedColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ColorSlider(
            label: '色相',
            value: _color.hue,
            min: 0,
            max: 360,
            activeColor: HSVColor.fromAHSV(1, _color.hue, 1, 1).toColor(),
            onChanged: (value) => setState(() {
              _color = _color.withHue(value);
            }),
          ),
          _ColorSlider(
            label: '饱和度',
            value: _color.saturation,
            min: 0,
            max: 1,
            activeColor: selectedColor,
            onChanged: (value) => setState(() {
              _color = _color.withSaturation(value);
            }),
          ),
          _ColorSlider(
            label: '亮度',
            value: _color.value,
            min: 0,
            max: 1,
            activeColor: selectedColor,
            onChanged: (value) => setState(() {
              _color = _color.withValue(value);
            }),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(selectedColor.toARGB32()),
            child: const Text('使用此颜色'),
          ),
        ],
      ),
    );
  }
}

class _ColorSlider extends StatelessWidget {
  const _ColorSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.activeColor,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final Color activeColor;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: activeColor,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

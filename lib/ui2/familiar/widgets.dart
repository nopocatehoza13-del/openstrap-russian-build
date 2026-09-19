import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../grammar.dart';
import '../theme.dart';

class FamiliarPanel extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const FamiliarPanel({super.key, required this.child, this.onTap});
  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final panel = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(S.x4),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: R.rMd,
        border: Border.all(color: p.line),
      ),
      child: child,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: S.x3),
      child: onTap == null ? panel : Pressable(onTap: onTap, child: panel),
    );
  }
}

class FamiliarHeading extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  const FamiliarHeading(this.text, {super.key, this.onTap});
  @override
  Widget build(BuildContext c) => Row(
    children: [
      Expanded(
        child: Text(text, style: F.over.copyWith(color: P.of(c).ink2)),
      ),
      if (onTap != null)
        Pressable(
          onTap: onTap,
          semanticLabel: 'Открыть: $text',
          child: Icon(Icons.chevron_right, size: 20, color: P.of(c).ink2),
        ),
    ],
  );
}

class FamiliarRing extends StatelessWidget {
  final String label, value, subtitle;
  final double? fraction;
  final Color color;
  final VoidCallback onTap;
  const FamiliarRing({
    super.key,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.fraction,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext c) => Pressable(
    onTap: onTap,
    semanticLabel: '$label: $value, $subtitle',
    child: Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: (fraction ?? 0).clamp(0.0, 1.0)),
            duration: motion(c, Motion.slow),
            builder: (c, v, child) => CustomPaint(
              painter: _RingPainter(v, color, P.of(c).track),
              child: child,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(S.x3),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value, style: F.n24.copyWith(color: P.of(c).ink)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: S.x2),
        Text(
          label,
          maxLines: 1,
          style: F.over.copyWith(color: P.of(c).on(color)),
        ),
        Text(
          subtitle,
          style: F.over.copyWith(color: P.of(c).ink3),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color, track;
  _RingPainter(this.value, this.color, this.track);
  @override
  void paint(Canvas c, Size s) {
    final rect = Rect.fromLTWH(7, 7, s.width - 14, s.height - 14);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    c.drawArc(rect, math.pi * .7, math.pi * 1.6, false, p..color = track);
    if (value > 0) {
      c.drawArc(
        rect,
        math.pi * .7,
        math.pi * 1.6 * value,
        false,
        p..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}

class FamiliarButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  const FamiliarButton(
    this.label,
    this.icon, {
    super.key,
    this.onTap,
    this.filled = false,
  });
  @override
  Widget build(BuildContext c) => Pressable(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: S.tap),
      padding: const EdgeInsets.symmetric(horizontal: S.x3, vertical: S.x2),
      decoration: BoxDecoration(
        borderRadius: R.rSm,
        color: filled ? P.of(c).ink : P.of(c).card2,
        border: Border.all(color: P.of(c).line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 17, color: filled ? P.of(c).bg : P.of(c).ink),
          const SizedBox(width: S.x2),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: F.cap.copyWith(color: filled ? P.of(c).bg : P.of(c).ink),
            ),
          ),
        ],
      ),
    ),
  );
}

class FamiliarChart extends StatelessWidget {
  final List<double?> first, second;
  final double maxFirst, maxSecond;
  final Color color;
  const FamiliarChart({
    super.key,
    required this.first,
    this.second = const [],
    this.maxFirst = 21,
    this.maxSecond = 100,
    this.color = C.blue,
  });
  @override
  Widget build(BuildContext c) => SizedBox(
    height: 140,
    child: CustomPaint(
      size: const Size(double.infinity, 140),
      painter: _Lines(
        first,
        second,
        maxFirst,
        maxSecond,
        color,
        P.of(c).on(C.green),
        P.of(c).line,
      ),
    ),
  );
}

class _Lines extends CustomPainter {
  final List<double?> a, b;
  final double am, bm;
  final Color color, green, line;
  _Lines(this.a, this.b, this.am, this.bm, this.color, this.green, this.line);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..strokeWidth = 1
      ..color = line;
    for (var i = 0; i < 5; i++) {
      c.drawLine(
        Offset(0, 8 + (s.height - 16) * i / 4),
        Offset(s.width, 8 + (s.height - 16) * i / 4),
        p,
      );
    }
    void draw(List<double?> list, double max, Color color) {
      if (list.isEmpty || max <= 0) return;
      Offset? prev;
      for (var i = 0; i < list.length; i++) {
        final v = list[i];
        if (v == null || !v.isFinite) {
          prev = null;
          continue;
        }
        final at = Offset(
          5 + (s.width - 10) * i / math.max(1, list.length - 1),
          s.height - 8 - (s.height - 16) * (v / max).clamp(0.0, 1.0),
        );
        if (prev != null) {
          c.drawLine(
            prev,
            at,
            p
              ..color = color
              ..strokeWidth = 2,
          );
        }
        c.drawCircle(at, 3, p..color = color);
        prev = at;
      }
    }

    draw(a, am, color);
    draw(b, bm, green);
  }

  @override
  bool shouldRepaint(_Lines old) =>
      old.a != a || old.b != b || old.line != line || old.color != color;
}

class FamiliarPage extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const FamiliarPage(this.title, {super.key, required this.children});
  @override
  Widget build(BuildContext c) => Scaffold(
    backgroundColor: P.of(c).bg,
    appBar: AppBar(
      title: Text(title, style: F.head),
      backgroundColor: P.of(c).bg,
    ),
    body: ListView(padding: const EdgeInsets.all(S.x4), children: children),
  );
}

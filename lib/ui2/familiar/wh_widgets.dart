// Shared WHOOP-parity building blocks for the Familiar surface: the phone-frame
// topbar, navbar, cards, rows, chips, pills, menus and the observation card.
// Geometry follows design/whoop-mock-v6/app.css; every colour and text style is
// a token from theme.dart (`W` / `FW` / `WR`).
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../grammar.dart';
import '../theme.dart';

/// One WHOOP design icon (`assets/icons/whoop/NAME.svg`), tinted.
class WhIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color color;
  const WhIcon(this.name, {super.key, this.size = 20, this.color = W.ink4});
  @override
  Widget build(BuildContext c) => SvgPicture.asset(
    'assets/icons/whoop/$name.svg',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    semanticsLabel: null,
  );
}

/// The screen scaffold every Familiar detail uses: WHOOP navbar (back · title ·
/// info) over a padded ListView on [W.bg].
class WhPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? right;
  final Widget? titleWidget;
  final List<Widget> children;
  final Key? listKey;
  const WhPage({
    super.key,
    required this.title,
    this.subtitle,
    this.right,
    this.titleWidget,
    this.listKey,
    required this.children,
  });
  @override
  Widget build(BuildContext c) => Scaffold(
    backgroundColor: W.bg,
    body: SafeArea(
      child: Column(
        children: [
          WhNavbar(title: title, subtitle: subtitle, right: right, titleWidget: titleWidget),
          Expanded(
            child: ListView(
              key: listKey,
              padding: const EdgeInsets.fromLTRB(S.x4, 0, S.x4, S.x10),
              children: children,
            ),
          ),
        ],
      ),
    ),
  );
}

class WhNavbar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? right;
  final Widget? titleWidget;
  const WhNavbar({super.key, required this.title, this.subtitle, this.right, this.titleWidget});
  @override
  Widget build(BuildContext c) => SizedBox(
    height: 52,
    child: Row(
      children: [
        Pressable(
          onTap: () => Navigator.of(c).maybePop(),
          semanticLabel: 'Назад',
          child: const SizedBox(width: 44, height: 44, child: Center(child: WhIcon('navigation_backward', size: 18, color: W.ink))),
        ),
        Expanded(
          child: titleWidget ??
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title.toUpperCase(), style: FW.h5.copyWith(color: W.ink), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (subtitle != null) Text(subtitle!, style: FW.hint.copyWith(color: W.ink2), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
        ),
        SizedBox(width: 44, height: 44, child: Center(child: right ?? const WhInfoDot())),
      ],
    ),
  );
}

/// The circled “i”.
class WhInfoDot extends StatelessWidget {
  final double size;
  const WhInfoDot({super.key, this.size = 26});
  @override
  Widget build(BuildContext c) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: W.ink3, width: 1.5)),
    child: Center(child: Text('i', style: FW.b2.copyWith(color: W.ink4, fontStyle: FontStyle.italic))),
  );
}

/// WHOOP card: #1A2227, radius 16, padding 16, optional tap.
class WhCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final bool tip;
  final Color color;
  final EdgeInsets margin;
  const WhCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(S.x4),
    this.tip = false,
    this.color = W.card,
    this.margin = const EdgeInsets.only(bottom: S.x3),
  });
  @override
  Widget build(BuildContext c) {
    final body = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(color: color, borderRadius: WR.rCard),
      child: child,
    );
    final withTip = tip
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              body,
              Positioned(
                top: -8,
                left: 0,
                right: 0,
                child: Center(
                  child: Transform.rotate(
                    angle: 0.785398,
                    child: Container(width: 16, height: 16, color: color),
                  ),
                ),
              ),
            ],
          )
        : body;
    return Padding(
      padding: margin.copyWith(top: tip ? S.x2 : margin.top),
      child: onTap == null ? withTip : Pressable(onTap: onTap, child: withTip),
    );
  }
}

/// Card header: uppercase label left, optional chevron/extra right.
class WhCardHead extends StatelessWidget {
  final String label;
  final Widget? right;
  final bool chevron;
  const WhCardHead(this.label, {super.key, this.right, this.chevron = false});
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(bottom: S.x2),
    child: Row(
      children: [
        Expanded(child: Text(label.toUpperCase(), style: FW.label.copyWith(color: W.ink))),
        ?right,
        if (chevron) const WhIcon('navigation_forward', size: 14, color: W.ink4),
      ],
    ),
  );
}

/// “Мой день” style section title.
class WhSection extends StatelessWidget {
  final String title;
  final Widget? right;
  const WhSection(this.title, {super.key, this.right});
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.fromLTRB(0, S.x5, 0, S.x3),
    child: Row(
      children: [
        Expanded(child: Text(title, style: FW.t3.copyWith(color: W.ink))),
        ?right,
      ],
    ),
  );
}

/// The ▲ / ▼ / ● delta glyph.
class WhTri extends StatelessWidget {
  final String dir; // up | dn | eq
  final bool goodIsUp;
  const WhTri(this.dir, {super.key, this.goodIsUp = true});
  @override
  Widget build(BuildContext c) {
    final good = dir == 'eq' ? W.ink3 : (dir == 'up') == goodIsUp ? W.action : W.neg;
    return SizedBox(
      width: 14,
      child: Text(dir == 'up' ? '▲' : dir == 'dn' ? '▼' : '●', textAlign: TextAlign.center, style: FW.tiny.copyWith(color: good)),
    );
  }
}

/// Metric row: icon · LABEL · value / previous · triangle (recovery/strain).
class WhRow extends StatelessWidget {
  final String icon, label, value;
  final String? prev;
  final String dir;
  final bool goodIsUp;
  final VoidCallback? onTap;
  final Widget? middle;
  const WhRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.prev,
    this.dir = 'eq',
    this.goodIsUp = true,
    this.onTap,
    this.middle,
  });
  @override
  Widget build(BuildContext c) {
    final row = Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(vertical: S.x1, horizontal: S.x1),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: W.line2))),
      child: Row(
        children: [
          WhIcon(icon, size: 20),
          const SizedBox(width: S.x2 + 2),
          Expanded(child: Text(label.toUpperCase(), style: FW.over.copyWith(color: W.ink), maxLines: 2)),
          if (middle != null) ...[middle!, const SizedBox(width: S.x2)],
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: FW.n17.copyWith(color: W.ink)),
              if (prev != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(prev!, style: FW.tiny.copyWith(color: W.ink3))),
            ],
          ),
          if (middle == null) ...[const SizedBox(width: S.x1), WhTri(dir, goodIsUp: goodIsUp)],
        ],
      ),
    );
    return onTap == null ? row : Pressable(onTap: onTap, child: row);
  }
}

/// Three-segment level indicator (poor / sufficient / optimal).
class WhSeg3 extends StatelessWidget {
  final int level;
  final double width;
  const WhSeg3(this.level, {super.key, this.width = 22});
  @override
  Widget build(BuildContext c) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < 3; i++)
        Container(
          width: width,
          height: 3,
          margin: EdgeInsets.only(left: i == 0 ? 0 : 4),
          decoration: BoxDecoration(color: i == level ? W.level(level) : W.track, borderRadius: WR.rBar),
        ),
    ],
  );
}

/// Legend “▲▼ Сегодня vs. последние 30 дней”.
class WhLegendNote extends StatelessWidget {
  final List<Widget> children;
  const WhLegendNote({super.key, required this.children});
  @override
  Widget build(BuildContext c) => Container(
    margin: const EdgeInsets.only(top: S.x2 + 2),
    padding: const EdgeInsets.symmetric(horizontal: S.x3, vertical: S.x2),
    decoration: BoxDecoration(color: W.bg, borderRadius: WR.rChip),
    child: Row(children: children),
  );
}

/// The “Наблюдение” card: eyebrow with a bulb, text and an uppercase link.
class WhObservationCard extends StatelessWidget {
  final String text;
  final String? link;
  final VoidCallback? onLink;
  final String eyebrow;
  final Widget? badge;
  final VoidCallback? onDismiss;
  const WhObservationCard({
    super.key,
    required this.text,
    this.link,
    this.onLink,
    this.eyebrow = 'Наблюдение',
    this.badge,
    this.onDismiss,
  });
  @override
  Widget build(BuildContext c) {
    final body = Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(S.x4, S.x3 + 2, badge == null ? S.x4 : S.x12, S.x3 + 2),
      decoration: BoxDecoration(color: W.card, borderRadius: WR.rTile, border: Border.all(color: W.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const WhIcon('advice', size: 12, color: W.ink4),
              const SizedBox(width: S.x1),
              Expanded(child: Text(eyebrow.toUpperCase(), style: FW.over.copyWith(color: W.ink2))),
            ],
          ),
          const SizedBox(height: S.x1 + 2),
          Text(text, style: FW.body.copyWith(color: W.ink)),
          if (link != null) ...[
            const SizedBox(height: S.x2 + 2),
            Pressable(
              onTap: onLink,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(link!.toUpperCase(), style: FW.label.copyWith(color: W.ink)),
                  const SizedBox(width: S.x1 + 2),
                  const WhIcon('arrow_forward', size: 12, color: W.ink),
                ],
              ),
            ),
          ],
        ],
      ),
    );
    final stacked = badge == null
        ? body
        : Stack(children: [body, Positioned(right: S.x3, top: S.x3, child: badge!)]);
    return Padding(
      padding: const EdgeInsets.only(bottom: S.x3),
      child: onDismiss == null ? stacked : Pressable(onTap: onDismiss, semanticLabel: 'Закрыть наблюдение', child: stacked),
    );
  }
}

/// The white check-with-count badge on the observation stack.
class WhCountBadge extends StatelessWidget {
  final int count;
  const WhCountBadge(this.count, {super.key});
  @override
  Widget build(BuildContext c) => Container(
    width: 24,
    height: 40,
    decoration: BoxDecoration(color: W.ink, borderRadius: WR.rBar),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const WhIcon('checkmark', size: 11, color: W.onLight),
          const SizedBox(height: 2),
          Text('$count', style: FW.n11.copyWith(color: W.onLight)),
        ],
      ),
    ),
  );
}

/// Rounded pill button (Добавить / Начать).
class WhPill extends StatelessWidget {
  final String label;
  final String? icon;
  final VoidCallback? onTap;
  final bool outline, white;
  const WhPill(this.label, {super.key, this.icon, this.onTap, this.outline = false, this.white = false});
  @override
  Widget build(BuildContext c) => Pressable(
    onTap: onTap,
    child: Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: S.x3),
      decoration: BoxDecoration(
        color: white ? W.ink : outline ? null : W.card3,
        borderRadius: WR.rPill,
        border: outline ? Border.all(color: W.ink2, width: 1.5) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[WhIcon(icon!, size: 14, color: white ? W.onLight : W.ink), const SizedBox(width: S.x1 + 3)],
          Flexible(child: Text(label.toUpperCase(), style: FW.pill.copyWith(color: white ? W.onLight : W.ink), overflow: TextOverflow.ellipsis)),
        ],
      ),
    ),
  );
}

/// Full-width big button (Планировщик сна / Начать сессию).
class WhBigButton extends StatelessWidget {
  final String label;
  final String? icon;
  final VoidCallback? onTap;
  final bool outline;
  const WhBigButton(this.label, {super.key, this.icon, this.onTap, this.outline = true});
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(top: S.x1, bottom: S.x3),
    child: Pressable(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: outline ? null : W.ink,
          borderRadius: WR.rPill,
          border: outline ? Border.all(color: W.ink2, width: 1.5) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[WhIcon(icon!, size: 16, color: outline ? W.ink : W.onLight), const SizedBox(width: S.x2)],
            Flexible(child: Text(label.toUpperCase(), style: FW.h5.copyWith(color: outline ? W.ink : W.onLight), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    ),
  );
}

/// Segmented control (Нед · Мес · 6 мес).
class WhSegmented extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  final double? width;
  const WhSegmented({super.key, required this.labels, required this.selected, required this.onSelect, this.width});
  @override
  Widget build(BuildContext c) => Container(
    width: width,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(color: W.bg, borderRadius: WR.rPill),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Pressable(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: motion(c, Motion.fast),
                height: 28,
                decoration: BoxDecoration(color: i == selected ? W.card3 : null, borderRadius: WR.rPill),
                child: Center(child: Text(labels[i].toUpperCase(), style: FW.pill.copyWith(color: i == selected ? W.ink : W.ink2))),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Chip row (Весь день · Без активности · Сон).
class WhChips extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  const WhChips({super.key, required this.labels, required this.selected, required this.onSelect});
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(top: S.x1, bottom: S.x3),
    child: Wrap(
      spacing: S.x2,
      runSpacing: S.x2,
      children: [
        for (var i = 0; i < labels.length; i++)
          Pressable(
            onTap: () => onSelect(i),
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: i == selected ? W.ink : W.card2, borderRadius: WR.rPill),
              child: Center(child: Text(labels[i].toUpperCase(), style: FW.pill.copyWith(color: i == selected ? W.onLight : W.ink))),
            ),
          ),
      ],
    ),
  );
}

/// Menu list card: icon · title / subtitle · chevron.
class WhMenu extends StatelessWidget {
  final List<WhMenuItem> items;
  const WhMenu(this.items, {super.key});
  @override
  Widget build(BuildContext c) => Container(
    margin: const EdgeInsets.only(bottom: S.x3),
    padding: const EdgeInsets.symmetric(horizontal: S.x1),
    decoration: BoxDecoration(color: W.card, borderRadius: WR.rCard),
    child: Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Pressable(
            onTap: items[i].onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 54),
              padding: const EdgeInsets.symmetric(horizontal: S.x2 + 2, vertical: S.x2),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: i == items.length - 1 ? W.clear : W.line2))),
              child: Row(
                children: [
                  if (items[i].icon != null) ...[WhIcon(items[i].icon!, size: 20), const SizedBox(width: S.x3)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(items[i].title, style: FW.menu.copyWith(color: W.ink)),
                        if (items[i].subtitle != null) Text(items[i].subtitle!, style: FW.hint.copyWith(color: W.ink2)),
                      ],
                    ),
                  ),
                  if (items[i].trailing != null) items[i].trailing!,
                  if (items[i].trailing == null) const WhIcon('navigation_forward', size: 12, color: W.axis),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class WhMenuItem {
  final String title;
  final String? subtitle, icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  const WhMenuItem(this.title, {this.subtitle, this.icon, this.onTap, this.trailing});
}

/// Key/value line inside a card.
class WhKv extends StatelessWidget {
  final String label, value;
  final String? unit;
  final bool last;
  const WhKv(this.label, this.value, {super.key, this.unit, this.last = false});
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.symmetric(vertical: S.x2 + 2),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: last ? W.clear : W.line2))),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: Text(label, style: FW.body.copyWith(color: W.ink))),
        Text(value, style: FW.n15.copyWith(color: W.ink)),
        if (unit != null) ...[const SizedBox(width: 3), Text(unit!, style: FW.hint.copyWith(color: W.ink3))],
      ],
    ),
  );
}

/// Status pill: “В норме”, “Выше нормы”, “—”.
class WhStatus extends StatelessWidget {
  final String text;
  final int tone; // 2 ok, 1 warn, 0 bad, -1 none
  final String? icon;
  const WhStatus(this.text, {super.key, this.tone = 2, this.icon});
  @override
  Widget build(BuildContext c) {
    final color = tone == 2 ? W.action : tone == 1 ? W.neg : tone == 0 ? W.recLow : W.ink3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: S.x2, vertical: S.x1),
      decoration: BoxDecoration(color: color.withValues(alpha: tone < 0 ? .06 : .15), borderRadius: WR.rPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[WhIcon(icon!, size: 11, color: color), const SizedBox(width: S.x1)],
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: FW.b2.copyWith(color: color))),
        ],
      ),
    );
  }
}

/// Small “i” note under a chart.
class WhHint extends StatelessWidget {
  final String text;
  final bool info;
  const WhHint(this.text, {super.key, this.info = false});
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(top: S.x2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (info) ...[const Padding(padding: EdgeInsets.only(top: 2), child: WhIcon('tiny_information', size: 10, color: W.ink3)), const SizedBox(width: S.x1 + 2)],
        Expanded(child: Text(text, style: FW.hint.copyWith(color: W.ink3))),
      ],
    ),
  );
}

/// Percent-change chip (“▲ 4 % к прошлой неделе”).
class WhChangeChip extends StatelessWidget {
  final double delta;
  final String suffix;
  const WhChangeChip(this.delta, this.suffix, {super.key});
  @override
  Widget build(BuildContext c) {
    final dir = delta > 0 ? 'up' : delta < 0 ? 'dn' : 'eq';
    final color = dir == 'up' ? W.action : dir == 'dn' ? W.neg : W.ink2;
    // Icons, not glyphs: the numeric face has no ▲ ▼ ● and drew boxes.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(color: W.card2, borderRadius: WR.rBar),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dir == 'eq')
            Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle))
          else
            WhIcon(dir == 'up' ? 'tiny_triangle_up' : 'tiny_triangle_down', size: 8, color: color),
          const SizedBox(width: 4),
          Text('${delta.abs().round()} % $suffix', style: FW.n9.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// Two-column legend row of colour squares.
class WhLegend extends StatelessWidget {
  final List<(Color, String)> items;
  final MainAxisAlignment align;
  const WhLegend(this.items, {super.key, this.align = MainAxisAlignment.end});
  @override
  Widget build(BuildContext c) => Row(
    mainAxisAlignment: align,
    children: [
      for (final (color, label) in items)
        Padding(
          padding: const EdgeInsets.only(left: S.x3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: WR.rTiny)),
              const SizedBox(width: 5),
              Text(label.toUpperCase(), style: FW.tiny.copyWith(color: W.ink2, fontWeight: FontWeight.w700, letterSpacing: .7)),
            ],
          ),
        ),
    ],
  );
}

/// Hint at the bottom of a screen.
class WhNote extends StatelessWidget {
  final String text;
  const WhNote(this.text, {super.key});
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(top: S.x2, bottom: S.x2),
    child: Text(text, textAlign: TextAlign.center, style: FW.tiny.copyWith(color: W.ink3, height: 13 / 9)),
  );
}

String ruDecimal(num? v, [int digits = 1]) => v == null || !v.isFinite ? '—' : v.toStringAsFixed(digits).replaceAll('.', ',');
String hmOf(num? minutes) => minutes == null || !minutes.isFinite ? '—' : '${minutes.round() ~/ 60}:${(minutes.round() % 60).toString().padLeft(2, '0')}';
String hmsOf(num? seconds) => seconds == null || !seconds.isFinite ? '—' : '${seconds.round() ~/ 3600}:${((seconds.round() % 3600) ~/ 60).toString().padLeft(2, '0')}:${(seconds.round() % 60).toString().padLeft(2, '0')}';
String groupThousands(num? v) {
  if (v == null || !v.isFinite) return '—';
  final s = v.round().toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(' ');
    out.write(s[i]);
  }
  return out.toString();
}

const ruMonthsShort = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
const ruMonthsGen = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
const ruDow = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
const ruDowFull = ['понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье'];
String dayShort(DateTime d) => '${d.day} ${ruMonthsShort[d.month - 1]}';
String dowShort(DateTime d) => '${ruDow[d.weekday - 1]} ${d.day}';
String clockOf(int? epochSec) {
  if (epochSec == null) return '—';
  final t = DateTime.fromMillisecondsSinceEpoch(epochSec * 1000);
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

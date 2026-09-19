import '../coach/coach_engine.dart';
import '../data/journal_fields.dart';
import 'ru_activity_extra.dart';
import 'ru_observations_extra.dart';

/// Render the action's real arguments; never translate or modify the request
/// that is actually executed after the user's confirmation.
String coachActionSummary(ActionRequest request, String? locale) {
  if (!observationsUseRussian(locale)) return request.summary;
  final a = request.args;
  final date = a['date'] ?? 'сегодня';
  final sport = ruActivityText('${a['type'] ?? 'workout'}', locale: locale);
  switch (request.tool) {
    case 'log_journal':
      final tags = (a['tags'] as List? ?? []).map((t) => journalTagLabel('$t', locale)).join(', ');
      return 'Добавить запись за $date. Метки: ${tags.isEmpty ? 'нет' : tags}. Заметка: «${a['note'] ?? ''}».';
    case 'log_period':
      return 'Отметить начало менструации: $date.';
    case 'start_workout':
      return 'Начать тренировку сейчас. Вид: $sport.';
    case 'end_workout':
      return 'Завершить текущую тренировку.';
    case 'log_food':
      final meal = ruActivityText('${a['meal']}', locale: locale);
      return 'Добавить «${a['label']}». Приём пищи: $meal. Дата: $date${a['kcal'] == null ? '' : ' (${a['kcal']} ккал)'}.';
    case 'log_journal_fields':
      final fields = a['fields'];
      final values = fields is Map ? fields.entries.map((e) {
        final unit = kJournalFieldsByKey['${e.key}']?.unit ?? '';
        return '${journalInsightField('${e.key}', '${e.key}', locale)}: ${e.value}${unit.isEmpty ? '' : ' ${observationUnit(unit, locale)}'}';
      }).join(', ') : 'нет полей';
      return 'Записать за $date: $values.';
    case 'add_completed_workout':
      return 'Сохранить тренировку «$sport» длительностью ${a['duration_min']} мин. Начало: ${a['start_time']}, дата: $date.';
    case 'add_medication':
      final days = a['weekdays'];
      const names = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
      final schedule = days is! List || days.isEmpty
          ? 'ежедневно' : days.map((d) => d is num && d >= 1 && d <= 7 ? names[d.toInt() - 1] : '?').join(', ');
      return 'Добавить в расписание «${a['name']}»: ${a['time']}, $schedule. Приложение не проверяет взаимодействия препаратов.';
    case 'mark_medication':
      final state = const {'taken':'принято', 'skipped':'намеренно пропущено', 'not_taken':'снять отметку о приёме'}['${a['state']}'] ?? '${a['state']}';
      return 'Препарат «${a['name']}», дата: $date. Установить отметку: $state.';
    case 'set_step_goal':
      return 'Задать ежедневную цель: ${a['goal']} шагов.';
    default:
      return request.summary;
  }
}

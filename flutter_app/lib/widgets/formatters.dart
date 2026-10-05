String twoDigits(int value) => value.toString().padLeft(2, '0');

String formatTime(DateTime value) {
  final local = value.toLocal();
  return '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

String formatShortDate(DateTime value) {
  value = value.toLocal();
  const months = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
  return '${value.day} de ${months[value.month - 1]}';
}

String formatLongDate(DateTime value) {
  value = value.toLocal();
  const weekdays = ['segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];
  const months = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];
  final weekday = weekdays[value.weekday - 1];
  return '${weekday[0].toUpperCase()}${weekday.substring(1)}, ${value.day} de ${months[value.month - 1]}';
}

String formatMonthYear(DateTime value) {
  value = value.toLocal();
  const months = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
  return '${months[value.month - 1]} de ${value.year}';
}

String formatBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return '—';
  final mb = bytes / (1024 * 1024);
  if (mb >= 1) return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB';
  return '${(bytes / 1024).toStringAsFixed(0)} KB';
}

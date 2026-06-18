import 'package:flutter/material.dart';

enum VoiceCommand {
  newTask,
  newHabit,
  newReminder,
  goTasks,
  goHabits,
  goReminders,
  goHome,
  goStats,
  signOut,
  unknown,
}

class VoiceCommandService {
  static VoiceCommand parse(String text) {
    final t = text.toLowerCase().trim();

    if (_matches(t, ['nueva tarea', 'crear tarea', 'añadir tarea', 'agregar tarea'])) {
      return VoiceCommand.newTask;
    }
    if (_matches(t, ['nuevo hábito', 'crear hábito', 'añadir hábito', 'agregar hábito'])) {
      return VoiceCommand.newHabit;
    }
    if (_matches(t, ['nuevo recordatorio', 'crear recordatorio', 'añadir recordatorio', 'nueva alerta'])) {
      return VoiceCommand.newReminder;
    }
    if (_matches(t, ['ir a tareas', 'mostrar tareas', 'ver tareas', 'tareas'])) {
      return VoiceCommand.goTasks;
    }
    if (_matches(t, ['ir a hábitos', 'mostrar hábitos', 'ver hábitos', 'hábitos'])) {
      return VoiceCommand.goHabits;
    }
    if (_matches(t, ['ir a alertas', 'mostrar alertas', 'ver alertas', 'recordatorios', 'alertas'])) {
      return VoiceCommand.goReminders;
    }
    if (_matches(t, ['inicio', 'ir a inicio', 'ir al inicio', 'home'])) {
      return VoiceCommand.goHome;
    }
    if (_matches(t, ['estadísticas', 'estadisticas', 'stats', 'ir a estadísticas'])) {
      return VoiceCommand.goStats;
    }
    if (_matches(t, ['cerrar sesión', 'cerrar sesion', 'salir', 'logout'])) {
      return VoiceCommand.signOut;
    }

    return VoiceCommand.unknown;
  }

  static bool _matches(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }

  // Descripción del comando para mostrar al usuario
  static String description(VoiceCommand cmd) {
    switch (cmd) {
      case VoiceCommand.newTask: return '📋 Abriendo nueva tarea...';
      case VoiceCommand.newHabit: return '🔄 Abriendo nuevo hábito...';
      case VoiceCommand.newReminder: return '🔔 Abriendo nuevo recordatorio...';
      case VoiceCommand.goTasks: return '📋 Yendo a Tareas...';
      case VoiceCommand.goHabits: return '🔄 Yendo a Hábitos...';
      case VoiceCommand.goReminders: return '🔔 Yendo a Alertas...';
      case VoiceCommand.goHome: return '🏠 Yendo a Inicio...';
      case VoiceCommand.goStats: return '📊 Yendo a Estadísticas...';
      case VoiceCommand.signOut: return '👋 Cerrando sesión...';
      case VoiceCommand.unknown: return '❓ Comando no reconocido';
    }
  }
}
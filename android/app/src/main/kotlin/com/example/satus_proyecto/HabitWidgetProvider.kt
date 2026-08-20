package com.example.satus_proyecto

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import android.widget.RemoteViews

class HabitWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) updateWidget(context, appWidgetManager, id)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, HabitWidgetProvider::class.java))

        when (intent.action) {
            "com.example.satus_proyecto.UPDATE_WIDGET",
            "com.example.satus_proyecto.REFRESH_WIDGET" -> {
                val ids = manager.getAppWidgetIds(ComponentName(context, HabitWidgetProvider::class.java))

                // Feedback visual
                val feedbackViews = RemoteViews(context.packageName, R.layout.habit_widget)
                feedbackViews.setTextViewText(R.id.btn_refresh, "✓")
                feedbackViews.setTextColor(R.id.btn_refresh, -16711936)
                feedbackViews.setOnClickPendingIntent(R.id.btn_refresh, null)
                for (id in ids) manager.updateAppWidget(id, feedbackViews)

                // Actualizar hora directamente desde Kotlin sin depender de Flutter
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val now = java.util.Calendar.getInstance()
                val timeStr = String.format("%02d:%02d", now.get(java.util.Calendar.HOUR_OF_DAY),
                    now.get(java.util.Calendar.MINUTE))
                prefs.edit().putString("flutter.current_time", timeStr).apply()

                // Recalcular cuál hábito está activo ahora
                val nowMin = now.get(java.util.Calendar.HOUR_OF_DAY) * 60 + now.get(java.util.Calendar.MINUTE)
                for (n in 1..2) {
                    val start = prefs.getString("flutter.habit_start_$n", "") ?: ""
                    val end   = prefs.getString("flutter.habit_end_$n", "") ?: ""
                    if (start.isNotEmpty() && end.isNotEmpty()) {
                        val startParts = start.split(":")
                        val endParts   = end.split(":")
                        val startMin = (startParts[0].toIntOrNull() ?: 0) * 60 + (startParts[1].toIntOrNull() ?: 0)
                        val endMin   = (endParts[0].toIntOrNull() ?: 0) * 60 + (endParts[1].toIntOrNull() ?: 0)
                        val isActive = nowMin >= startMin && nowMin < endMin
                        prefs.edit().putBoolean("flutter.habit_active_$n", isActive).apply()
                    }
                }

                // Programar restauración
                val restoreIntent = Intent(context, HabitWidgetProvider::class.java).apply {
                    action = "com.example.satus_proyecto.RESTORE_WIDGET"
                }
                val restorePending = PendingIntent.getBroadcast(
                    context, 100, restoreIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
                alarmManager.set(android.app.AlarmManager.RTC, System.currentTimeMillis() + 1000, restorePending)
            }

            "com.example.satus_proyecto.RESTORE_WIDGET" -> {
                val ids = manager.getAppWidgetIds(ComponentName(context, HabitWidgetProvider::class.java))
                for (id in ids) updateWidget(context, manager, id)
            }
            "com.example.satus_proyecto.CHECK_HABIT" -> {
                val n = intent.getIntExtra("habit_index", 0)
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

                // Leer fecha de hoy
                val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.getDefault())
                    .format(java.util.Date())

                // Leer fechas completadas actuales
                val key = "flutter.habit_dates_$n"
                val datesStr = prefs.getString(key, "") ?: ""
                val dates = if (datesStr.isEmpty()) mutableListOf()
                else datesStr.split(",").toMutableList()

                // Toggle
                if (dates.contains(today)) {
                    dates.remove(today)
                } else {
                    dates.add(today)
                }

                prefs.edit().putString(key, dates.joinToString(",")).apply()

                // Marcar como hecho hoy en la key simple
                val isDone = dates.contains(today)
                prefs.edit().putBoolean("flutter.habit_done_$n", isDone).apply()

                Log.d("SatusWidget", "Hábito $n: done=$isDone, fecha=$today")

                for (id in ids) updateWidget(context, manager, id)
            }
        }
    }

    companion object {

        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val prefs: SharedPreferences = context.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE)
            val views = RemoteViews(context.packageName, R.layout.habit_widget)

            val currentTime = prefs.getString("flutter.current_time", "") ?: ""
            val count = prefs.getLong("flutter.habit_count", 0L).toInt()

            views.setTextViewText(R.id.widget_time, "🟢 $currentTime")

            // Botón refrescar
            val refreshIntent = Intent(context, HabitWidgetProvider::class.java).apply {
                action = "com.example.satus_proyecto.REFRESH_WIDGET"
            }
            val refreshPending = PendingIntent.getBroadcast(
                context, 99, refreshIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.btn_refresh, refreshPending)
            views.setTextViewText(R.id.btn_refresh, "↻")
            views.setTextColor(R.id.btn_refresh, -12534498)

            val titleIds = listOf<Int>(R.id.widget_habit1, R.id.widget_habit2)

            if (count == 0) {
                views.setViewVisibility(R.id.empty_text, android.view.View.VISIBLE)
                titleIds.forEach { views.setTextViewText(it, "") }
            } else {
                views.setViewVisibility(R.id.empty_text, android.view.View.GONE)

                for (i in 0..1) {
                    val n = i + 1
                    val title  = prefs.getString("flutter.habit_title_$n", "") ?: ""
                    val start  = prefs.getString("flutter.habit_start_$n", "") ?: ""
                    val habitId = prefs.getString("flutter.habit_id_$n", "") ?: ""
                    val isActive = try {
                        prefs.getBoolean("flutter.habit_active_$n", false)
                    } catch (e: ClassCastException) { false }

                    val text = if (n <= count && title.isNotEmpty()) "$start  $title" else ""
                    views.setTextViewText(titleIds[i], text)
                    views.setTextColor(titleIds[i], if (isActive) -1 else -6776040)
                    views.setViewVisibility(titleIds[i],
                        if (n <= count && title.isNotEmpty()) android.view.View.VISIBLE
                        else android.view.View.GONE)

                    // Click en hábito — abre la app
                    if (habitId.isNotEmpty()) {
                        val openIntent = Intent(context, MainActivity::class.java).apply {
                            action = Intent.ACTION_VIEW
                            putExtra("habit_id", habitId)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        }
                        val openPending = PendingIntent.getActivity(
                            context, 200 + n, openIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        val openAppIntent = Intent(context, MainActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        }
                        val openAppPending = PendingIntent.getActivity(
                            context, 300, openAppIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        views.setOnClickPendingIntent(titleIds[i], openPending)
                        views.setOnClickPendingIntent(android.R.id.content, openAppPending)
                    }
                }
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
            Log.d("SatusWidget", "Widget: $count hábitos")
        }
    }
}
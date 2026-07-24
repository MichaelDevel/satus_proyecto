package com.example.satus_proyecto

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
        println("Actualizando widget app desde provider...")
        println("IDs de widgets a actualizar: ${appWidgetIds.joinToString()}")
        for (id in appWidgetIds) updateWidget(context, appWidgetManager, id)
        println("Actualizado widget app desde provider")
    }

    override fun onReceive(context: Context, intent: Intent) {
        android.util.Log.d("SatusWidget", "onReceive: ${intent.action}")
        super.onReceive(context, intent)
        if (intent.action == "com.example.satus_proyecto.UPDATE_WIDGET") {
            android.util.Log.d("SatusWidget", "✅ Broadcast capturado, actualizando...")
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, HabitWidgetProvider::class.java))
            for (id in ids) updateWidget(context, manager, id)
        }
    }

    companion object {
        private val barColors = listOf(-10158081, -12534498, -2760960)

        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val views = RemoteViews(context.packageName, R.layout.habit_widget)

            val currentTime = prefs.getString("flutter.current_time", "") ?: ""
            val count = prefs.getLong("flutter.habit_count", 0L).toInt()

            views.setTextViewText(R.id.widget_time, "🟢 $currentTime  HÁBITOS DE HOY")

            val titleIds = listOf<Int>(R.id.widget_habit1, R.id.widget_habit2, R.id.widget_habit3)

            if (count == 0) {
                views.setViewVisibility(R.id.empty_text, android.view.View.VISIBLE)
                titleIds.forEach { views.setTextViewText(it, "") }
            } else {
                views.setViewVisibility(R.id.empty_text, android.view.View.GONE)
                for (i in 0..2) {
                    val n = i + 1
                    val title = prefs.getString("flutter.habit_title_$n", "") ?: ""
                    val start = prefs.getString("flutter.habit_start_$n", "") ?: ""
                    val end   = prefs.getString("flutter.habit_end_$n", "") ?: ""
                    val isActive = try {
                        prefs.getBoolean("flutter.habit_active_$n", false)
                    } catch (e: ClassCastException) {
                        false
                    }
                    val text = if (n <= count && title.isNotEmpty()) "$start-$end  $title" else ""
                    views.setTextViewText(titleIds[i], text)
                    views.setTextColor(titleIds[i], if (isActive) -12534498 else -6776040)
                }
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
            Log.d("SatusWidget", "Widget: $count hábitos")
        }
    }
}
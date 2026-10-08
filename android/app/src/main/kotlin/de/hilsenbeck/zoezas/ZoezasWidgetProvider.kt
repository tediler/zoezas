package de.hilsenbeck.zoezas

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Homescreen-Widget: zeigt das verfügbare Guthaben und öffnet per Tipp direkt
 * die Schnelleingabe in der App (zoezas://add?type=…).
 *
 * Die Werte schreibt die Flutter-App über home_widget in die SharedPreferences
 * (siehe lib/platform/platform_integration.dart).
 */
class ZoezasWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.zoezas_widget).apply {
                setTextViewText(R.id.widget_amount, widgetData.getString("available", null) ?: "—")
                setTextViewText(
                    R.id.widget_forecast,
                    widgetData.getString("forecast", null) ?: context.getString(R.string.widget_empty),
                )
                val negative = widgetData.getString("negative", "false") == "true"
                setTextColor(R.id.widget_amount, if (negative) 0xFFD9707E.toInt() else 0xFF29242A.toInt())

                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
                setOnClickPendingIntent(
                    R.id.widget_add_expense,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("zoezas://add?type=expense"),
                    ),
                )
                setOnClickPendingIntent(
                    R.id.widget_add_income,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("zoezas://add?type=income"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

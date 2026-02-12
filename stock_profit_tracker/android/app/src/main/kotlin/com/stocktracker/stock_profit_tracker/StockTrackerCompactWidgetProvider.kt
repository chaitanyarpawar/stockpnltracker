package com.stocktracker.stock_profit_tracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Compact 3x2 widget provider delegating to the HomeWidget plugin.
 * Shows Stock | LTP | P&L layout with refresh button.
 */
class StockTrackerCompactWidgetProvider : HomeWidgetProvider() {
  companion object {
    const val ACTION_REFRESH = "com.stocktracker.stock_profit_tracker.ACTION_REFRESH_COMPACT"
  }

  override fun onReceive(context: Context, intent: Intent) {
    super.onReceive(context, intent)
    if (intent.action == ACTION_REFRESH) {
      // Trigger Dart background callback via HomeWidget
      val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(
        context,
        Uri.parse("stockwidget://refresh")
      )
      try {
        backgroundIntent.send()
      } catch (e: Exception) {
        e.printStackTrace()
      }
      
      // Also trigger widget UI update
      val updateIntent = Intent(context, StockTrackerCompactWidgetProvider::class.java).apply {
        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(
          ComponentName(context, StockTrackerCompactWidgetProvider::class.java)
        )
        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
      }
      context.sendBroadcast(updateIntent)
    }
  }

  override fun onUpdate(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetIds: IntArray,
    widgetData: SharedPreferences,
  ) {
    for (appWidgetId in appWidgetIds) {
      val views = RemoteViews(context.packageName, R.layout.stock_tracker_widget_compact)

      // Set up refresh button click - triggers refresh only, not app open
      val refreshIntent = Intent(context, StockTrackerCompactWidgetProvider::class.java).apply {
        action = ACTION_REFRESH
      }
      val refreshPendingIntent = PendingIntent.getBroadcast(
        context,
        appWidgetId,
        refreshIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
      )
      views.setOnClickPendingIntent(R.id.widget_refresh_btn, refreshPendingIntent)

      // Set up widget container click to open app
      val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
      if (launchIntent != null) {
        launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        val launchPendingIntent = PendingIntent.getActivity(
          context,
          appWidgetId + 1000,
          launchIntent,
          PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_container_compact, launchPendingIntent)
      }

      views.setTextViewText(
        R.id.widget_total_pl,
        readFirst(widgetData, "widget_total_pl", "total_pl", defaultValue = "₹0.00"),
      )
      views.setTextViewText(
        R.id.widget_last_updated,
        readFirst(widgetData, "widget_last_updated", "widget_total_percentage", "total_percentage", defaultValue = "0.00%"),
      )
      views.setTextViewText(
        R.id.widget_stock_count,
        readFirst(widgetData, "widget_stock_count", "stock_count", defaultValue = "0 stocks"),
      )

      bindRow(
        views = views,
        widgetData = widgetData,
        rowIndex = 0,
        containerId = R.id.stock_item_0,
        nameId = R.id.stock_0_name,
        ltpId = R.id.stock_0_ltp,
        valueId = R.id.stock_0_pl,
      )
      bindRow(
        views = views,
        widgetData = widgetData,
        rowIndex = 1,
        containerId = R.id.stock_item_1,
        nameId = R.id.stock_1_name,
        ltpId = R.id.stock_1_ltp,
        valueId = R.id.stock_1_pl,
      )
      bindRow(
        views = views,
        widgetData = widgetData,
        rowIndex = 2,
        containerId = R.id.stock_item_2,
        nameId = R.id.stock_2_name,
        ltpId = R.id.stock_2_ltp,
        valueId = R.id.stock_2_pl,
      )

      appWidgetManager.updateAppWidget(appWidgetId, views)
    }
  }

  private fun bindRow(
    views: RemoteViews,
    widgetData: SharedPreferences,
    rowIndex: Int,
    containerId: Int,
    nameId: Int,
    ltpId: Int,
    valueId: Int,
  ) {
    val symbol = readFirst(
      widgetData,
      "widget_stock_${rowIndex}_symbol",
      "stock_${rowIndex}_symbol",
      defaultValue = "",
    )
    val name = readFirst(
      widgetData,
      "widget_stock_${rowIndex}_name",
      "stock_${rowIndex}_name",
      defaultValue = symbol,
    )
    val ltp = readFirst(
      widgetData,
      "widget_stock_${rowIndex}_ltp",
      "stock_${rowIndex}_ltp",
      "widget_stock_${rowIndex}_price",
      "stock_${rowIndex}_price",
      defaultValue = "",
    )
    val value = readFirst(
      widgetData,
      "widget_stock_${rowIndex}_pl",
      "stock_${rowIndex}_pl",
      defaultValue = "",
    )

    val hasData = symbol.isNotBlank() || value.isNotBlank()
    views.setViewVisibility(containerId, if (hasData) View.VISIBLE else View.GONE)
    views.setTextViewText(nameId, name)
    views.setTextViewText(ltpId, ltp)
    views.setTextViewText(valueId, value)
  }

  private fun readFirst(
    widgetData: SharedPreferences,
    vararg keys: String,
    defaultValue: String,
  ): String {
    for (key in keys) {
      val value = widgetData.getString(key, null)
      if (!value.isNullOrBlank()) {
        return value
      }
    }
    return defaultValue
  }
}

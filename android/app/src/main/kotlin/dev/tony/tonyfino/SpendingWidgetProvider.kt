package dev.tony.tonyfino

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Widget "Chi tiêu từ đầu tháng" (Phase 21). CHỈ hiển thị chuỗi đã format sẵn
 * bên Dart (`SpendingWidgetService`, dùng chính `Money.format()` của hero
 * card Phase 6) — provider này không parse/cộng/tính lại số tiền, chỉ đọc
 * [widgetData] do plugin `home_widget` đồng bộ từ SharedPreferences.
 *
 * Trạng thái nguội (app chưa từng mở, chưa có key nào trong [widgetData]):
 * hiện "Mở app để xem" thay vì crash — `getString(key, null)` trả null an
 * toàn, không throw.
 */
class SpendingWidgetProvider : HomeWidgetProvider() {

    companion object {
        private const val TAG = "SpendingWidget"
        const val KEY_EXPENSE_LABEL = "expense_since_month_start"
        const val KEY_UPDATED_AT_LABEL = "updated_at_label"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        // Mốc thời gian dùng để đo độ trễ THẬT giữa lúc Dart gọi updateWidget()
        // và lúc RemoteViews thật sự vẽ lại trên máy — xem TODOS.md § Phase 21.
        Log.d(TAG, "onUpdate at ${System.currentTimeMillis()}, ids=${appWidgetIds.joinToString()}")

        appWidgetIds.forEach { widgetId ->
            val views =
                RemoteViews(context.packageName, R.layout.spending_widget).apply {
                    val pendingIntent =
                        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                    setOnClickPendingIntent(R.id.widget_container, pendingIntent)

                    val expense = widgetData.getString(KEY_EXPENSE_LABEL, null)
                    setTextViewText(R.id.widget_amount, expense ?: "Mở app để xem")

                    val updatedAt = widgetData.getString(KEY_UPDATED_AT_LABEL, null)
                    setTextViewText(
                        R.id.widget_updated_at,
                        if (updatedAt != null) "Cập nhật lúc $updatedAt" else "",
                    )
                }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

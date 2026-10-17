package club.onepercent.one_percent_club

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Home-screen widget: today's habits. Tapping a habit opens it in the app to log. */
class TodayWidget : HomeWidgetProvider() {
    private val rows = listOf(R.id.row0, R.id.row1, R.id.row2, R.id.row3, R.id.row4, R.id.row5)

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.today_widget).apply {
                setTextViewText(R.id.title, widgetData.getString("title", null) ?: "1% Club")
                setTextViewText(R.id.subtitle, widgetData.getString("subtitle", null) ?: "Open the app to load today")
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("onepercent://today")),
                )
                val count = widgetData.getInt("count", 0)
                rows.forEachIndexed { i, row ->
                    if (i < count) {
                        setViewVisibility(row, View.VISIBLE)
                        setTextViewText(row, widgetData.getString("row$i", ""))
                        val habit = Uri.encode(widgetData.getString("habit$i", ""))
                        setOnClickPendingIntent(
                            row,
                            HomeWidgetLaunchIntent.getActivity(
                                context, MainActivity::class.java, Uri.parse("onepercent://log?habit=$habit"),
                            ),
                        )
                    } else {
                        setViewVisibility(row, View.GONE)
                    }
                }
                val more = widgetData.getString("more", null)
                setViewVisibility(R.id.more, if (more.isNullOrEmpty()) View.GONE else View.VISIBLE)
                setTextViewText(R.id.more, more ?: "")
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}

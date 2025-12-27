SELECT
    year,
    month,
    SUM(revenue) as total
FROM {DATABASE}.daily_revenue
GROUP BY year, month
ORDER BY year DESC, month DESC
LIMIT 5;
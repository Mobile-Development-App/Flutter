// ─────────────────────────────────────────────
// API Constants
// Backend: Firebase Cloud Functions (us-central1)
// ─────────────────────────────────────────────
const String kApiBaseUrl =
    'https://us-central1-inventaria-app-ae5ce.cloudfunctions.net/api';

// Auth
const String kAuthLogin    = '/auth/login';
const String kAuthRegister = '/auth/register';
const String kAuthLogout   = '/auth/logout';
const String kAuthMe       = '/auth/me';

// Products
const String kProducts     = '/products';

// Alerts
const String kAlerts       = '/alerts';
const String kAlertsSummary = '/alerts/summary';

// Analytics
const String kAnalyticsDashboard   = '/analytics/dashboard';
const String kAnalyticsSalesTrend  = '/analytics/sales-trend';
const String kAnalyticsStockCat    = '/analytics/stock-by-category';
const String kAnalyticsCategoryDist = '/analytics/category-distribution';

// Inventory movements
const String kInventoryMovements = '/inventory/movements';
const String kInventoryAdjust    = '/inventory/adjust';

// Restock
const String kRestockSuggestions = '/restock/suggestions';

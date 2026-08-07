# Centralized employee app

Flutter app for MultiCRM employees. Pick a **company** on login, then all API calls use that company's base URL.

## Setup

```bash
cd centralized_app
cp .env.example .env   # if needed
flutter pub get
flutter run
```

Edit `.env` for local/production API hosts (same values as each web CRM `VITE_API_URL`).

## Structure

| Path | Role |
|------|------|
| `.env` | Base URLs + socket host |
| `lib/config/` | Env + company registry |
| `lib/api/*_api.dart` | Per-company API modules (mirrors web `src/api/axios.js`) |
| `lib/api/api_client.dart` | Shared HTTP client |
| `lib/screens/login_screen.dart` | Compact company + login UI |
| `lib/auth/auth_session.dart` | Selected company + session |

## Companies

- Sales Tech Reality → `SALES_TECH_REALITY_API_URL`
- Bangar Properties → `BANGAR_PROPERTIES_API_URL`
- Maha Properties → `MAHA_PROPERTIES_API_URL`
- Ads Research Global → `ADS_RESEARCH_GLOBAL_API_URL`

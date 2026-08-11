import 'package:flutter/material.dart';
import 'app_env.dart';

enum CompanyId {
  salesTechReality,
  bangarProperties,
  mahaProperties,
  adsResearchGlobal,
}

/// Company metadata + logo styling + base URL (from `.env`, mirrors each web CRM).
class CompanyConfig {
  const CompanyConfig({
    required this.id,
    required this.key,
    required this.displayName,
    required this.shortName,
    required this.envUrlKey,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.tagline,
    required this.logoAsset,
  });
  // Duplicate constructor removed


  final CompanyId id;
  final String key;
  final String displayName;
  final String shortName;
  final String envUrlKey;

  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final String tagline;
  final String logoAsset;

  String get apiBaseUrl => AppEnv.require(envUrlKey);

  static const List<CompanyConfig> all = [
    CompanyConfig(
        id: CompanyId.salesTechReality,
        key: 'salesTechReality',
        displayName: 'Sales Tech Reality',
        shortName: 'STR',
        envUrlKey: 'SALES_TECH_REALITY_API_URL',
        icon: Icons.space_dashboard_rounded,
        primaryColor: Color(0xFF3B82F6),
        secondaryColor: Color(0xFF4F46E5),
        tagline: 'Sales & CRM Intelligence',
        logoAsset: 'assets/str.jpg',
      ),
    CompanyConfig(
        id: CompanyId.bangarProperties,
        key: 'bangarProperties',
        displayName: 'Bangar Properties',
        shortName: 'Bangar',
        envUrlKey: 'BANGAR_PROPERTIES_API_URL',
        icon: Icons.apartment_rounded,
        primaryColor: Color(0xFFF59E0B),
        secondaryColor: Color(0xFFD97706),
        tagline: 'Premium Real Estate Solutions',
        logoAsset: 'assets/bangar.jpg',
      ),
    CompanyConfig(
        id: CompanyId.mahaProperties,
        key: 'mahaProperties',
        displayName: 'Maha Properties',
        shortName: 'Maha',
        envUrlKey: 'MAHA_PROPERTIES_API_URL',
        icon: Icons.home_work_rounded,
        primaryColor: Color(0xFF10B981),
        secondaryColor: Color(0xFF059669),
        tagline: 'Housing & Commercial Realty',
        logoAsset: 'assets/mahaProperties.png',
      ),
    CompanyConfig(
        id: CompanyId.adsResearchGlobal,
        key: 'adsResearchGlobal',
        displayName: 'Ads Research Global',
        shortName: 'ARG',
        envUrlKey: 'ADS_RESEARCH_GLOBAL_API_URL',
        icon: Icons.campaign_rounded,
        primaryColor: Color(0xFF06B6D4),
        secondaryColor: Color(0xFF8B5CF6),
        tagline: 'Global Advertising & Research',
        logoAsset: 'assets/ads.jpg',
      ),
  ];

  static CompanyConfig? byKey(String? key) {
    if (key == null || key.isEmpty) return null;
    for (final c in all) {
      if (c.key == key) return c;
    }
    return null;
  }

  static CompanyConfig? byId(CompanyId id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// Reusable Company Logo Widget
class CompanyLogoWidget extends StatelessWidget {
  const CompanyLogoWidget({
    super.key,
    required this.company,
    this.size = 36,
    this.showTagline = false,
  });

  final CompanyConfig company;
  final double size;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    // If a logo asset is provided, display it; otherwise fall back to gradient icon.
    if (company.logoAsset.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.28),
          boxShadow: [
            BoxShadow(
              color: company.primaryColor.withAlpha(80),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.28),
          child: Image.asset(
            company.logoAsset,
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        ),
      );
    }
    final iconSize = size * 0.55;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [company.primaryColor, company.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: company.primaryColor.withAlpha(80),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          company.icon,
          size: iconSize,
          color: Colors.white,
        ),
      ),
    );
  }
}

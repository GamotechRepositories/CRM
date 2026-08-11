import 'package:flutter/material.dart';

class EmailMarketingPage extends StatefulWidget {
  const EmailMarketingPage({super.key});

  @override
  State<EmailMarketingPage> createState() => _EmailMarketingPageState();
}

class _EmailMarketingPageState extends State<EmailMarketingPage> {
  final List<Map<String, dynamic>> _campaigns = [
    {
      'id': '1',
      'subject': 'Monthly Newsletter - February 2026',
      'audience': 'All Subscribed Clients (1,240 recipients)',
      'status': 'Sent',
      'openRate': '42.8%',
      'clickRate': '18.5%',
      'sentDate': 'Feb 5, 2026',
    },
    {
      'id': '2',
      'subject': 'Product Launch & Exclusive Offer',
      'audience': 'VIP Leads & Prospects (450 recipients)',
      'status': 'Scheduled',
      'openRate': '—',
      'clickRate': '—',
      'sentDate': 'Feb 15, 2026',
    },
    {
      'id': '3',
      'subject': 'Re-engagement Survey',
      'audience': 'Inactive Contacts (820 recipients)',
      'status': 'Draft',
      'openRate': '—',
      'clickRate': '—',
      'sentDate': '—',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Email Marketing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              onPressed: () => _showComposeModal(context),
              icon: const Icon(Icons.email_outlined, size: 16),
              label: const Text('Compose Email', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stat Cards
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Total Emails Sent',
                    value: '12,480',
                    subtitle: 'Avg Open Rate: 41.2%',
                    icon: Icons.mark_email_read,
                    iconBg: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    title: 'Click-Through Rate',
                    value: '16.8%',
                    subtitle: 'High engagement',
                    icon: Icons.ads_click,
                    iconBg: const Color(0xFFECFDF5),
                    iconColor: const Color(0xFF059669),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            const Text('Email Broadcast Campaigns', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 10),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _campaigns.length,
              separatorBuilder: (_, index) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final item = _campaigns[idx];
                final status = item['status'] as String;
                final isSent = status == 'Sent';

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(item['subject'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSent ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSent ? const Color(0xFF047857) : const Color(0xFF1D4ED8))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(item['audience'] as String, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      const Divider(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Open Rate: ${item['openRate']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                          Text('Click Rate: ${item['clickRate']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
                          Text('Date: ${item['sentDate']}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showComposeModal(BuildContext context) {
    final subjCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Compose Broadcast Email', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Divider(),
            TextField(controller: subjCtrl, decoration: const InputDecoration(labelText: 'Subject Line *', isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: bodyCtrl, maxLines: 4, decoration: const InputDecoration(labelText: 'Email Body Content', isDense: true)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (subjCtrl.text.trim().isEmpty) return;
                  setState(() {
                    _campaigns.insert(0, {
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      'subject': subjCtrl.text.trim(),
                      'audience': 'Selected Client Group',
                      'status': 'Sent',
                      'openRate': '0.0%',
                      'clickRate': '0.0%',
                      'sentDate': 'Just Now',
                    });
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Broadcast email dispatched!')));
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                child: const Text('Send Broadcast'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

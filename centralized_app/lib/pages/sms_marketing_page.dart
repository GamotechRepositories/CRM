import 'package:flutter/material.dart';

class SmsMarketingPage extends StatefulWidget {
  const SmsMarketingPage({super.key});

  @override
  State<SmsMarketingPage> createState() => _SmsMarketingPageState();
}

class _SmsMarketingPageState extends State<SmsMarketingPage> {
  final List<Map<String, dynamic>> _smsLogs = [
    {
      'id': '1',
      'senderId': 'TXTBOX',
      'templateId': 'DLT-10042',
      'message': 'Dear Client, your site visit appointment is confirmed for tomorrow 11 AM.',
      'recipients': 350,
      'status': 'Delivered',
      'date': 'Feb 8, 2026',
    },
    {
      'id': '2',
      'senderId': 'CRMIND',
      'templateId': 'DLT-10088',
      'message': 'Special 10% discount on new commercial booking valid till Feb 28.',
      'recipients': 1200,
      'status': 'Delivered',
      'date': 'Feb 1, 2026',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('SMS Blast & DLT Templates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              onPressed: () => _showSendSmsModal(context),
              icon: const Icon(Icons.sms, size: 16),
              label: const Text('Send SMS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
                    title: 'SMS Sent',
                    value: '14,250',
                    subtitle: 'DLT Compliant',
                    icon: Icons.textsms,
                    iconBg: const Color(0xFFECFDF5),
                    iconColor: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    title: 'Delivery Rate',
                    value: '98.4%',
                    subtitle: 'Instant Delivery',
                    icon: Icons.check_circle,
                    iconBg: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            const Text('SMS Broadcast History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 10),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _smsLogs.length,
              separatorBuilder: (_, index) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final item = _smsLogs[idx];
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Sender: ${item['senderId']} (${item['templateId']})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12)),
                            child: Text(item['status'] as String, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(item['message'] as String, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Recipients: ${item['recipients']} contacts', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          Text(item['date'] as String, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
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

  void _showSendSmsModal(BuildContext context) {
    final msgCtrl = TextEditingController();

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
                const Text('Send DLT SMS Blast', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Divider(),
            TextField(controller: msgCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'SMS Content (DLT Approved)', isDense: true)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (msgCtrl.text.trim().isEmpty) return;
                  setState(() {
                    _smsLogs.insert(0, {
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      'senderId': 'CRMIND',
                      'templateId': 'DLT-CUSTOM',
                      'message': msgCtrl.text.trim(),
                      'recipients': 150,
                      'status': 'Delivered',
                      'date': 'Just Now',
                    });
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SMS Blast Sent!')));
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                child: const Text('Dispatch SMS'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

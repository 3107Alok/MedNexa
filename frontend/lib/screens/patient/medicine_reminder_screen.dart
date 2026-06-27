import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/services/notification_service.dart';
import 'package:frontend/services/reminder_service.dart';

import 'package:provider/provider.dart';
import 'package:frontend/services/auth_provider.dart';

class MedicineReminderScreen extends StatefulWidget {
  const MedicineReminderScreen({super.key});

  @override
  State<MedicineReminderScreen> createState() => _MedicineReminderScreenState();
}

class _MedicineReminderScreenState extends State<MedicineReminderScreen> {
  List<dynamic> _reminders = [];
  final TextEditingController _nameController = TextEditingController();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final ReminderService _reminderService = ReminderService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReminders();
  }

  Future<void> _fetchReminders() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    try {
      final reminders = await _reminderService.getUserReminders(user.uid);
      setState(() {
        _reminders = reminders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _addReminder() async {
    if (_nameController.text.isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    final now = DateTime.now();
    final reminderTime = DateTime(now.year, now.month, now.day, _selectedTime.hour, _selectedTime.minute);
    
    // If time is in the past, schedule for tomorrow
    final scheduledTime = reminderTime.isBefore(now) ? reminderTime.add(const Duration(days: 1)) : reminderTime;

    final reminderData = {
      "uid": user.uid,
      "medicine_name": _nameController.text,
      "time": _selectedTime.format(context),
    };

    try {
      await _reminderService.saveReminder(reminderData);
      
      NotificationService.scheduleNotification(
        _reminders.length + 1,
        'Medicine Reminder',
        'Time to take your ${_nameController.text}',
        scheduledTime,
      );

      _fetchReminders(); // Refresh list
      _nameController.clear();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save reminder')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medicine Reminders')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _reminders.isEmpty
          ? const Center(child: Text('No reminders set.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _reminders.length,
              itemBuilder: (context, index) {
                final r = _reminders[index];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.medication)),
                    title: Text(r['medicine_name'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    subtitle: Text('Scheduled for ${r['time']}'),
                    trailing: const Icon(Icons.notifications_active, color: Colors.orange),
                  ),
                );
              },
            ),
    );
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add New Reminder', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Medicine Name', prefixIcon: Icon(Icons.medication)),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Reminder Time'),
              trailing: Text(_selectedTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: () async {
                final picked = await showTimePicker(context: context, initialTime: _selectedTime);
                if (picked != null) setState(() => _selectedTime = picked);
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _addReminder, child: const Text('Save Reminder')),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

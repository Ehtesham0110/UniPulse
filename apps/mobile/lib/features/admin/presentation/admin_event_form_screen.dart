import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/gradient_button.dart';
import '../../events/application/event_providers.dart';
import '../../events/data/event_api.dart';
import '../../events/domain/event_summary.dart';

class AdminEventFormScreen extends ConsumerStatefulWidget {
  const AdminEventFormScreen({this.eventId, super.key});

  final String? eventId;

  @override
  ConsumerState<AdminEventFormScreen> createState() => _AdminEventFormScreenState();
}

class _AdminEventFormScreenState extends ConsumerState<AdminEventFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _venueController = TextEditingController();
  final _bannerUrlController = TextEditingController();
  final _priceController = TextEditingController();
  final _maxParticipantsController = TextEditingController();
  final _organizerNameController = TextEditingController();
  final _organizerContactController = TextEditingController();
  final _rulesController = TextEditingController();
  final _highlightsController = TextEditingController();

  String _category = 'Tech';
  String _eventType = 'Individual';
  bool _isPaid = false;
  DateTime _eventDate = DateTime.now().add(const Duration(days: 7));
  // ignore: prefer_final_fields  — mutated by the time-picker callbacks below
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  // ignore: prefer_final_fields
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);

  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    _bannerUrlController.dispose();
    _priceController.dispose();
    _maxParticipantsController.dispose();
    _organizerNameController.dispose();
    _organizerContactController.dispose();
    _rulesController.dispose();
    _highlightsController.dispose();
    super.dispose();
  }

  void _populateExisting(EventSummary event) {
    if (_isInitialized) return;
    _isInitialized = true;

    _titleController.text = event.title;
    _descriptionController.text = event.description;
    _venueController.text = event.venue;
    _bannerUrlController.text = event.bannerUrl ?? '';
    _category = event.category;
    _eventType = event.eventType;
    _isPaid = event.paid;
    _priceController.text = event.price > 0 ? event.price.toString() : '';
    _maxParticipantsController.text = event.maximumParticipants?.toString() ?? '';
    _organizerNameController.text = event.organizer.name ?? '';
    _organizerContactController.text = event.organizer.contactNumber ?? '';
    _rulesController.text = event.rules.join('\n');
    _highlightsController.text = event.highlights.join('\n');

    if (event.eventDate != null) {
      _eventDate = event.eventDate!;
    }
  }

  Future<void> _submit({required bool publish}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final rulesList = _rulesController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final highlightsList = _highlightsController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final payload = <String, dynamic>{
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'category': _category,
      'venue': _venueController.text.trim(),
      'eventDate': _eventDate.toIso8601String(),
      'startTime': '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
      'endTime': '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
      'eventType': _eventType,
      'paid': _isPaid,
      'price': _isPaid ? (int.tryParse(_priceController.text.trim()) ?? 0) : 0,
      'maximumParticipants': int.tryParse(_maxParticipantsController.text.trim()),
      if (_bannerUrlController.text.trim().isNotEmpty)
        'media': {'bannerUrl': _bannerUrlController.text.trim()},
      'organizer': {
        'name': _organizerNameController.text.trim(),
        'contactNumber': _organizerContactController.text.trim(),
      },
      'rules': rulesList,
      'highlights': highlightsList,
      'requiresApproval': !publish,
    };

    try {
      if (widget.eventId != null && widget.eventId!.isNotEmpty) {
        await ref.read(eventApiProvider).updateEvent(widget.eventId!, payload);
        if (publish) {
          await ref.read(eventApiProvider).approveEvent(widget.eventId!);
        }
      } else {
        final created = await ref.read(eventApiProvider).createEvent(payload);
        if (publish) {
          await ref.read(eventApiProvider).approveEvent(created.id);
        }
      }

      ref.invalidate(eventListProvider);
      if (widget.eventId != null) {
        ref.invalidate(eventDetailProvider(widget.eventId!));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(publish ? 'Event published successfully!' : 'Event saved as draft!'),
          backgroundColor: const Color(0xFF22A33A),
        ),
      );
      context.pop();
    } on EventApiException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (error) {
      setState(() => _errorMessage = 'Could not save event. Please check inputs.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.eventId != null && widget.eventId!.isNotEmpty;

    if (isEditing) {
      final existingAsync = ref.watch(eventDetailProvider(widget.eventId!));
      existingAsync.whenData(_populateExisting);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Event' : 'Create Event'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Basic Information'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _titleController,
                label: 'Event Title',
                validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 14),
              _buildTextField(
                controller: _descriptionController,
                label: 'Description',
                maxLines: 3,
                validator: (v) => v == null || v.trim().isEmpty ? 'Description is required' : null,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      label: 'Category',
                      value: _category,
                      items: const ['Tech', 'Non Tech'],
                      onChanged: (val) => setState(() => _category = val!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown(
                      label: 'Event Type',
                      value: _eventType,
                      items: const ['Individual', 'Team'],
                      onChanged: (val) => setState(() => _eventType = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Date & Venue'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _venueController,
                label: 'Venue',
                validator: (v) => v == null || v.trim().isEmpty ? 'Venue is required' : null,
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Event Date', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${_eventDate.day}/${_eventDate.month}/${_eventDate.year}'),
                trailing: const Icon(Icons.calendar_month_rounded, color: Color(0xFFFF5A1A)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _eventDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _eventDate = picked);
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Start Time', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(_startTime.format(context)),
                      trailing: const Icon(Icons.access_time_rounded, color: Color(0xFFFF5A1A)),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _startTime,
                        );
                        if (picked != null) setState(() => _startTime = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('End Time', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(_endTime.format(context)),
                      trailing: const Icon(Icons.access_time_filled_rounded, color: Color(0xFF3B82F6)),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _endTime,
                        );
                        if (picked != null) setState(() => _endTime = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Registration Details'),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Paid Registration', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(_isPaid ? 'Participants pay entry fee' : 'Free entry for all'),
                value: _isPaid,
                activeColor: const Color(0xFFFF5A1A),
                onChanged: (val) => setState(() => _isPaid = val),
              ),
              if (_isPaid) ...[
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _priceController,
                  label: 'Registration Fee (₹)',
                  keyboardType: TextInputType.number,
                  validator: (v) => _isPaid && (v == null || v.trim().isEmpty) ? 'Fee is required' : null,
                ),
              ],
              const SizedBox(height: 14),
              _buildTextField(
                controller: _maxParticipantsController,
                label: 'Maximum Participants (Optional)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Organizer & Contact'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _organizerNameController,
                      label: 'Organizer Name',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _organizerContactController,
                      label: 'Contact Number',
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Rules & Prize Details'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _rulesController,
                label: 'Event Rules (One per line)',
                maxLines: 3,
              ),
              const SizedBox(height: 14),
              _buildTextField(
                controller: _highlightsController,
                label: 'Prize Details & Highlights (One per line)',
                maxLines: 3,
              ),
              const SizedBox(height: 14),
              _buildTextField(
                controller: _bannerUrlController,
                label: 'Banner Image URL (Optional)',
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEAEA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFD32F2F)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Color(0xFFD32F2F)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => _submit(publish: false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Save Draft', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GradientButton(
                      label: _isLoading ? 'Saving…' : (isEditing ? 'Save Changes' : 'Publish Event'),
                      icon: Icons.check_circle_rounded,
                      onPressed: _isLoading ? () {} : () => _submit(publish: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE3E3EA)),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE3E3EA)),
        ),
      ),
    );
  }
}

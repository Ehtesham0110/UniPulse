import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../certificates/application/certificate_providers.dart';
import '../../certificates/data/certificate_api.dart';

/// Admin-facing certificate generation tools. There's no participant/
/// event picker UI yet (the Admin Panel is still mostly static/mock —
/// see AI_HANDOVER.md), so this pragmatically takes registration/event/
/// certificate ids directly rather than blocking on building a full
/// picker. The backend logic (eligibility, duplicate prevention,
/// explicit-confirm regeneration) is fully real either way.
class AdminCertificatesScreen extends ConsumerStatefulWidget {
  const AdminCertificatesScreen({super.key});

  @override
  ConsumerState<AdminCertificatesScreen> createState() => _AdminCertificatesScreenState();
}

class _AdminCertificatesScreenState extends ConsumerState<AdminCertificatesScreen> {
  final _registrationIdController = TextEditingController();
  final _eventIdController = TextEditingController();
  final _certificateIdController = TextEditingController();

  bool _isGeneratingSingle = false;
  bool _isBulkGenerating = false;
  bool _isRegenerating = false;
  BulkGenerateSummary? _lastBulkSummary;

  @override
  void dispose() {
    _registrationIdController.dispose();
    _eventIdController.dispose();
    _certificateIdController.dispose();
    super.dispose();
  }

  void _toast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFD32F2F) : const Color(0xFF22A33A),
      ),
    );
  }

  Future<void> _generateSingle() async {
    final registrationId = _registrationIdController.text.trim();
    if (registrationId.isEmpty) {
      _toast('Enter a registration ID', isError: true);
      return;
    }
    setState(() => _isGeneratingSingle = true);
    try {
      await ref.read(certificateApiProvider).generate(registrationId: registrationId);
      _toast('Certificate generated successfully');
      _registrationIdController.clear();
    } on CertificateApiException catch (error) {
      _toast(error.message, isError: true);
    } catch (_) {
      _toast('Something went wrong. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isGeneratingSingle = false);
    }
  }

  Future<void> _bulkGenerate() async {
    final eventId = _eventIdController.text.trim();
    if (eventId.isEmpty) {
      _toast('Enter an event ID', isError: true);
      return;
    }
    setState(() {
      _isBulkGenerating = true;
      _lastBulkSummary = null;
    });
    try {
      final summary = await ref.read(certificateApiProvider).bulkGenerate(eventId: eventId);
      setState(() => _lastBulkSummary = summary);
      _toast('Generated ${summary.generatedCount} of ${summary.totalEligible} certificates');
    } on CertificateApiException catch (error) {
      _toast(error.message, isError: true);
    } catch (_) {
      _toast('Something went wrong. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isBulkGenerating = false);
    }
  }

  Future<void> _regenerate() async {
    final certificateId = _certificateIdController.text.trim();
    if (certificateId.isEmpty) {
      _toast('Enter a certificate ID', isError: true);
      return;
    }

    // "Regenerate only if explicitly allowed" — require an explicit
    // confirmation dialog on top of the backend's own confirm:true guard.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate this certificate?'),
        content: const Text(
          'This replaces the existing PDF with a freshly generated one. '
          'The certificate number stays the same.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isRegenerating = true);
    try {
      await ref.read(certificateApiProvider).regenerate(certificateId);
      _toast('Certificate regenerated successfully');
      _certificateIdController.clear();
    } on CertificateApiException catch (error) {
      _toast(error.message, isError: true);
    } catch (_) {
      _toast('Something went wrong. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isRegenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Certificates')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Section(
            title: 'Generate for one student',
            subtitle:
                'Issues a certificate for a single registration. The student must have '
                'attended and the event must be marked Completed.',
            child: Column(
              children: [
                TextField(
                  controller: _registrationIdController,
                  decoration: const InputDecoration(
                    labelText: 'Registration ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isGeneratingSingle ? null : _generateSingle,
                    icon: _isGeneratingSingle
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.workspace_premium_outlined),
                    label: Text(_isGeneratingSingle ? 'Generating…' : 'Generate Certificate'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _Section(
            title: 'Bulk generate for an event',
            subtitle:
                'Issues certificates for every attended registration in a completed event. '
                'Students who already have one are skipped automatically.',
            child: Column(
              children: [
                TextField(
                  controller: _eventIdController,
                  decoration: const InputDecoration(
                    labelText: 'Event ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isBulkGenerating ? null : _bulkGenerate,
                    icon: _isBulkGenerating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.groups_outlined),
                    label: Text(_isBulkGenerating ? 'Generating…' : 'Bulk Generate'),
                  ),
                ),
                if (_lastBulkSummary != null) ...[
                  const SizedBox(height: 16),
                  _BulkSummaryCard(summary: _lastBulkSummary!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          _Section(
            title: 'Regenerate a certificate',
            subtitle:
                'Re-renders the PDF for an already-issued certificate (e.g. after fixing a '
                'name). Requires explicit confirmation and does not create a duplicate.',
            child: Column(
              children: [
                TextField(
                  controller: _certificateIdController,
                  decoration: const InputDecoration(
                    labelText: 'Certificate ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isRegenerating ? null : _regenerate,
                    icon: _isRegenerating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(_isRegenerating ? 'Regenerating…' : 'Regenerate'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDEDF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Color(0xFF696C7E), fontSize: 13)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _BulkSummaryCard extends StatelessWidget {
  const _BulkSummaryCard({required this.summary});

  final BulkGenerateSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Generated ${summary.generatedCount} of ${summary.totalEligible} eligible certificates',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (summary.skipped.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Skipped: ${summary.skipped.length} (${summary.skipped.toSet().join(', ')})',
              style: const TextStyle(color: Color(0xFF696C7E), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

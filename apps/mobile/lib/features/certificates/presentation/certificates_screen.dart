import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/date_formatting.dart';
import '../../auth/application/auth_controller.dart';
import '../application/certificate_providers.dart';
import '../data/certificate_api.dart';
import '../domain/earned_certificate.dart';

class CertificatesScreen extends ConsumerWidget {
  const CertificatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certificatesAsync = ref.watch(myCertificatesProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => ref.read(myCertificatesProvider.notifier).refresh(),
        child: certificatesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 80),
              const Icon(Icons.error_outline, size: 56, color: Color(0xFF9295A4)),
              const SizedBox(height: 12),
              const Text(
                'Could not load your certificates',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                error is CertificateApiException ? error.message : 'Pull down to try again.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF696C7E)),
              ),
            ],
          ),
          data: (certificates) {
            if (certificates.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 100),
                  Icon(Icons.workspace_premium_outlined, size: 56, color: Color(0xFF9295A4)),
                  SizedBox(height: 12),
                  Center(
                    child: Text(
                      'No certificates yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Attend an event and your certificate will show up here once it\'s issued.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF696C7E)),
                    ),
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.all(22),
              children: [
                const Center(
                  child: Text(
                    'Certificates',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 24),
                for (final certificate in certificates) ...[
                  _CertificateCard(certificate: certificate),
                  const SizedBox(height: 14),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CertificateCard extends ConsumerStatefulWidget {
  const _CertificateCard({required this.certificate});

  final EarnedCertificate certificate;

  @override
  ConsumerState<_CertificateCard> createState() => _CertificateCardState();
}

class _CertificateCardState extends ConsumerState<_CertificateCard> {
  bool _isOpening = false;

  Future<void> _open({required bool download}) async {
    setState(() => _isOpening = true);
    try {
      final accessToken = await ref.read(secureTokenStorageProvider).readAccessToken();
      if (accessToken == null) throw CertificateApiException('You need to be logged in.');

      // The download endpoint (Content-Disposition: attachment) and the
      // view endpoint (inline) are both served from the same relative
      // pdfPath — the certificate model stores the download path, so we
      // swap the suffix for the "View" action.
      final path = download
          ? widget.certificate.pdfPath
          : widget.certificate.pdfPath.replaceFirst('/download', '/view');
      final url = buildCertificateExternalUrl(path, accessToken);

      final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the certificate. Please try again.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is CertificateApiException ? error.message : 'Could not open the certificate.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isOpening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final certificate = widget.certificate;
    final issuedLabel = formatEventDate(certificate.issuedAt);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFF6B1A), size: 42),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      certificate.eventTitle,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Issued $issuedLabel',
                      style: const TextStyle(color: Color(0xFF696C7E), fontSize: 13),
                    ),
                    Text(
                      certificate.certificateNumber,
                      style: const TextStyle(color: Color(0xFF9295A4), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_isOpening)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CertActionButton(
                  icon: Icons.visibility_outlined,
                  label: 'View',
                  onTap: () => _open(download: false),
                ),
                _CertActionButton(
                  icon: Icons.download_rounded,
                  label: 'Download',
                  onTap: () => _open(download: true),
                ),
                _CertActionButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  onTap: () => _open(download: false),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CertActionButton extends StatelessWidget {
  const _CertActionButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF4C4F61)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF4C4F61))),
          ],
        ),
      ),
    );
  }
}

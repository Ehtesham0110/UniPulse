import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import PDFDocument from 'pdfkit';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
// apps/backend/storage/certificates — a simple local-disk abstraction.
// Swapping this for Cloudinary/S3 later only requires changing this one
// module (writeCertificatePdf + the two streaming reads in the
// controller), not the generation/validation logic around it.
export const CERTIFICATE_STORAGE_DIR = path.resolve(__dirname, '../../../storage/certificates');

function ensureStorageDir() {
  fs.mkdirSync(CERTIFICATE_STORAGE_DIR, { recursive: true });
}

/**
 * Renders a simple, readable certificate PDF to local disk and returns
 * its absolute file path. Uses a template's `name`/`backgroundUrl` for
 * light customization when provided, but never depends on network access
 * (no remote image fetching) so certificate generation can't fail because
 * of an unreachable template asset.
 */
export function writeCertificatePdf({
  certificateNumber,
  studentName,
  eventTitle,
  collegeName,
  issuedAt,
  templateName,
}) {
  ensureStorageDir();
  const filePath = path.join(CERTIFICATE_STORAGE_DIR, `${certificateNumber}.pdf`);

  const doc = new PDFDocument({ size: 'A4', layout: 'landscape', margin: 50 });
  const stream = fs.createWriteStream(filePath);
  doc.pipe(stream);

  doc
    .rect(20, 20, doc.page.width - 40, doc.page.height - 40)
    .lineWidth(2)
    .strokeColor('#FF6B1A')
    .stroke();

  doc
    .fontSize(12)
    .fillColor('#696C7E')
    .text((collegeName ?? 'UniPulse').toUpperCase(), 0, 70, { align: 'center' });

  doc
    .fontSize(30)
    .fillColor('#101223')
    .text(templateName ?? 'Certificate of Participation', 0, 100, { align: 'center' });

  doc
    .fontSize(14)
    .fillColor('#696C7E')
    .text('This certificate is proudly presented to', 0, 170, { align: 'center' });

  doc
    .fontSize(28)
    .fillColor('#FF6B1A')
    .text(studentName, 0, 205, { align: 'center' });

  doc
    .fontSize(14)
    .fillColor('#696C7E')
    .text(`for participating in "${eventTitle}"`, 0, 255, { align: 'center' });

  const issuedDateLabel = issuedAt.toLocaleDateString('en-IN', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  });
  doc.fontSize(11).text(`Issued on ${issuedDateLabel}`, 0, 300, { align: 'center' });
  doc.fontSize(10).text(`Certificate No. ${certificateNumber}`, 0, doc.page.height - 70, {
    align: 'center',
  });

  doc.end();

  return new Promise((resolve, reject) => {
    stream.on('finish', () => resolve(filePath));
    stream.on('error', reject);
  });
}

export function deleteCertificatePdf(filePath) {
  fs.rm(filePath, { force: true }, () => {});
}

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/features/telehealth/data/tele_dietetics_api.dart';

const _ghanaRegions = [
  'Greater Accra',
  'Ashanti',
  'Western',
  'Western North',
  'Central',
  'Eastern',
  'Volta',
  'Oti',
  'Northern',
  'Savannah',
  'North East',
  'Upper East',
  'Upper West',
  'Bono',
  'Bono East',
  'Ahafo',
];

/// In-app application to become a verified nutrition professional.
class DietitianApplicationScreen extends StatefulWidget {
  const DietitianApplicationScreen({super.key});

  @override
  State<DietitianApplicationScreen> createState() => _DietitianApplicationScreenState();
}

class _DietitianApplicationScreenState extends State<DietitianApplicationScreen> {
  final _api = TeleDieteticsApi();
  final _formKey = GlobalKey<FormState>();

  final _fullName = TextEditingController();
  final _age = TextEditingController();
  final _phone = TextEditingController();
  final _altPhone = TextEditingController();
  final _email = TextEditingController();
  final _ghanaCard = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _qualification = TextEditingController();
  final _institution = TextEditingController();
  final _experience = TextEditingController();
  final _license = TextEditingController();
  final _bio = TextEditingController();
  final _specialty = TextEditingController();
  final _category = TextEditingController();
  final _hourlyRate = TextEditingController();

  DateTime? _dob;
  String? _region;
  File? _certificate;
  File? _ghanaCardFile;
  File? _profilePhoto;
  File? _cv;

  DietitianApplicationDto? _existing;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fullName.dispose();
    _age.dispose();
    _phone.dispose();
    _altPhone.dispose();
    _email.dispose();
    _ghanaCard.dispose();
    _address.dispose();
    _city.dispose();
    _qualification.dispose();
    _institution.dispose();
    _experience.dispose();
    _license.dispose();
    _bio.dispose();
    _specialty.dispose();
    _category.dispose();
    _hourlyRate.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final app = await _api.fetchMyDietitianApplication();
      if (!mounted) return;
      if (app != null) {
        _prefill(app);
      }
      setState(() {
        _existing = app;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _prefill(DietitianApplicationDto app) {
    _fullName.text = app.fullName;
    if (app.age != null) _age.text = '${app.age}';
    _phone.text = app.phone ?? '';
    _altPhone.text = app.altPhone ?? '';
    _email.text = app.professionalEmail ?? '';
    _ghanaCard.text = app.ghanaCardNumber ?? '';
    _address.text = app.residentialAddress ?? '';
    _city.text = app.city ?? '';
    _region = app.region;
    _qualification.text = app.highestQualification ?? '';
    _institution.text = app.institution ?? '';
    if (app.yearsExperience != null) _experience.text = '${app.yearsExperience}';
    _license.text = app.licenseNumber ?? '';
    _bio.text = app.bio ?? '';
    _specialty.text = app.specialty ?? '';
    _category.text = app.category ?? '';
    if (app.hourlyRate != null) _hourlyRate.text = '${app.hourlyRate}';
    if (app.dateOfBirth != null) {
      _dob = DateTime.tryParse(app.dateOfBirth!);
    }
  }

  bool get _canEdit =>
      _existing == null || _existing!.status == 'rejected';

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 80),
      lastDate: DateTime(now.year - 18, now.month, now.day),
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _age.text = '${now.year - picked.year - ((now.month < picked.month || (now.month == picked.month && now.day < picked.day)) ? 1 : 0)}';
      });
    }
  }

  Future<void> _pickProfilePhotoFrom(ImageSource source) async {
    final x = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
      preferredCameraDevice: CameraDevice.front,
    );
    if (x != null && mounted) {
      setState(() => _profilePhoto = File(x.path));
    }
  }

  Future<void> _pickProfilePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    await _pickProfilePhotoFrom(source);
  }

  Future<void> _pickFile({
    required void Function(File f) onPicked,
    List<String>? extensions,
  }) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions ?? const ['jpg', 'jpeg', 'png'],
    );
    if (res != null && res.files.single.path != null) {
      onPicked(File(res.files.single.path!));
    }
  }

  Future<void> _submit() async {
    if (!_canEdit || _submitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your date of birth.')),
      );
      return;
    }
    if (_region == null || _region!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your region.')),
      );
      return;
    }
    if (_profilePhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a clear photo of yourself.')),
      );
      return;
    }
    if (_certificate == null || _ghanaCardFile == null || _cv == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload all required documents.')),
      );
      return;
    }
    if (_phone.text.trim() == _altPhone.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alternate phone must be different from your mobile number.')),
      );
      return;
    }

    setState(() => _submitting = true);
    final result = await _api.submitDietitianApplication(
      fullName: _fullName.text.trim(),
      dateOfBirth: _dob!,
      age: int.parse(_age.text.trim()),
      phone: _phone.text.trim(),
      altPhone: _altPhone.text.trim(),
      professionalEmail: _email.text.trim(),
      ghanaCardNumber: _ghanaCard.text.trim().toUpperCase(),
      residentialAddress: _address.text.trim(),
      city: _city.text.trim(),
      region: _region!,
      highestQualification: _qualification.text.trim(),
      institution: _institution.text.trim(),
      yearsExperience: int.parse(_experience.text.trim()),
      licenseNumber: _license.text.trim(),
      bio: _bio.text.trim(),
      specialty: _specialty.text.trim(),
      category: _category.text.trim(),
      hourlyRate: int.parse(_hourlyRate.text.trim()),
      certificate: _certificate!,
      ghanaCard: _ghanaCardFile!,
      profilePhoto: _profilePhoto!,
      cv: _cv!,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.ok) {
      setState(() => _existing = result.application);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Application saved securely. Your details and documents are stored on our servers for review.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF0FBD74);
    const bg = Color(0xFFF8FAFC);
    const text = Color(0xFF0F172A);
    const muted = Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: text,
        title: Text(
          'Become a dietitian',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                if (_existing != null) ...[
                  if (!_canEdit && (_existing!.imageUrl?.isNotEmpty == true))
                    Center(
                      child: CircleAvatar(
                        radius: 48,
                        backgroundImage: NetworkImage(_existing!.imageUrl!),
                      ),
                    ),
                  if (!_canEdit && (_existing!.imageUrl?.isNotEmpty == true))
                    const SizedBox(height: 12),
                  _statusBanner(_existing!),
                ],
                Text(
                  'All fields and documents are required. Approved professionals appear in Nutrition Advice.',
                  style: GoogleFonts.spaceGrotesk(fontSize: 13, color: muted, height: 1.4),
                ),
                const SizedBox(height: 16),
                if (_canEdit)
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _sectionTitle('Your photo'),
                        _profilePhotoSection(primary, muted),
                        const SizedBox(height: 8),
                        _sectionTitle('Personal details'),
                        _field(_fullName, 'Full legal name', required: true),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            _dob == null
                                ? 'Date of birth *'
                                : 'DOB: ${_dob!.toLocal().toString().split(' ').first}',
                            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
                          ),
                          trailing: const Icon(Icons.calendar_today_outlined),
                          onTap: _pickDob,
                        ),
                        _field(_age, 'Age', required: true, keyboard: TextInputType.number),
                        _sectionTitle('Contact'),
                        _field(_phone, 'Mobile number', required: true, keyboard: TextInputType.phone),
                        _field(_altPhone, 'Alternate phone', required: true, keyboard: TextInputType.phone),
                        _field(
                          _email,
                          'Professional email',
                          required: true,
                          keyboard: TextInputType.emailAddress,
                          isEmail: true,
                        ),
                        _sectionTitle('Identification & address'),
                        _field(_ghanaCard, 'Ghana card number (e.g. GHA-123456789-0)', required: true),
                        _field(_address, 'Residential address', required: true, maxLines: 2),
                        _field(_city, 'City / town', required: true),
                        DropdownButtonFormField<String>(
                          initialValue: _region,
                          decoration: _inputDeco('Region *'),
                          items: _ghanaRegions
                              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                              .toList(),
                          onChanged: (v) => setState(() => _region = v),
                          validator: (v) => v == null ? 'Select region' : null,
                        ),
                        const SizedBox(height: 12),
                        _sectionTitle('Education & experience'),
                        _field(_qualification, 'Highest qualification', required: true),
                        _field(_institution, 'Institution', required: true),
                        _field(_experience, 'Years of experience', required: true, keyboard: TextInputType.number),
                        _field(
                          _license,
                          'Professional license / registration no.',
                          required: true,
                          minLen: 3,
                        ),
                        _field(_bio, 'Professional summary', required: true, maxLines: 5, minLen: 80),
                        _sectionTitle('Practice profile'),
                        _field(_specialty, 'Specialty (e.g. Diabetes care)', required: true),
                        _field(_category, 'Category', required: true, hint: 'e.g. Clinical, Sports'),
                        _field(
                          _hourlyRate,
                          'Requested hourly rate (GHS)',
                          required: true,
                          keyboard: TextInputType.number,
                          hint: 'Admin sets the listed rate after review',
                        ),
                        _sectionTitle('Documents'),
                        _docTile(
                          label: 'Nutrition / dietetics certificate *',
                          file: _certificate,
                          onPick: () => _pickFile(
                            extensions: const ['pdf', 'jpg', 'jpeg', 'png'],
                            onPicked: (f) => setState(() => _certificate = f),
                          ),
                        ),
                        _docTile(
                          label: 'Ghana card (photo or PDF) *',
                          file: _ghanaCardFile,
                          onPick: () => _pickFile(
                            extensions: const ['pdf', 'jpg', 'jpeg', 'png'],
                            onPicked: (f) => setState(() => _ghanaCardFile = f),
                          ),
                        ),
                        _docTile(
                          label: 'CV / résumé (PDF) *',
                          file: _cv,
                          onPick: () async {
                            final res = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: const ['pdf'],
                            );
                            if (res?.files.single.path != null) {
                              setState(() => _cv = File(res!.files.single.path!));
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _submitting ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  'Submit application',
                                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _statusBanner(DietitianApplicationDto app) {
    Color bg;
    Color fg;
    String title;
    switch (app.status) {
      case 'approved':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF166534);
        title = 'Approved — you are listed as a nutrition professional.';
        break;
      case 'rejected':
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFF991B1B);
        title = 'Application rejected. Update your details and resubmit.';
        break;
      default:
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF1D4ED8);
        title = 'Application in review. We will notify you after verification.';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, color: fg)),
          if (app.reviewNotes != null && app.reviewNotes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(app.reviewNotes!, style: GoogleFonts.spaceGrotesk(fontSize: 12, color: fg)),
          ],
        ],
      ),
    );
  }

  Widget _profilePhotoSection(Color primary, Color muted) {
    final existingUrl = _existing?.imageUrl;
    final hasRemote = existingUrl != null && existingUrl.isNotEmpty && _profilePhoto == null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _profilePhoto == null && !hasRemote
              ? const Color(0xFFFECACA)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 56,
                backgroundColor: const Color(0xFFF1F5F9),
                backgroundImage: _profilePhoto != null
                    ? FileImage(_profilePhoto!)
                    : (hasRemote ? NetworkImage(existingUrl) : null),
                child: _profilePhoto == null && !hasRemote
                    ? Icon(Icons.person_outline, size: 48, color: muted)
                    : null,
              ),
              if (_canEdit)
                Material(
                  color: primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _pickProfilePhoto,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Upload a clear headshot of yourself *',
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Clients will see this on your Nutrition Advice profile. Face the camera, good lighting, no filters.',
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(fontSize: 12, color: muted, height: 1.35),
          ),
          if (_canEdit) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickProfilePhotoFrom(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Take photo'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickProfilePhotoFrom(ImageSource.gallery),
                    icon: const Icon(Icons.photo_outlined, size: 18),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            if (_profilePhoto != null)
              TextButton(
                onPressed: () => setState(() => _profilePhoto = null),
                child: Text(
                  'Remove photo',
                  style: GoogleFonts.spaceGrotesk(color: const Color(0xFFB91C1C)),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(t, style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w800)),
      );

  InputDecoration _inputDeco(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  Widget _field(
    TextEditingController c,
    String label, {
    bool required = false,
    int maxLines = 1,
    int? minLen,
    String? hint,
    TextInputType? keyboard,
    bool isEmail = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: _inputDeco(required ? '$label *' : label).copyWith(hintText: hint),
        validator: (v) {
          final t = (v ?? '').trim();
          if (required && t.isEmpty) return 'Required';
          if (minLen != null && t.length < minLen) return 'At least $minLen characters';
          if (isEmail && t.isNotEmpty) {
            final emailOk = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(t);
            if (!emailOk) return 'Enter a valid email';
          }
          return null;
        },
      ),
    );
  }

  Widget _docTile({
    required String label,
    required VoidCallback onPick,
    File? file,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text(
          file == null ? 'Not selected' : file.path.split(Platform.pathSeparator).last,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: OutlinedButton(onPressed: onPick, child: const Text('Upload')),
      ),
    );
  }
}

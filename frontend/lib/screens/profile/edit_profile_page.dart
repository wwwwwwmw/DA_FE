import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _contactCtrl;
  late TextEditingController _pinCtrl;
  String? _avatarDataUrl; // base64 image stored temporarily
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<ApiService>().currentUser!;
    _nameCtrl = TextEditingController(text: u.name);
    _contactCtrl = TextEditingController(text: u.contact ?? '');
    _pinCtrl = TextEditingController(text: u.employeePin ?? '');
    _avatarDataUrl = u.avatarUrl;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 600);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final b64 = base64Encode(bytes);
    setState(() {
      _avatarDataUrl = 'data:${file.mimeType};base64,$b64';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(()=> _saving = true);
    try {
      await context.read<ApiService>().updateProfile(
        name: _nameCtrl.text.trim(),
        contact: _contactCtrl.text.trim().isEmpty? null : _contactCtrl.text.trim(),
        employeePin: _pinCtrl.text.trim().isEmpty? null : _pinCtrl.text.trim(),
        avatarUrl: _avatarDataUrl,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lưu thất bại: $e')));
    } finally {
      if (mounted) setState(()=> _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
  final avatar = _avatarDataUrl;
    Uint8List? avatarBytes;
    if (avatar != null && avatar.startsWith('data:')) {
      final base64Part = avatar.split(',').last;
      try { avatarBytes = base64Decode(base64Part); } catch (_) {}
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa Hồ sơ')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 64,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    backgroundImage: avatarBytes != null ? MemoryImage(avatarBytes) : null,
                    child: avatarBytes == null ? Icon(Icons.camera_alt, size: 40, color: Theme.of(context).colorScheme.primary) : null,
                  ),
                ),
                const SizedBox(height: 24),
                _RoundedField(controller: _nameCtrl, label: 'Họ tên', validator: (v)=> v==null||v.isEmpty? 'Nhập họ tên': null, icon: Icons.badge),
                const SizedBox(height: 14),
                _RoundedField(controller: _contactCtrl, label: 'Liên hệ', icon: Icons.phone),
                const SizedBox(height: 14),
                _RoundedField(controller: _pinCtrl, label: 'Mã PIN nhân viên', icon: Icons.key),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _saving? null : _save, child: _saving? const CircularProgressIndicator() : const Text('Lưu')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundedField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final IconData? icon;
  const _RoundedField({required this.controller, required this.label, this.validator, this.icon});
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        prefixIcon: icon!=null? Icon(icon, color: Theme.of(context).colorScheme.primary): null,
        labelText: label,
        filled: true,
        fillColor: Theme.of(context).cardColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
      ),
    );
  }
}

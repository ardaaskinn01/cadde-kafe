import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';

class AddPersonnelView extends StatefulWidget {
  const AddPersonnelView({Key? key}) : super(key: key);

  @override
  State<AddPersonnelView> createState() => _AddPersonnelViewState();
}

class _AddPersonnelViewState extends State<AddPersonnelView> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController(); 
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  
  String _selectedRole = 'garson';
  bool _isLoading = false;

  void _createPersonnel() async {
    if (_nameController.text.isEmpty || _usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen tüm alanları doldurun.')));
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // Oluşturduğumuz AuthService içindeki addPersonnel metodunu kullanıyoruz
      await _authService.addPersonnel(
        username: _usernameController.text,
        password: _passwordController.text,
        fullName: _nameController.text,
        role: _selectedRole,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Personel başarıyla oluşturuldu!')),
        );
        Navigator.pop(context); // İşlem bitince geri dön
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personel Ekle'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'İsim Soyisim',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Kullanıcı Adı',
                suffixText: '@example.com',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Şifre',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Rol Seçimi',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'garson', child: Text('Garson')),
                DropdownMenuItem(value: 'kasa', child: Text('Kasa')),
                DropdownMenuItem(value: 'yonetici', child: Text('Yönetici')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedRole = val);
                }
              },
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading ? null : _createPersonnel,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isLoading 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Hesabı Oluştur', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

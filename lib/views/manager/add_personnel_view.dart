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
  
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  void _createPersonnel() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm alanları doldurunuz')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // Rolü varsayılan olarak 'garson' yapıyoruz
      await _authService.addPersonnel(
        username: username,
        password: password,
        fullName: name,
        role: 'garson',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Garson hesabı başarıyla oluşturuldu!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.contains('already exists')) {
          msg = 'Bu kullanıcı adı zaten kullanımda.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $msg'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.brown,
        title: const Text(
          'YENİ GARSON KAYDI',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            // İllüstrasyon veya Dekoratif Alan
            Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.brown.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                size: 60,
                color: Colors.brown,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Personel Bilgileri',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Oluşturulan hesap garson yetkisiyle açılacaktır.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 40),
            
            // İsim Soyisim Field
            _buildTextField(
              controller: _nameController,
              label: 'Adı Soyadı',
              icon: Icons.badge_outlined,
              hint: 'Örn: Ahmet Yılmaz',
            ),
            const SizedBox(height: 20),
            
            // Kullanıcı Adı Field
            _buildTextField(
              controller: _usernameController,
              label: 'Kullanıcı Adı',
              icon: Icons.alternate_email_rounded,
            ),
            const SizedBox(height: 20),
            
            // Şifre Field
            _buildTextField(
              controller: _passwordController,
              label: 'Şifre',
              icon: Icons.lock_open_rounded,
              hint: 'En az 6 karakter',
              isPassword: true,
              isPasswordVisible: _isPasswordVisible,
              onTogglePassword: () {
                setState(() => _isPasswordVisible = !_isPasswordVisible);
              },
            ),
            
            const SizedBox(height: 50),
            
            // Kaydet Butonu
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createPersonnel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 2,
                ),
                child: _isLoading 
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'HESABI OLUŞTUR',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Vazgeç',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? suffix,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onTogglePassword,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.brown,
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: isPassword && !isPasswordVisible,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(icon, color: Colors.brown, size: 22),
            suffixText: suffix,
            suffixStyle: TextStyle(color: Colors.grey.shade400),
            suffixIcon: isPassword ? IconButton(
              icon: Icon(
                isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey,
              ),
              onPressed: onTogglePassword,
            ) : null,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.grey.shade100),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.brown, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

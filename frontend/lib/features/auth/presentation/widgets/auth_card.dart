import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_state.dart';

class AuthCard extends StatelessWidget {
  final bool isLogin;
  final AuthState state;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final VoidCallback onToggle;

  const AuthCard({
    super.key,
    required this.isLogin,
    required this.state,
    required this.usernameController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.onLogin,
    required this.onRegister,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF6366F1); 

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isLogin ? "Welcome Back" : "Create Account",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isLogin ? "Good to see you again!" : "Join the conversation today.",
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 32),

              _buildTextField(
                controller: usernameController,
                hint: "Username",
                icon: Icons.alternate_email_rounded,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: passwordController,
                hint: "Password",
                icon: Icons.lock_outline_rounded,
                isPassword: true,
              ),

              if (!isLogin) ...[
                const SizedBox(height: 16),
                _buildTextField(
                  controller: confirmPasswordController,
                  hint: "Confirm Password",
                  icon: Icons.shield_outlined,
                  isPassword: true,
                ),
              ],

              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    state.error!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),

              const SizedBox(height: 32),

              state.isLoading
                  ? const CircularProgressIndicator(color: primaryColor)
                  : SizedBox(
                      width: double.infinity,
                      height: 56, 
                      child: ElevatedButton(
                        onPressed: isLogin ? onLogin : onRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          isLogin ? "Sign In" : "Get Started",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

              const SizedBox(height: 16),

              // 5. Subtle Toggle Button
              TextButton(
                onPressed: onToggle,
                style: TextButton.styleFrom(foregroundColor: Colors.grey[800]),
                child: Text(
                  isLogin ? "New here? Create account" : "Already have an account? Log in",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      
      style: const TextStyle(
        color: Color(0xFF1F2937), // Dark grey/black for visibility
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),

      cursorColor: const Color(0xFF6366F1),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[500]), // Clear hint text
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF6366F1)),
        filled: true,
        fillColor: Colors.grey[200]?.withOpacity(0.8), // Slightly darker fill
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../constants/auth_constants.dart';

class AuthTextField extends StatefulWidget {
  final String label;
  final String hintText;
  final IconData prefixIcon;
  final bool isPassword;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;

  const AuthTextField({
    super.key,
    required this.label,
    required this.hintText,
    required this.prefixIcon,
    this.isPassword = false,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.autofillHints,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _obscureText = true;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AuthConstants.textPrimary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Focus(
          onFocusChange: (hasFocus) {
            setState(() => _isFocused = hasFocus);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                AuthConstants.borderRadiusMedium,
              ),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: AuthConstants.primaryBlue.withValues(alpha: 0.1),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: TextFormField(
              controller: widget.controller,
              obscureText: widget.isPassword && _obscureText,
              keyboardType: widget.keyboardType,
              autofillHints: widget.autofillHints,
              validator: widget.validator,
              style: const TextStyle(color: AuthConstants.textPrimary),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: const TextStyle(color: Color(0xFFA0AEC0)),
                prefixIcon: Icon(
                  widget.prefixIcon,
                  color: AuthConstants.textSecondary,
                  size: 20,
                ),
                suffixIcon: widget.isPassword
                    ? IconButton(
                        icon: Icon(
                          _obscureText
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AuthConstants.textSecondary,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscureText = !_obscureText),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AuthConstants.borderRadiusMedium,
                  ),
                  borderSide: const BorderSide(
                    color: AuthConstants.fieldBorder,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AuthConstants.borderRadiusMedium,
                  ),
                  borderSide: const BorderSide(
                    color: AuthConstants.fieldBorder,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AuthConstants.borderRadiusMedium,
                  ),
                  borderSide: const BorderSide(
                    color: AuthConstants.primaryBlue,
                    width: 1.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AuthConstants.borderRadiusMedium,
                  ),
                  borderSide: const BorderSide(
                    color: Colors.redAccent,
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

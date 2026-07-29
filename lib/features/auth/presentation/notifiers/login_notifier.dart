import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../data/repositories/auth_repository.dart';

class LoginState {
  final bool isLoading;
  final String? emailError;
  final String? passwordError;
  final String? generalError;
  final bool staySignedIn;

  LoginState({
    this.isLoading = false,
    this.emailError,
    this.passwordError,
    this.generalError,
    this.staySignedIn = true,
  });

  LoginState copyWith({
    bool? isLoading,
    String? emailError,
    String? passwordError,
    String? generalError,
    bool? staySignedIn,
  }) {
    return LoginState(
      isLoading: isLoading ?? this.isLoading,
      emailError: emailError,
      passwordError: passwordError,
      generalError: generalError,
      staySignedIn: staySignedIn ?? this.staySignedIn,
    );
  }
}

class LoginNotifier extends ValueNotifier<LoginState> {
  LoginNotifier() : super(LoginState());

  void toggleStaySignedIn(bool? value) {
    this.value = this.value.copyWith(staySignedIn: value ?? false);
  }

  Future<bool> signIn(String email, String password) async {
    // Reset state
    value = value.copyWith(isLoading: true, generalError: null);

    // Basic Validation
    String? emailErr;
    String? passErr;
    bool hasError = false;

    if (email.isEmpty) {
      emailErr = 'Email Address is required';
      hasError = true;
    } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      emailErr = 'Please enter a valid email address';
      hasError = true;
    }

    if (password.isEmpty) {
      passErr = 'Password is required';
      hasError = true;
    }

    if (hasError) {
      value = value.copyWith(
        isLoading: false,
        emailError: emailErr,
        passwordError: passErr,
      );
      return false;
    }

    try {
      // Connects to live AuthRepository.login
      await AuthRepository.login(email, password);
      value = value.copyWith(isLoading: false);
      return true; // Success
    } on ApiException catch (e) {
      value = value.copyWith(isLoading: false, generalError: e.message);
      return false;
    } catch (e) {
      value = value.copyWith(
        isLoading: false,
        generalError: 'Failed to sign in. Please try again.',
      );
      return false;
    }
  }
}

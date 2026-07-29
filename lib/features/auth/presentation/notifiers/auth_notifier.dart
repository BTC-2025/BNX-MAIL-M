import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/token_service.dart';

class AuthState {
  final bool isLoggedIn;

  AuthState({this.isLoggedIn = false}); // Changed to false by default

  AuthState copyWith({bool? isLoggedIn}) {
    return AuthState(isLoggedIn: isLoggedIn ?? this.isLoggedIn);
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState());

  void login() {
    state = state.copyWith(isLoggedIn: true);
  }

  Future<void> logout() async {
    await TokenService.clearAll();
    state = state.copyWith(isLoggedIn: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectionStateData {
  final List<String> availableUsers;
  final List<String> connectedUsers;
  final List<String> blockedUsers;

  ConnectionStateData({
    required this.availableUsers,
    required this.connectedUsers,
    required this.blockedUsers,
  });

  ConnectionStateData copyWith({
    List<String>? availableUsers,
    List<String>? connectedUsers,
    List<String>? blockedUsers,
  }) {
    return ConnectionStateData(
      availableUsers: availableUsers ?? this.availableUsers,
      connectedUsers: connectedUsers ?? this.connectedUsers,
      blockedUsers: blockedUsers ?? this.blockedUsers,
    );
  }
}

class ConnectionNotifier extends StateNotifier<ConnectionStateData> {
  ConnectionNotifier()
    : super(
        ConnectionStateData(
          availableUsers: const [],
          connectedUsers: const [],
          blockedUsers: const [],
        ),
      );

  void connect(String username) {
    state = state.copyWith(
      availableUsers: state.availableUsers.where((u) => u != username).toList(),
      connectedUsers: [...state.connectedUsers, username],
    );
  }

  void disconnect(String username) {
    state = state.copyWith(
      connectedUsers: state.connectedUsers.where((u) => u != username).toList(),
      availableUsers: [...state.availableUsers, username],
    );
  }

  void block(String username) {
    state = state.copyWith(
      availableUsers: state.availableUsers.where((u) => u != username).toList(),
      connectedUsers: state.connectedUsers.where((u) => u != username).toList(),
      blockedUsers: [...state.blockedUsers, username],
    );
  }

  void unblock(String username) {
    state = state.copyWith(
      blockedUsers: state.blockedUsers.where((u) => u != username).toList(),
      availableUsers: [...state.availableUsers, username],
    );
  }
}

final connectionProvider =
    StateNotifierProvider<ConnectionNotifier, ConnectionStateData>((ref) {
      return ConnectionNotifier();
    });

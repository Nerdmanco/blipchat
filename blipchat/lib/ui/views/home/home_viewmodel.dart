import 'dart:async';
import 'package:flutter/material.dart';
import 'package:blipchat/app/app.locator.dart';
import 'package:blipchat/models/message.dart';
import 'package:blipchat/services/ble_service.dart';
import 'package:stacked/stacked.dart';

class HomeViewModel extends BaseViewModel {
  final _bleService = locator<BleService>();
  final TextEditingController _messageController = TextEditingController();
  
  StreamSubscription? _messageSubscription;
  StreamSubscription? _connectionSubscription;
  
  bool _isConnected = false;
  List<Message> _messages = [];

  // Getters
  String get username => _bleService.deviceUsername;
  bool get isConnected => _isConnected;
  TextEditingController get messageController => _messageController;
  List<Message> get messages => _messages;
  
  Stream<List<Message>> get messagesStream => _bleService.messageStream.map((newMessage) {
    if (!_messages.any((msg) => msg.id == newMessage.id)) {
      _messages.add(newMessage);
      rebuildUi();
    }
    return List.from(_messages);
  });

  HomeViewModel() {
    _initializeStreams();
  }

  void _initializeStreams() {
    // Listen to connection status changes
    _connectionSubscription = _bleService.connectionStatusStream.listen((connected) {
      _isConnected = connected;
      rebuildUi();
    });

    // Listen to incoming messages
    _messageSubscription = _bleService.messageStream.listen((message) {
      if (!_messages.any((msg) => msg.id == message.id)) {
        _messages.add(message);
        rebuildUi();
      }
    });

    // Initialize with current state
    _isConnected = _bleService.isActive;
    _messages = List.from(_bleService.messages);
  }

  Future<void> toggleConnection() async {
    setBusy(true);
    
    try {
      final newState = await _bleService.toggleConnection();
      _isConnected = newState;
      
      if (newState) {
        // Connection activated
        print("BLE connection activated for user: ${_bleService.deviceUsername}");
      } else {
        // Connection deactivated
        print("BLE connection deactivated");
      }
    } catch (e) {
      print("Error toggling BLE connection: $e");
      // You could show a dialog here to inform the user of the error
    } finally {
      setBusy(false);
      rebuildUi();
    }
  }

  Future<void> sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    try {
      await _bleService.sendMessage(messageText);
      _messageController.clear();
      
      // Scroll to bottom after sending message (if needed)
      // This would be handled in the UI layer
    } catch (e) {
      print("Error sending message: $e");
      // You could show an error dialog here
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }
}

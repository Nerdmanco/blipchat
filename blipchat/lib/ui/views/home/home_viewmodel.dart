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
  Timer? _periodicRefreshTimer;
  
  bool _isConnected = false;
  List<Message> _messages = [];

  // Getters
  String get username => _bleService.deviceUsername;
  bool get isConnected => _isConnected;
  TextEditingController get messageController => _messageController;
  List<Message> get messages => _messages;
  
  Stream<List<Message>> get messagesStream => _bleService.messageStream.map((newMessage) {
    print("Stream received message: ${newMessage.username}: ${newMessage.content}");
    if (!_messages.any((msg) => msg.id == newMessage.id)) {
      _messages.add(newMessage);
      print("Added to UI list. Total messages: ${_messages.length}");
      // Sort messages by timestamp to maintain chronological order
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      rebuildUi();
    } else {
      print("Message already exists in list");
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

    // Start periodic refresh timer (every 10 seconds)
    _startPeriodicRefresh();

    // Initialize with current state
    _isConnected = _bleService.isActive;
    _messages = List.from(_bleService.messages);
  }

  void _startPeriodicRefresh() {
    _periodicRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _refreshMessageList();
    });
  }

  void _refreshMessageList() {
    print("Periodic refresh: Syncing message list with BLE service");
    final bleMessages = _bleService.messages;
    bool hasNewMessages = false;

    // Check for new messages from BLE service
    for (final bleMessage in bleMessages) {
      if (!_messages.any((msg) => msg.id == bleMessage.id)) {
        _messages.add(bleMessage);
        hasNewMessages = true;
        print("Added missed message during refresh: ${bleMessage.username}: ${bleMessage.content}");
      }
    }

    // Remove messages that no longer exist in BLE service (cleanup)
    _messages.removeWhere((msg) => !bleMessages.any((bleMsg) => bleMsg.id == msg.id));

    // Sort messages by timestamp to maintain order
    _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (hasNewMessages || _messages.length != bleMessages.length) {
      print("Message list updated during refresh. UI messages: ${_messages.length}, BLE messages: ${bleMessages.length}");
      rebuildUi();
    }
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
      
      // Refresh message list after sending to ensure it appears
      _refreshMessageList();
      
      // Scroll to bottom after sending message (if needed)
      // This would be handled in the UI layer
    } catch (e) {
      print("Error sending message: $e");
      // You could show an error dialog here
    }
  }

  // Manual refresh method for UI triggers
  void refreshMessages() {
    _refreshMessageList();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    _periodicRefreshTimer?.cancel();
    super.dispose();
  }
}

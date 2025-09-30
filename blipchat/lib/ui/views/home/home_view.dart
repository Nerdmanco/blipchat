import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:blipchat/ui/common/app_colors.dart';
import 'package:blipchat/ui/common/sci_fi_widgets.dart';
import 'package:blipchat/models/message.dart';

import 'home_viewmodel.dart';

class HomeView extends StackedView<HomeViewModel> {
  const HomeView({Key? key}) : super(key: key);

  @override
  Widget builder(BuildContext context, HomeViewModel viewModel, Widget? child) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kcBackgroundColor, kcSurfaceColor],
          ),
        ),
        child: Column(
          children: [
            // Custom App Bar
            SciFiAppBar(
              username: viewModel.username,
              isConnected: viewModel.isConnected,
              onToggleConnection: viewModel.toggleConnection,
            ),
            
            // Messages List
            Expanded(
              child: StreamBuilder<List<Message>>(
                stream: viewModel.messagesStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bluetooth_searching,
                            size: 64,
                            color: kcTextMuted.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No messages yet...',
                            style: TextStyle(
                              color: kcTextMuted.withOpacity(0.7),
                              fontSize: 16,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            viewModel.isConnected 
                                ? 'Waiting for messages...'
                                : 'Turn on BLE to start chatting',
                            style: TextStyle(
                              color: kcTextMuted.withOpacity(0.5),
                              fontSize: 14,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  final messages = snapshot.data!;
                  return ListView.builder(
                    reverse: true,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[messages.length - 1 - index];
                      return MessageBubble(
                        username: message.username,
                        content: message.content,
                        timestamp: message.timestamp,
                        isLocal: message.isLocal,
                      );
                    },
                  );
                },
              ),
            ),
            
            // Message Input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    kcGradientEnd.withOpacity(0.8),
                    kcGradientStart.withOpacity(0.9),
                  ],
                ),
              ),
              child: SciFiTextField(
                controller: viewModel.messageController,
                hintText: 'Type your message...',
                onSubmitted: (value) => viewModel.sendMessage(),
                onSuffixPressed: viewModel.sendMessage,
                suffixIcon: Icons.send,
                glowColor: kcPrimaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  HomeViewModel viewModelBuilder(BuildContext context) => HomeViewModel();
}

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shimmer-скелетон для списка чатов.
class ChatListSkeleton extends StatelessWidget {
  const ChatListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHighest,
      highlightColor: scheme.surfaceContainerHigh,
      child: ListView.builder(
        itemCount: 8,
        itemBuilder: (BuildContext _, int __) => ListTile(
          leading: const CircleAvatar(radius: 26),
          title: Container(height: 12, color: Colors.white),
          subtitle: Container(
            margin: const EdgeInsets.only(top: 8),
            height: 10,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

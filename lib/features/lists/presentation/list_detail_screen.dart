import 'package:flutter/material.dart';

class ListDetailScreen extends StatelessWidget {
  const ListDetailScreen({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('List Detail')),
      body: Center(
        child: Text('List detail placeholder for $listId'),
      ),
    );
  }
}

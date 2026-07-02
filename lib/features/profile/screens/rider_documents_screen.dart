import 'package:flutter/material.dart';

class RiderDocumentsScreen extends StatelessWidget {
  const RiderDocumentsScreen({
    super.key,
  });

  Widget tile(String title) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: ElevatedButton(
          onPressed: () {},
          child: const Text('Upload'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          tile('National ID'),
          tile('Driving License'),
          tile('Insurance'),
          tile('Profile Photo'),
        ],
      ),
    );
  }
}

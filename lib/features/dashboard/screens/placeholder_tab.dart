import 'package:flutter/material.dart';

import 'package:secondary_sales/core/widgets/ss_ui.dart';

class PlaceholderTab extends StatelessWidget {
  const PlaceholderTab({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          BlueHeader(title: title, subtitle: 'Coming soon'),
          const Expanded(child: Center(child: Text('No data'))),
        ],
      ),
    );
  }
}

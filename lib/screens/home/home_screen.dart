import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../room_screen.dart';

class HomeScreen extends StatelessWidget {
  final bool isOwner;

  const HomeScreen({super.key, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(
      isOwner ? AppLanguage.german : AppLanguage.russian,
    );

    return Scaffold(
      appBar: AppBar(title: Text(strings.appTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _hotelCard(
            context,
            title: strings.mainHotel,
            subtitle: strings.rooms1to10,
            area: 'mainHotel',
            color: Colors.blue,
          ),
          const SizedBox(height: 12),
          _hotelCard(
            context,
            title: strings.basement,
            subtitle: strings.rooms1to5,
            area: 'basement',
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _hotelCard(
            context,
            title: strings.apartment,
            subtitle: strings.guestApartment,
            area: 'apartment',
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _hotelCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String area,
    required Color color,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: const Icon(Icons.hotel, color: Colors.white),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  RoomScreen(area: area, title: title, isOwner: isOwner),
            ),
          );
        },
      ),
    );
  }
}

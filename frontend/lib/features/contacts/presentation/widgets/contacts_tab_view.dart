import 'package:flutter/material.dart';
import 'package:my_chat_app/features/contacts/presentation/widgets/contact_list.dart';
import 'package:my_chat_app/features/contacts/presentation/widgets/blocked_list.dart';

class ContactsTabView extends StatelessWidget {
  final TabController tabController;

  const ContactsTabView({super.key, required this.tabController});

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      controller: tabController,
      children: const [
        ContactsList(),
        BlockedList(),
      ],
    );
  }
}
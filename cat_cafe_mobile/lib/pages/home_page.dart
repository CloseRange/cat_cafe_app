import 'package:cat_cafe_mobile/pages/cats/cat_list_page.dart';
import 'package:cat_cafe_mobile/pages/settings/settings_page.dart';
import 'package:cat_cafe_mobile/pages/shifts/shift_page.dart';
import 'package:close_range_util/close_range_util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    CRRole.reload();
    return CRScrollPage(
      pages: [CRMoneyCounterScreen(), CatListPage(), ShiftListPage(), SettingsPage()],
      icons: const [
        CupertinoIcons.money_dollar_circle_fill,
        Icons.pets,
        CupertinoIcons.doc_person_fill,
        CupertinoIcons.settings_solid
      ],
      labels: const ["Money Counter", "Cat Photos", "Shifts", "Settings"],
    );
  }
}

// void showSimpleSuccess(BuildContext context, String message) {
//   ScaffoldMessenger.of(context).showSnackBar(
//     SnackBar(
//       content: Text(message),
//       behavior: SnackBarBehavior.floating,
//       backgroundColor: Theme.of(context).colorScheme.primary,
//       duration: const Duration(seconds: 2),
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//       ),
//     ),
//   );
// }
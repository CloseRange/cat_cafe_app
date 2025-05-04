import 'package:cat_cafe_mobile/pages/settings/manage_employees_page.dart';
import 'package:cat_cafe_mobile/pages/settings/profile_page.dart';
import 'package:cat_cafe_mobile/pages/settings/store_settings_page.dart';
import 'package:close_range_util/close_range_util.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  SettingsItem profile(BuildContext context) {
    return SettingsItem(
      accessKey: null,
      title: CRUser.current?.fullName ?? "Unknown User",
      subtitle: CRUser.current?.data["role"] ?? "Unknown Role",
      enabled: true,
      titleRatio: 4,
      leading: CRProfilePicture(user: CRUser.current, size: 75),
      group: "",
      breakOnGroup: false,
      showGroupBackground: false,
      size: 75,
      titleSize: 20,
      onTap: (_) {
        pageGoto(context, const ProfilePage());
      },
      builder: (key, item) {
        return const Icon(Icons.arrow_forward_ios);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var managerStuff = _managerItems(context);
    return CRRole.bind(builder: (context) {
      return CRSettings(
        backButton: false,
        popout: true,
        children: [
          profile(context),
          CRSettings.group("Layout"),
          CRSettings.colorTheme(context),
          CRSettings.darkMode(context),
          if(managerStuff.isNotEmpty) ...[
            CRSettings.group("Manager Settings"),
            ...managerStuff,
          ],
          if (CRRole.hasRole("master")) ...[
            CRSettings.group("Owner Settings"),
            CRSettings.navigation(context,
                location: const CRModifyRolesPage(),
                title: 'Permissions',
                icon: Icons.security,
                description: 'Modify permissions'),
            CRSettings.navigation(context,
                location: const StoreSettingsPage(),
                title: 'Store Settings',
                icon: Icons.store,
                description: 'Modify Store Info'),
          ],
          CRSettings.group("User Settings"),
          CRSettings.action(context, title: "Change password", onTap: () {
            attemptPasswordReset(context);
          }),
          CRSettings.action(context, title: "Reload Roles", onTap: () async {
            CRRole.reload();
          }),
          CRSettings.logout(context)
        ],
      );
    });
  }

  List<SettingsItem> _managerItems(BuildContext context) {
    return [
      if(CRRole.hasRole("edit_employees"))
        CRSettings.navigation(context, title: "Edit Employees",
            icon: Icons.person_add,
          location: const ManageEmployeesPage())
    ];
  }
}

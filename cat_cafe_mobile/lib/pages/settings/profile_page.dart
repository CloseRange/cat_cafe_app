import 'package:flutter/cupertino.dart';
import 'package:close_range_util/close_range_util.dart';
import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    return CRAppBar(
      title: "Profile",
      backButton: true,
      scrollable: false,
      surfaceVarient: true,
      child: CRRefreshPage(
        onRefresh: () async {
          await CRUser.current?.reload();
          CRUser.current?.reloadPfp();
          if (mounted) setState(() {});
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              // 👤 Profile Picture
              Center(
                child: CRProfileBanner(
                  profile: CRUser.current!,
                  description: "Testing 123",
                  onEdit: () => CRProfilePicture.editProfilePicture(context),
                  links: [
                    Icon(CupertinoIcons.person),
                    Icon(CupertinoIcons.phone_down),
                    Icon(CupertinoIcons.person),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 👤 Basic Info
              CRRegion(
                child: Column(
                  children: [
                    CRForm.action(
                      context,
                      title: "Name",
                      description: CRUser.current?.fullName ?? "Unknown",
                      enabled: false,
                    ),
                    CRForm.action(
                      context,
                      title: "Phone",
                      description: CRUser.current?.phonenumber ?? "N/A",
                      enabled: false,
                    ),
                    CRForm.action(
                      context,
                      title: "Role",
                      description: CRRole.roleTitle,
                      enabled: false,
                    ),
                    CRForm.action(
                      context,
                      title: "Start Date",
                      description: "",//formatDate(CRUser.current?.createdAt),
                      enabled: false,
                    ),
                  ],
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  String formatDate(DateTime? date) {
    if (date == null) return "Unknown";
    return "${date.month}/${date.day}/${date.year}";
  }
}

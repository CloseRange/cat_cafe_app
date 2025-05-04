// ignore_for_file: use_build_context_synchronously

import 'package:cat_cafe_mobile/pages/square/square_utility.dart';
import 'package:close_range_util/close_range_util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ManageEmployeesPage extends StatefulWidget {
  const ManageEmployeesPage({super.key});

  @override
  State<ManageEmployeesPage> createState() => _ManageEmployeesPageState();
}

class _ManageEmployeesPageState extends State<ManageEmployeesPage> {
  List<Map<String, dynamic>> employees = [];
  List<Map<String, dynamic>> allRoles = [];
  String search = "";
  bool loading = true;
  int currentUserRoleLevel = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => loading = true);
    final userResp = await CRDatabase.client
        .from('profiles')
        .select('user_id, first_name, last_name, role, store')
        .eq('store', 1111)
        .order('last_name');

    final rolesResp = await CRDatabase.client
        .from('roles')
        .select('name, level')
        .order('level');

    final currentUserRole = CRUser.current?.data['role'];
    final currentLevel = rolesResp.firstWhere(
      (r) => r['name'] == currentUserRole,
      orElse: () => {'level': 0},
    )['level'] as int;

    setState(() {
      employees = List<Map<String, dynamic>>.from(userResp);
      allRoles = List<Map<String, dynamic>>.from(rolesResp);
      currentUserRoleLevel = currentLevel;
      loading = false;
    });
  }

  Future<void> _updateRole(String userId, String? newRole) async {
    await CRDatabase.client
        .from('profiles')
        .update({'role': newRole}).eq('user_id', userId);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return CRAppBar(
      title: "Manage Employees",
      scrollable: false,
      backButton: true,
      surfaceVarient: true,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          var res = await _showEmployeeAddModal(context, 1111);
          if (res == true) {
            // Reload the data after adding a new employee
            _loadData();
          }
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        shape: const CircleBorder(),
        child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary), // This forces a perfect circle
      ),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: "Search by name",
                    ),
                    onChanged: (value) => setState(() => search = value),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: employees.where((emp) {
                      final fullName =
                          "${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}"
                              .toLowerCase();
                      return fullName.contains(search.toLowerCase());
                    }).map((emp) {
                      final name =
                          "${emp['last_name'] ?? ''}, ${emp['first_name'] ?? ''}";
                      final currentRole = emp['role'] as String?;
                      final targetRole = allRoles.firstWhere(
                        (r) => r['name'] == currentRole,
                        orElse: () => {'level': 0},
                      );
                      final canEdit =
                          (targetRole['level'] ?? 0) <= currentUserRoleLevel;

                      return ListTile(
                        onTap: canEdit
                            ? () {
                                showEmployeeProfileDialog(
                                  context,
                                  emp,
                                  allRoles,
                                  currentUserRoleLevel,
                                  (newRole) {
                                    _updateRole(emp['user_id'],
                                        newRole == "" ? null : newRole);
                                  },
                                  () {
                                    _loadData();
                                  },
                                );
                              }
                            : null,
                        leading: SizedBox(
                          width: 40,
                          height: 40,
                          child: CRProfilePicture.fromId(
                            (emp['user_id']),
                            size: 40,
                          ),
                        ),
                        title: Text(name),
                        trailing: Text(currentRole ?? ""),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }
}

Future<void> showEmployeeProfileDialog(
  BuildContext context,
  Map<String, dynamic> employee,
  List<Map<String, dynamic>> allRoles,
  int currentUserLevel,
  Function(String) onRoleChanged,
  void Function() updateRole,
) async {
  String? selectedRole = employee['role'];

  final user = await CRUser.load(employee['user_id']);
  // final currentRoleLevel = allRoles.firstWhere(
  //   (r) => r['name'] == selectedRole,
  //   orElse: () => {'level': 0},
  // )['level'] as int;
  final editableRoles =
      allRoles.where((r) => (r['level'] as int) < currentUserLevel).toList();

  await showDialog(
    context: context,
    builder: (context) {
      final name =
          "${employee['first_name'] ?? ''} ${employee['last_name'] ?? ''}"
              .trim();

      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Employee Profile",
            style: Theme.of(context).textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CRProfilePicture(user: user, size: 75),
            const SizedBox(height: 12),
            Text(name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: "Role"),
              value: editableRoles.any((r) => r['name'] == selectedRole)
                  ? selectedRole
                  : null,
              items: editableRoles
                  .map<DropdownMenuItem<String>>((r) =>
                      DropdownMenuItem<String>(
                          value: r['name'], child: Text(r['name'])))
                  .toList(),
              onChanged: (val) => selectedRole = val,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever),
            label: const Text("Remove"),
            onPressed: () {
              onRoleChanged("");
              CRDatabase.client
                  .from('profiles')
                  .update({'store': null, 'role': null})
                  .eq('user_id', employee['user_id'])
                  .then((_) async {
                    updateRole();
                  });
              Navigator.pop(context);
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text("Save"),
            onPressed: () {
              if (selectedRole != null && selectedRole != employee['role']) {
                onRoleChanged(selectedRole!);
              }
              Navigator.pop(context);
            },
          ),
        ],
      );
    },
  );
}

Future<T?> showCustomModal<T>(
  BuildContext context, {
  required String title,
  Widget? action,
  bool backButton = false,
  required Widget Function(BuildContext) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, // ✅ Keyboard aware
        ),
        child: SingleChildScrollView(
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min, // ✅ Wrap content height
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: Theme.of(context).colorScheme.primary,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: backButton
                            ? IconButton(
                                icon: Icon(
                                  CupertinoIcons.chevron_back,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                                onPressed: () => Navigator.pop(context),
                              )
                            : const SizedBox.shrink(),
                      ),
                      const Expanded(child: SizedBox.shrink()),
                      Text(
                        title,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 20,
                        ),
                      ),
                      const Expanded(child: SizedBox.shrink()),
                      Expanded(child: action ?? const SizedBox.shrink()),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: builder(context),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<bool?> _showEmployeeAddModal(BuildContext context, int storeNumber) async {
  final phoneController = TextEditingController();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  return await showCustomModal(context, title: "Add Employee", backButton: true,
      action: Loader.bind(() {
    return Loader.isLoading
        ? const CircularProgressIndicator()
        : IconButton(
            icon: Icon(CupertinoIcons.floppy_disk,
                color: Theme.of(context).colorScheme.onPrimary),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              String? pn = verifyE164(phoneController.text);
              if (pn == null) {
                showSimpleError(context, "Invalid phone number");
                return;
              }

              try {
                Loader.load();
                final res = await CRDatabase.client
                    .from('profiles')
                    .select('user_id, store')
                    .eq('phone', pn.replaceAll("+", ""))
                    .maybeSingle();

                if (res == null || res['user_id'] == null) {
                  showSimpleError(context, "User not found");
                  Loader.unload();
                  return;
                }

                if (res['store'] == storeNumber) {
                  showSimpleError(
                      context, "User already assigned to this store");
                  Loader.unload();
                  return;
                }

                var valid = await SquareUtility.createTeamMember(
                  context,
                  firstName: firstNameController.text.trim(),
                  lastName: lastNameController.text.trim(),
                  phone: pn,
                  userId: res['user_id'],
                  storeNumber: storeNumber,
                );
                if (!valid) {
                  showSimpleError(context, "Failed to add employee");
                  Loader.unload();
                  return;
                }
                await CRDatabase.client.from('profiles').update({
                  'store': storeNumber,
                  'first_name': firstNameController.text.trim(),
                  'last_name': lastNameController.text.trim(),
                }).eq('user_id', res['user_id']);
                Loader.unload();

                showSimpleSuccess(context, "Employee added successfully");
                Navigator.pop(context, true);
              } catch (e) {
                Loader.unload();
                Debug.error("Failed to add employee", inner: e.toString());
                showSimpleError(context, "Something went wrong.");
              } finally {}
            },
          );
  }), builder: (context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: "Phone Number"),
            validator: (v) => verifyE164(v ?? "") == null
                ? "Enter a valid phone number"
                : null,
          ),
          TextFormField(
            controller: firstNameController,
            decoration: const InputDecoration(labelText: "First Name"),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? "Required" : null,
          ),
          TextFormField(
            controller: lastNameController,
            decoration: const InputDecoration(labelText: "Last Name"),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? "Required" : null,
          ),
        ],
      ),
    );
  });
}

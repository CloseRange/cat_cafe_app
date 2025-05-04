// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:close_range_util/close_range_util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CatListEditorPage extends StatefulWidget {
  const CatListEditorPage({super.key});

  @override
  State<CatListEditorPage> createState() => _CatListEditorPageState();
}

class _CatListEditorPageState extends State<CatListEditorPage> {
  List<Map<String, dynamic>> cats = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadCats();
  }

  Future<void> _loadCats() async {
    setState(() => loading = true);
    final response =
        await CRDatabase.client.from('cats').select().order('name');
    setState(() {
      cats = List<Map<String, dynamic>>.from(response);
      loading = false;
    });
  }

  void _openEditor([Map<String, dynamic>? cat]) async {
    showCatEditorModal(context, cat: cat).then((value) {
      if (value == true) {
        try {
          _loadCats();
        } catch (e) {
          Debug.error("Error loading cats: $e");
        }
      }
    });
  }

  Widget buildCatEditListPage(
      BuildContext context, List<Map<String, dynamic>> cats) {
    return ListView.builder(
      itemCount: cats.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final cat = cats[index];
        final name = cat['name'] ?? 'Unnamed';
        final adopted = cat['is_adopted'] == true;
        final photo = cat['photo_url'];

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 50,
                height: 50,
                child: CRImage.fromUrl(photo ?? "",
                    width: 50, height: 50, fit: BoxFit.cover),
              ),
            ),
            title:
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(adopted ? "Adopted" : "Available"),
            trailing: const Icon(Icons.edit),
            onTap: () => showCatEditorModal(context, cat: cat).then((v) {
              if (v == true) {
                try {
                  _loadCats();
                } catch (e) {
                  Debug.error("Error loading cats: $e");
                }
              }
            }),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CRAppBar(
      title: "Manage Cats",
      scrollable: false,
      surfaceVarient: true,
      backButton: true,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        backgroundColor: Theme.of(context).colorScheme.primary,
        shape: const CircleBorder(),
        child: Icon(Icons.add,
            color: Theme.of(context)
                .colorScheme
                .onPrimary), // This forces a perfect circle
        elevation: 6,
      ),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : CRRefreshPage(
              onRefresh: _loadCats,
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: buildCatEditListPage(context, cats)),
            ),
    );
  }
}

Widget _displayCatModalImage(
    BuildContext context, XFile? imageFile, String? existingPhotoUrl) {
  const double size = 120;
  Widget child = const SizedBox(height: size, width: size);
  CRImage? image;
  if (imageFile != null) {
    child = Image.file(File(imageFile.path), height: size);
    image = CRImage.fromFile(imageFile, height: size);
  } else if (existingPhotoUrl != null) {
    child = image = CRImage.fromUrl(existingPhotoUrl, height: size);
  } else {
    child = const Icon(Icons.pets, size: size);
  }
  return Center(
      child: SizedBox(
    height: size,
    width: size,
    child: GestureDetector(
        onTap: () {
          if (image != null) {
            showImageControl(context, image);
          }
        },
        child: child),
  ));
}


Future<bool?> showCatEditorModal(BuildContext context,
    {Map<String, dynamic>? cat}) async {
  final isEditing = cat != null;
  final nameController = TextEditingController(text: cat?['name'] ?? '');
  final breedController = TextEditingController(text: cat?['breed'] ?? '');
  final colorController = TextEditingController(text: cat?['color'] ?? '');
  final notesController = TextEditingController(text: cat?['notes'] ?? '');
  final birthday = ValueNotifier<DateTime?>(
      cat?['birthday'] != null ? DateTime.parse(cat!['birthday']) : null);
  final adopted = ValueNotifier<bool>(cat?['is_adopted'] ?? false);
  XFile? imageFile;
  String? existingPhotoUrl = cat?['photo_url'];
  
  return await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    // shape: const RoundedRectangleBorder(
    //   borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    // ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: 600,
          child: StatefulBuilder(builder: (context, setState) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    // height: 15,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    color: Theme.of(context).colorScheme.primary,
                    child: Center(
                      child: Text(isEditing ? "Edit Cat" : "Add Cat",
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 25)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left side: image and button
                      Column(
                        children: [
                          const SizedBox(height: 18),
                          _displayCatModalImage(
                              context, imageFile, existingPhotoUrl),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.image),
                            label: const Text("Choose Image"),
                            onPressed: () async {
                              final picked = await catImagePickerSheet(
                                context,
                                hasRemove: imageFile != null ||
                                    existingPhotoUrl != null,
                              );

                              if (picked != null) {
                                setState(() {
                                  imageFile = picked;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            TextField(
                              controller: nameController,
                              decoration:
                                  const InputDecoration(labelText: "Name"),
                            ),
                            TextField(
                              controller: breedController,
                              decoration:
                                  const InputDecoration(labelText: "Breed"),
                            ),
                            TextField(
                              controller: colorController,
                              decoration:
                                  const InputDecoration(labelText: "Color"),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Birthday Picker
                  ValueListenableBuilder<DateTime?>(
                    valueListenable: birthday,
                    builder: (_, date, __) => ListTile(
                      title: const Text("Birthday"),
                      subtitle: Text(date != null
                          ? DateFormat('yMMMd').format(date)
                          : "Select date"),
                      trailing: const Icon(Icons.cake),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: birthday.value ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) birthday.value = picked;
                      },
                    ),
                  ),

                  // Adopted Switch
                  SwitchListTile(
                    title: const Text("Adopted"),
                    value: adopted.value,
                    onChanged: (val) {
                      setState(() => adopted.value = val);
                    },
                  ),

                  const SizedBox(height: 20),

                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.save),
                          label: Text(isEditing ? "Update Cat" : "Add Cat"),
                          onPressed: () async {
                            final client = CRDatabase.client;
                            final data = {
                              'name': nameController.text.trim(),
                              'breed': breedController.text.trim(),
                              'color': colorController.text.trim(),
                              'notes': notesController.text.trim(),
                              'birthday': birthday.value?.toIso8601String(),
                              'is_adopted': adopted.value,
                              'store_id': CRUser.current?.data['store_id'],
                            };

                            dynamic id = cat?['id'];
                            if (isEditing) {
                              await client
                                  .from('cats')
                                  .update(data)
                                  .eq('id', id);
                            } else {
                              final inserted = await client
                                  .from('cats')
                                  .insert(data)
                                  .select()
                                  .single();
                              id = inserted['id'];
                            }

                            // Upload and link image
                            if (imageFile != null && id != null) {
                              const bucket = "cat-photos";
                              final fileName = "$id";
                              await CRDatabase.storage.from(bucket).upload(
                                    fileName,
                                    File(imageFile!.path),
                                    fileOptions:
                                        const FileOptions(upsert: true),
                                  );

                              final publicUrl = Supabase.instance.client.storage
                                  .from(bucket)
                                  .getPublicUrl(fileName);
                              await client.from('cats').update(
                                  {'photo_url': publicUrl}).eq('id', id);
                            }

                            Navigator.pop(context, true);
                          },
                        ),
                        if (isEditing)
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0),
                            child: Center(
                              child: OutlinedButton.icon(
                                icon: Icon(Icons.delete,
                                    color: Theme.of(context).colorScheme.error),
                                label: Text(
                                  "Delete Cat",
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color:
                                          Theme.of(context).colorScheme.error),
                                ),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text("Confirm Deletion"),
                                      content: const Text(
                                          "Are you sure you want to delete this cat? This action cannot be undone."),
                                      actions: [
                                        TextButton(
                                          child: const Text("Cancel"),
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                        ),
                                        TextButton(
                                          child: Text(
                                            "Delete",
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error),
                                          ),
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    await CRDatabase.client
                                        .from('cats')
                                        .delete()
                                        .eq('id', cat['id']);
                                    Navigator.pop(context,
                                        true); // Close the editor modal
                                  }
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            );
          }),
        ),
      );
    },
  );
}

Future<XFile?> catImagePickerSheet(BuildContext context,
    {bool hasRemove = false}) async {
  Widget button(
    IconData icon,
    String text,
    void Function() onPressed, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: 40,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Icon(
                    icon,
                    color: color ?? Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  text,
                  style: TextStyle(
                    color: color ?? Theme.of(context).colorScheme.onBackground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<XFile>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 5,
              width: 50,
              margin: const EdgeInsets.only(bottom: 10, top: 10),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).colorScheme.onBackground.withAlpha(150),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            button(CupertinoIcons.photo, "Choose from Gallery", () async {
              try {
                var img = await CRImagePicker.loadGallery();
                if (img == null) return;
                Navigator.pop(context, img);
              } catch (e) {
                Debug.error('Gallery upload failed', inner: e.toString());
                showSimpleError(context, "Upload failed.");
              }
            }),
            button(CupertinoIcons.camera, 'Take photo', () async {
              try {
                var img = await CRImagePicker.loadCamera();
                if (img == null) return;
                Navigator.pop(context, img);
              } catch (e) {
                Debug.error('Camera upload failed', inner: e.toString());
                showSimpleError(context, "Upload failed.");
              }
            }),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

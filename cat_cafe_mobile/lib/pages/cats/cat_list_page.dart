// ignore_for_file: use_build_context_synchronously

import 'package:cat_cafe_mobile/pages/cats/cat_list_editor_page.dart';
import 'package:close_range_util/close_range_util.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CatListPage extends StatefulWidget {
  const CatListPage({super.key});

  @override
  State<CatListPage> createState() => _CatListPageState();
}

class _CatListPageState extends State<CatListPage> {
  List<Map<String, dynamic>> cats = [];
  bool loading = true;
  Set<String> expandedCats = {};

  @override
  void initState() {
    super.initState();
    _loadCats();
  }

  Future<void> _loadCats() async {
    setState(() => loading = true);
    final response =
        await CRDatabase.client.from('cats').select().order('name');
        
      cats = List<Map<String, dynamic>>.from(response);
      loading = false;
      if(mounted) setState(() {});
  }


  @override
  Widget build(BuildContext context) {
    return CRRole.bind(builder: (context) {
      return CRAppBar(
        title: "Cats",
        scrollable: false,
        surfaceVarient: true,
        action: CRRole.hasRole("edit_cats")
            ? IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  pageGoto(context, const CatListEditorPage());
                },
              )
            : null,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : CRRefreshPage(
                onRefresh: _loadCats,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, // Number of columns
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 3 / 4, // Adjust card shape
                    ),
                    itemCount: cats.length,
                    itemBuilder: (context, index) {
                      final cat = cats[index];
                      final name = cat['name'] ?? 'Unnamed';
                      final adopted = cat['is_adopted'] == true;

                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: adopted
                              ? Theme.of(context)
                                  .colorScheme
                                  .error
                                  .withAlpha(50)
                              : Theme.of(context).colorScheme.surface,
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context)
                                  .colorScheme
                                  .shadow
                                  .withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: GestureDetector(
                          onTap: () {
                            showCatDetailsDialog(context, cat);
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12)),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  height: adopted ? 190 : 220, // or any value that looks good
                                  child: CRImage.fromSupabase(
                                    'cat-photos',
                                    cat['id'],
                                    heroTag: "cat-${cat['id']}",
                                    fit: BoxFit.cover,
                                    fallback: const Icon(Icons.pets, size: 80),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Center(
                                      child: Text(
                                        name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (adopted)
                                      const Center(
                                        child: Text(
                                          "Adopted",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
      );
    });
  }
}

Widget _infoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

Future<void> showCatDetailsDialog(
    BuildContext context, Map<String, dynamic> cat) async {
  final name = cat['name'] ?? 'Unnamed';
  final adopted = cat['is_adopted'] == true;
  final breed = cat['breed'] ?? 'Unknown';
  final color = cat['color'] ?? 'Unknown';
  final birthday = cat['birthday'] != null
      ? DateFormat.yMMMd().format(DateTime.parse(cat['birthday']))
      : 'Unknown';
  final notes = cat['notes'] ?? '';
  final store = cat['store_id'] ?? 'Unknown';
  final imageUrl = cat['photo_url'];
  final image = CRImage.fromSupabase(
    'cat-photos',
    cat['id'],
    heroTag: "cat-${cat['id']}",
    fit: BoxFit.cover,
    height: 200,
    fallback: const Icon(Icons.pets, size: 80),
  );

  await showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (imageUrl != null && imageUrl.toString().isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: image
                  )
                else const Icon(Icons.pets, size: 100),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  adopted ? "Adopted" : "Available",
                ),
                const Divider(height: 24),
                _infoRow("Breed", breed),
                _infoRow("Color", color),
                _infoRow("Birthday", birthday),
                _infoRow("Store", store),
                if (notes.isNotEmpty) ...[
                  const Divider(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Notes:",
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const SizedBox(height: 4),
                  Text(notes),
                ],
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text("Close"),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

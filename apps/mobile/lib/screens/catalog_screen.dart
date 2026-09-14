import "dart:convert";
import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";

class CatalogScreen extends StatefulWidget {
  final LocaleController localeController;
  final String userId;
  final bool isOwner;

  const CatalogScreen({
    super.key,
    required this.localeController,
    required this.userId,
    this.isOwner = false,
  });

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  bool loading = true;
  List<Map<String, dynamic>> products = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final response = await ApiClient.listCatalog(widget.userId);
    if (response.statusCode == 200) {
      products = List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> deleteProduct(String productId) async {
    await ApiClient.deleteProduct(productId);
    load();
  }

  Future<void> addProduct() async {
    final t = widget.localeController.t;
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final priceController = TextEditingController();
    final imageController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SyrixColors.surface,
        title: Text(t("catalog_new_product"), style: const TextStyle(color: SyrixColors.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: SyrixColors.textPrimary),
                decoration: InputDecoration(hintText: t("catalog_name_hint")),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                maxLines: 2,
                style: const TextStyle(color: SyrixColors.textPrimary),
                decoration: InputDecoration(hintText: t("catalog_description_hint")),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: SyrixColors.textPrimary),
                decoration: InputDecoration(hintText: t("catalog_price_hint")),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: imageController,
                style: const TextStyle(color: SyrixColors.textPrimary),
                decoration: InputDecoration(hintText: t("catalog_image_hint")),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t("profile_cancel"))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(t("contact_rename_save"))),
        ],
      ),
    );
    if (result != true || nameController.text.trim().isEmpty) return;
    await ApiClient.createProduct(
      name: nameController.text.trim(),
      description: descController.text.trim(),
      price: num.tryParse(priceController.text.trim()) ?? 0,
      imageUrl: imageController.text.trim().isEmpty ? null : imageController.text.trim(),
      launchDate: DateTime.now().toIso8601String(),
    );
    load();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    return Scaffold(
      backgroundColor: SyrixColors.background,
      appBar: AppBar(
        backgroundColor: SyrixColors.background,
        title: Text(t("catalog_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
        actions: [
          if (widget.isOwner)
            IconButton(icon: const Icon(Icons.add_rounded, color: SyrixColors.textPrimary), onPressed: addProduct),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: SyrixColors.primary))
          : products.isEmpty
              ? Center(child: Text(t("catalog_empty"), style: const TextStyle(color: SyrixColors.textMuted)))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: SyrixColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: SyrixColors.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: product["imageUrl"] != null
                                ? Image.network(product["imageUrl"], fit: BoxFit.cover, width: double.infinity)
                                : Container(
                                    color: SyrixColors.surfaceAlt,
                                    child: const Icon(Icons.shopping_bag_rounded, color: SyrixColors.textMuted, size: 32),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product["name"] ?? "",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: SyrixColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("${product["price"] ?? 0}", style: const TextStyle(color: SyrixColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                                    if (widget.isOwner)
                                      GestureDetector(
                                        onTap: () => deleteProduct(product["_id"]),
                                        child: const Icon(Icons.delete_outline_rounded, color: SyrixColors.danger, size: 16),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

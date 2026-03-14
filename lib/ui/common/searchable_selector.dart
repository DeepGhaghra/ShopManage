import 'package:flutter/material.dart';

class SearchableSelector extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final String labelKey;
  final IconData icon;
  final Color iconColor;
  final Function(dynamic) onSelected;

  const SearchableSelector({
    super.key,
    required this.title,
    required this.items,
    required this.labelKey,
    required this.icon,
    required this.iconColor,
    required this.onSelected,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required List<Map<String, dynamic>> items,
    required String labelKey,
    required IconData icon,
    required Color iconColor,
    required Function(dynamic) onSelected,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => SearchableSelector(
        title: title,
        items: items,
        labelKey: labelKey,
        icon: icon,
        iconColor: iconColor,
        onSelected: onSelected,
      ),
    );
  }

  @override
  State<SearchableSelector> createState() => _SearchableSelectorState();
}

class _SearchableSelectorState extends State<SearchableSelector> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items
        .where((i) => i[widget.labelKey]
            .toString()
            .toLowerCase()
            .contains(query.toLowerCase()))
        .toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(widget.title,
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: -0.3)),
          IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.pop(context)),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      content: SizedBox(
        width: 300,
        height: 260,
        child: Column(
          children: [
            TextField(
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Type to search...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (val) => setState(() => query = val),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text('No results found',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12)))
                  : ListView.builder(
                      itemCount: filtered.length,
                      padding: EdgeInsets.zero,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                color: widget.iconColor.withOpacity(0.1),
                                shape: BoxShape.circle),
                            child: Icon(widget.icon,
                                color: widget.iconColor, size: 14),
                          ),
                          title: Text(item[widget.labelKey],
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          onTap: () {
                            widget.onSelected(item['id']);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

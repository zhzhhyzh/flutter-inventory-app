import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'inventory_form_page.dart';

class InventoryListPage extends StatefulWidget {
  final List<Map<String, dynamic>> inventoryItems;

  const InventoryListPage({required this.inventoryItems});

  @override
  State<InventoryListPage> createState() => _InventoryListPageState();
}

class _InventoryListPageState extends State<InventoryListPage> {
  List<Map<String, dynamic>> _items = [];
  late Timer _timer;

  Future<void> _viewItem(Map<String, dynamic> item) async {
    final expiry = item['expiryDate'];
    final expiryDate =
        expiry is Timestamp
            ? expiry.toDate()
            : (expiry is DateTime ? expiry : DateTime.now());

    await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('Item Details'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Brand: ${item['brand']}'),
                Text('Function: ${item['function']}'),
                Text('Quantity: ${item['quantity']}'),
                Text(
                  'Expiry Date: ${expiryDate.day}-${expiryDate.month}-${expiryDate.year}',
                ),
                Text('Type: ${item['type']}'),
                Text('Remarks: ${item['remarks']}'),
                Text('Category: ${item['category']}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          ),
    );
  }

  Future<void> _editItem(Map<String, dynamic> item, int index) async {
    final updatedItem = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InventoryFormPage(mode: 'edit', initialData: item),
      ),
    );

    if (updatedItem != null && updatedItem is Map<String, dynamic>) {
      final docId = item['id'];
      if (docId != null) {
        await FirebaseFirestore.instance
            .collection('inventory')
            .doc(docId)
            .update(updatedItem);
        setState(() {
          _items[index] = updatedItem;
        });
      }
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('Confirm Deletion'),
            content: Text('Are you sure you want to delete this item?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      final docId = item['id'];
      if (docId != null) {
        await FirebaseFirestore.instance
            .collection('inventory')
            .doc(docId)
            .delete();
        setState(() {
          _items.removeAt(index);
        });
      }
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatCountdown(dynamic expiry) {
    if (expiry is! DateTime) return 'Invalid date';

    final now = DateTime.now();
    final difference = expiry.difference(now);

    if (difference.isNegative) return 'Expired';

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;
    final seconds = difference.inSeconds % 60;

    return '${days.toString().padLeft(2, '0')}:'
        '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _startCountdownTimer();
    _fetchItemsFromFirestore(
      category: _selectedCategory,
      type: _selectedType,
      expiryFrom: _expiryFrom,
      expiryTo: _expiryTo,
    );
  }

  void _startCountdownTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      setState(() {}); // Triggers UI rebuild to update countdowns
    });
  }

  DocumentSnapshot? _lastVisible;
  bool _isLoading = false;
  bool _hasMore = true;

  final int _limit = 20;

  Future<void> _fetchItemsFromFirestore({
    bool loadMore = false,
    String? category,
    String? type,
    DateTime? expiryFrom,
    DateTime? expiryTo,
  }) async {
    if (_isLoading || (!_hasMore && loadMore)) return;
    setState(() => _isLoading = true);

    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
        'inventory',
      );

      if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category.toLowerCase());
      }
      if (type != null && type.isNotEmpty) {
        query = query.where('type', isEqualTo: type.toLowerCase());
      }
      if (expiryFrom != null) {
        query = query.where('expiryDate', isGreaterThanOrEqualTo: expiryFrom);
      }
      if (expiryTo != null) {
        query = query.where('expiryDate', isLessThanOrEqualTo: expiryTo);
      }

      query = query.orderBy('expiryDate').limit(_limit);

      if (_lastVisible != null && loadMore) {
        query = query.startAfterDocument(_lastVisible!);
      }

      final snapshot = await query.get();
      final docs = snapshot.docs;

      if (!loadMore) _items.clear();

      if (docs.isNotEmpty) {
        _lastVisible = docs.last;
        final List<Map<String, dynamic>> loadedItems =
            docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;

              final expiry = data['expiryDate'];
              if (expiry is Timestamp) {
                data['expiryDate'] = expiry.toDate();
              }

              return data;
            }).toList();

        setState(() => _items.addAll(loadedItems));
      }

      if (docs.length < _limit) _hasMore = false;
    } catch (e) {
      print('Error loading inventory items: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _importCSV() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null) {
      final file = File(result.files.single.path!);
      final csvContent = await file.readAsString();
      final csvRows = CsvToListConverter().convert(csvContent, eol: '\n');

      final List<Map<String, dynamic>> data = [];

      for (int i = 1; i < csvRows.length; i++) {
        final row = csvRows[i];
        if (row.length < 7) continue;

        final parsedDate = _parseDate(row[3]);

        data.add({
          'brand': row[0].toString().trim(),
          'function': row[1]?.toString().trim() ?? '',
          'quantity': int.tryParse(row[2].toString()) ?? 0,
          'expiryDate': parsedDate ?? DateTime.now(),
          'type': row[4]?.toString().toLowerCase().trim() ?? '',
          'remarks': row[5]?.toString().trim() ?? '',
          'category': row[6]?.toString().toLowerCase().trim() ?? '',
          'imageUrl': '',
        });
      }

      for (final item in data) {
        await FirebaseFirestore.instance.collection('inventory').add(item);
      }

      await _fetchItemsFromFirestore();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV imported successfully!')));
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();

    // Handle formats like "2026-7-1" safely
    final parts = str.split('-');
    if (parts.length == 3) {
      try {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);

        if (year < 2000 || month > 12 || day > 31) return null;

        return DateTime(year, month, day);
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  Future<void> _navigateToCreate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InventoryFormPage(mode: 'create')),
    );

    if (result != null && result is Map<String, dynamic>) {
      await FirebaseFirestore.instance.collection('inventory').add(result);
      setState(() {
        _items.add(result);
      });
    }
  }

  final TextEditingController _brandFilter = TextEditingController();
  DateTime? _expiryFrom;
  DateTime? _expiryTo;
  String? _selectedCategory;
  String? _selectedType;

  final _categories = ['cosmetic', 'grocery', 'sample'];
  final _types = {
    'cosmetic': [
      'blush',
      'contour plate',
      'cushion',
      'eye brown',
      'eyeliner',
      'lip balm',
      'lip tint',
      'loose powder',
      'powder foundation',
    ],
    'grocery': [
      'body wash',
      'cream',
      'face cream',
      'face wash',
      'handcream',
      'mask',
      'scrub',
      'sunscreen',
      'toner',
      'toothpaste',
      '-',
    ],
    'sample': [
      'acne patch',
      'ampoule',
      'ampoule bottle',
      'body cream',
      'body lotion',
      'body wash',
      'clay',
      'clay mask',
      'cleansing balm',
      'cleansing oil',
      'conditioner',
      'cream',
      'cream before makeup',
      'eye cream',
      'eye mask',
      'face set',
      'face wash',
      'foot cream',
      'foundation',
      'full set',
      'gel',
      'hair care',
      'hand cream',
      'lip gloss',
      'lipbalm',
      'lipstick',
      'lotion',
      'makeup remover',
      'mask',
      'primer',
      'scrub',
      'scrum',
      'serum',
      'set',
      'shampoo',
      'shower oil',
      'sunscreen',
      'toner',
      'Toner & Serum',
    ],
  };

  List<Map<String, dynamic>> get _filteredItems {
    final brandSearch = _brandFilter.text.toLowerCase();
    return _items.where((item) {
      final brand = item['brand']?.toLowerCase() ?? '';
      return brandSearch.isEmpty || brand.contains(brandSearch);
    }).toList();
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inventory List'),
        actions: [
          IconButton(icon: Icon(Icons.add), onPressed: _navigateToCreate),
          IconButton(icon: Icon(Icons.file_upload), onPressed: _importCSV),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          if (!_isLoading &&
              _hasMore &&
              scrollInfo.metrics.pixels >=
                  scrollInfo.metrics.maxScrollExtent - 200) {
            _fetchItemsFromFirestore(loadMore: true);
          }
          return false;
        },
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _brandFilter,
                            decoration: InputDecoration(
                              labelText: 'Search Brand',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(

                          child: DropdownButtonFormField<String>(

                            value: _selectedCategory, isExpanded: true,
                            decoration: InputDecoration(labelText: 'Category'),
                            items:
                                _categories
                                    .map(
                                      (cat) => DropdownMenuItem(
                                        value: cat,
                                        child: Text(cat),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedCategory = val;
                                _selectedType = null;
                                _lastVisible = null;
                                _hasMore = true;
                              });
                              _fetchItemsFromFirestore(
                                category: _selectedCategory,
                                type: _selectedType,
                                expiryFrom: _expiryFrom,
                                expiryTo: _expiryTo,
                              );
                            },
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedType, isExpanded:true,
                            decoration: InputDecoration(labelText: 'Type'),
                            items:
                                (_selectedCategory != null &&
                                        _types[_selectedCategory!] != null)
                                    ? _types[_selectedCategory!]!.map((
                                      String value,
                                    ) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList()
                                    : [],
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedType = newValue;
                                _lastVisible = null;
                                _hasMore = true;
                              });
                              _fetchItemsFromFirestore(
                                category: _selectedCategory,
                                type: _selectedType,
                                expiryFrom: _expiryFrom,
                                expiryTo: _expiryTo,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            child: Text(
                              _expiryFrom == null
                                  ? 'Expiry From'
                                  : '${_expiryFrom!.month}-${_expiryFrom!.year}',
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _expiryFrom ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() => _expiryFrom = picked);
                                _lastVisible = null;
                                _hasMore = true;
                                _fetchItemsFromFirestore(
                                  category: _selectedCategory,
                                  type: _selectedType,
                                  expiryFrom: _expiryFrom,
                                  expiryTo: _expiryTo,
                                );
                              }

                            },
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            child: Text(
                              _expiryTo == null
                                  ? 'Expiry To'
                                  : '${_expiryTo!.month}-${_expiryTo!.year}',
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _expiryTo ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() => _expiryTo = picked);
                                _lastVisible = null;
                                _hasMore = true;
                                _fetchItemsFromFirestore(
                                  category: _selectedCategory,
                                  type: _selectedType,
                                  expiryFrom: _expiryFrom,
                                  expiryTo: _expiryTo,
                                );
                              }

                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _brandFilter.clear();
                                _selectedCategory = null;
                                _selectedType = null;
                                _expiryFrom = null;
                                _expiryTo = null;
                                _lastVisible = null;
                                _hasMore = true;
                              });
                              _fetchItemsFromFirestore();
                            }

                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Brand')),
                    DataColumn(label: Text('Quantity')),
                    DataColumn(label: Text('Expiry Date')),
                    DataColumn(label: Text('Category')),

                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Function')),

                    DataColumn(label: Text('Remarks')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: List<DataRow>.generate(_filteredItems.length, (index) {
                    final item = _filteredItems[index];
                    final expiry = item['expiryDate'];
                    final expiryDate =
                        expiry is Timestamp
                            ? expiry.toDate()
                            : (expiry is DateTime ? expiry : DateTime.now());

                    final isExpiringThisYear =
                        expiryDate.year == DateTime.now().year;

                    return DataRow(
                      color: MaterialStateProperty.resolveWith<Color?>((_) {
                        if (isExpiringThisYear) return Colors.red[200];
                        return null;
                      }),
                      cells: [
                        DataCell(Text(item['brand'] ?? '')),
                        DataCell(Text(item['quantity'].toString())),
                        DataCell(Text(_formatCountdown(expiryDate))),
                        DataCell(Text(item['category'] ?? '')),

                        DataCell(Text(item['type'] ?? '')),
                        DataCell(Text(item['function'] ?? '')),

                        DataCell(Text(item['remarks'] ?? '')),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.visibility),
                                onPressed: () => _viewItem(item),
                              ),
                              IconButton(
                                icon: Icon(Icons.edit),
                                onPressed:
                                    () => _editItem(item, _items.indexOf(item)),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete),
                                onPressed:
                                    () =>
                                        _deleteItem(item, _items.indexOf(item)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

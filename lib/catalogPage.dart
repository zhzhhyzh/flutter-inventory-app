import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CatalogPage extends StatefulWidget {
  @override
  _CatalogPageState createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  List<Map<String, dynamic>> _products = [];
  bool isLoading = false;
  bool hasMore = true;
  DocumentSnapshot? lastDocument;
  final int batchSize = 20;
  final ScrollController _scrollController = ScrollController();
  bool sortByExpiry = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!isLoading && hasMore) {
        _loadItems();
      }
    }
  }

  Future<void> _loadItems({bool reset = false}) async {
    if (isLoading || !hasMore) return;

    setState(() {
      isLoading = true;
      if (reset) {
        _products.clear();
        lastDocument = null;
        hasMore = true;
      }
    });

    try {
      Query query = FirebaseFirestore.instance
          .collection('inventory')
          .limit(batchSize);

      if (sortByExpiry) {
        query = query.orderBy('expiryDate');
      } else {
        query = query.orderBy('brand');
      }

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        lastDocument = snapshot.docs.last;

        final items = snapshot.docs.map((doc) {
          final item = doc.data() as Map<String, dynamic>;
          item['imageUrl'] = item['imageUrl']?.toString() ?? '';

          if (item.containsKey('expiryDate') && item['expiryDate'] is Timestamp) {
            final date = (item['expiryDate'] as Timestamp).toDate();
            item['expiryDate'] = date.toIso8601String();
          } else {
            item['expiryDate'] = '';
          }

          return item;
        }).where((item) {
          if (sortByExpiry) {
            final expiry = DateTime.tryParse(item['expiryDate'] ?? '');
            return expiry != null && expiry.isAfter(DateTime.now());
          }
          return true;
        }).toList();

        setState(() => _products.addAll(items));
      }

      if (snapshot.docs.length < batchSize) {
        hasMore = false;
      }
    } catch (e) {
      print('Error fetching data: $e');
    }

    setState(() => isLoading = false);
  }

  String _calculateCountdown(DateTime expiryDate) {
    final now = DateTime.now();
    final duration = expiryDate.difference(now);
    if (duration.isNegative) return 'Expired';
    return '${duration.inDays} days left';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Catalog'),
        actions: [
          Row(
            children: [
              Text('Sort by Expiry'),
              Switch(
                value: sortByExpiry,
                onChanged: (val) {
                  setState(() {
                    sortByExpiry = val;
                  });
                  _loadItems(reset: true);
                },
              ),
            ],
          ),
        ],
      ),
      body: _products.isEmpty && isLoading
          ? Center(child: CircularProgressIndicator())
          : GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8.0),
        itemCount: _products.length + (hasMore ? 1 : 0),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 250,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemBuilder: (context, index) {
          if (index == _products.length) {
            return Center(child: CircularProgressIndicator());
          }

          final product = _products[index];
          final expiryDate = DateTime.tryParse(product['expiryDate']) ?? DateTime.now();
          final imageUrl = product['imageUrl'];

          return Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Expanded(
                    child: imageUrl.isNotEmpty
                        ? Image.memory(
                      base64Decode(imageUrl),
                      fit: BoxFit.cover,
                      width: double.infinity,
                    )
                        : Image.asset('assets/placeholder.png', fit: BoxFit.cover),
                  ),
                  SizedBox(height: 8),
                  Text(
                    product['brand'] ?? 'No Brand',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(_calculateCountdown(expiryDate)),

                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

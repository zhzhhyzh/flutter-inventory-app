import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart' as rtdb;

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

  Future<void> _loadItems() async {
    if (isLoading || !hasMore) return;
    setState(() => isLoading = true);

    try {
      Query query = FirebaseFirestore.instance
          .collection('inventory')
          .orderBy('brand')
          .limit(batchSize);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        lastDocument = snapshot.docs.last;

        final List<Map<String, dynamic>> items = snapshot.docs.map((doc) {
          final item = doc.data() as Map<String, dynamic>;

          item['imageUrl'] = item['imageUrl']?.toString() ?? '';

          if (item.containsKey('expiryDate') && item['expiryDate'] is Timestamp) {
            final date = (item['expiryDate'] as Timestamp).toDate();
            item['expiryDate'] = date.toIso8601String();
          } else {
            item['expiryDate'] = '';
          }

          return item;
        }).toList();

        setState(() => _products.addAll(items));
      }

      if (snapshot.docs.length < batchSize) {
        hasMore = false;
      }
    } catch (e) {
      print('Error fetching paginated data: $e');
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
      appBar: AppBar(title: Text('Catalog')),
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

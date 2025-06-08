import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_app/image_handler.dart';

class InventoryFormPage extends StatefulWidget {
  final String mode;
  final Map<String, dynamic>? initialData;

  InventoryFormPage({required this.mode, this.initialData});

  @override
  State<InventoryFormPage> createState() => _InventoryFormPageState();
}

class _InventoryFormPageState extends State<InventoryFormPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _functionController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  DateTime? _expiryDate;
  String? _category;
  String? _type;
  File? _imageFile;

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

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    if (data != null) {
      _brandController.text = data['brand'] ?? '';
      _functionController.text = data['function'] ?? '';
      _quantityController.text = data['quantity']?.toString() ?? '';
      _remarksController.text = data['remarks'] ?? '';
      _category = data['category'];
      _type = (data['type'] as String?)?.toLowerCase();
      _category = (data['category'] as String?)?.toLowerCase();

      if (_category != null && !_types.containsKey(_category)) {
        _category = null;
      }

      if (_type != null && (_category == null || !_types[_category]!.contains(_type))) {
        _type = null;
      }

      final expiry = data['expiryDate'];
      _expiryDate = expiry is Timestamp ? expiry.toDate() : (expiry is DateTime ? expiry : null);

      final imageStr = data['image'];
      if (imageStr != null && imageStr is String && imageStr.isNotEmpty) {
        try {
          final bytes = base64Decode(imageStr);
          final tempDir = Directory.systemTemp;
          final tempImage = File('${tempDir.path}/temp_image.jpg');
          tempImage.writeAsBytesSync(bytes);
          _imageFile = tempImage;
        } catch (e) {
          print('Image decode failed: $e');
          _imageFile = null;
        }
      }
    }
    if (_type != null && _category != null) {
      print('Category: $_category, Type: $_type');
      print('Available types: ${_types[_category]}');
    }


  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  Future<void> _pickImageDialog() async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Select Image Source'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.camera_alt),
                  title: Text('Camera'),
                  onTap: () async {
                    Navigator.pop(context);
                    final image = await ImageHandler.pickImageFromCamera();
                    if (image != null) {
                      setState(() => _imageFile = image);
                    }
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library),
                  title: Text('Gallery'),
                  onTap: () async {
                    Navigator.pop(context);
                    final image = await ImageHandler.pickImageFromGallery();
                    if (image != null) {
                      setState(() => _imageFile = image);
                    }
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (_expiryDate == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Pick an expiry date')));
        return;
      }

      final item = {
        'brand': _brandController.text.trim(),
        'function': _functionController.text.trim(),
        'quantity': int.parse(_quantityController.text.trim()),
        'remarks': _remarksController.text.trim(),
        'category': _category?.toLowerCase(),
        'type': _type?.toLowerCase(),

        'expiryDate': _expiryDate,
        'image':
            _imageFile != null
                ? base64Encode(_imageFile!.readAsBytesSync())
                : '',
      };

      Navigator.pop(context, item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = widget.mode == 'view';
    final formatter = DateFormat('dd-MM-yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.mode[0].toUpperCase()}${widget.mode.substring(1)} Inventory',
        ),
        actions:
            widget.mode != 'view'
                ? [IconButton(icon: Icon(Icons.check), onPressed: _submit)]
                : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _brandController,
                decoration: InputDecoration(labelText: 'Brand'),
                readOnly: readOnly,
                validator:
                    (val) =>
                        val == null || val.trim().isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _functionController,
                decoration: InputDecoration(labelText: 'Function'),
                readOnly: readOnly,
              ),
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
                readOnly: readOnly,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Required';
                  final num = int.tryParse(val);
                  if (num == null || num < 0) return 'Enter a valid number ≥ 0';
                  return null;
                },
              ),
              TextFormField(
                controller: _remarksController,
                decoration: InputDecoration(labelText: 'Remarks'),
                readOnly: readOnly,
              ),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: InputDecoration(labelText: 'Category'),
                items:
                    _categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.toUpperCase()),
                          ),
                        )
                        .toList(),
                onChanged:
                    readOnly
                        ? null
                        : (val) => setState(() {
                          _category = val;
                          _type = null;
                        }),
                validator: (val) => val == null ? 'Required' : null,
              ),
              DropdownButtonFormField<String>(
                value: (_category != null &&
                    _type != null &&
                    _types[_category]?.contains(_type) == true)
                    ? _type
                    : null,
                decoration: InputDecoration(labelText: 'Type'),
                items: (_category != null && _types[_category] != null
                    ? _types[_category]!
                    : [])
                    .map((item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                ))
                    .toList(),
                onChanged: readOnly ? null : (val) => setState(() => _type = val),
                validator: (val) => val == null ? 'Required' : null,
              ),


              ListTile(
                title: Text(
                  _expiryDate == null
                      ? 'Pick Expiry Date'
                      : 'Expiry Date: ${formatter.format(_expiryDate!)}',
                ),
                trailing: readOnly ? null : Icon(Icons.calendar_today),
                onTap: readOnly ? null : _pickDate,
              ),
              if (_imageFile != null)
                Image.file(_imageFile!, height: 200, fit: BoxFit.cover)
              else
                Image.asset('assets/placeholder.png', height: 200),
              if (!readOnly)
                ElevatedButton.icon(
                  icon: Icon(Icons.image),
                  label: Text('Upload Image'),
                  onPressed: _pickImageDialog,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

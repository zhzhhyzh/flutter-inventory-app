import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'catalogPage.dart';
import 'firebase_options.dart';

import 'inventoryList.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Inventory App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,

      ),
      home: HomeRouter(),
    );
  }
}

class HomeRouter extends StatefulWidget {
  @override
  State<HomeRouter> createState() => _HomeRouterState();
}

class _HomeRouterState extends State<HomeRouter> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    CatalogPage(),
    InventoryListPage(inventoryItems: [],),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view),
            label: 'Catalog',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Inventory',
          ),
        ],
      ),
    );
  }
}

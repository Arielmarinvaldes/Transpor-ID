import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class TransportCardData {
  final String type;
  final String cardNumber;
  final String alias;
  final String image;
  final String? icon;

  TransportCardData({
    required this.type,
    required this.cardNumber,
    required this.alias,
    required this.image,
    this.icon,
  });

  TransportCardData copyWith({
    String? type,
    String? cardNumber,
    String? alias,
    String? image,
    String? icon,
  }) =>
      TransportCardData(
        type: type ?? this.type,
        cardNumber: cardNumber ?? this.cardNumber,
        alias: alias ?? this.alias,
        image: image ?? this.image,
        icon: icon ?? this.icon,
      );
}

class DatabaseHelper {
  static const _databaseName = "TransportCards.db";
  static const _databaseVersion = 1;
  static const table = 'transport_cards';
  static const columnId = '_id';
  static const columnIcon = 'icon';
  static const columnType = 'type';
  static const columnAlias = 'alias';
  static const columnCardNumber = 'card_number';
  static const columnImage = 'image';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async => _database ??= await _initDatabase();

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(path, version: _databaseVersion, onCreate: _onCreate);
  }

  Future _onCreate(Database db, int version) async {
    await db.execute(
      '''
      CREATE TABLE $table (
          $columnId INTEGER PRIMARY KEY,
          $columnType TEXT NOT NULL,
          $columnCardNumber TEXT NOT NULL,
          $columnAlias TEXT NOT NULL,
          $columnImage TEXT,
          $columnIcon TEXT
      )
      ''');
  }

  Future<int> insert(TransportCardData card) async {
    Database db = await instance.database;
    return await db.insert(table, {
      columnType: card.type,
      columnCardNumber: card.cardNumber,
      columnAlias: card.alias,
      columnImage: card.image,
      columnIcon: card.icon,
    });
  }

  Future<List<Map<String, dynamic>>> queryAllRows() async {
    Database db = await instance.database;
    return await db.query(table);
  }

  Future<List<TransportCardData>> getAllCards() async {
    List<Map<String, dynamic>> maps = await queryAllRows();
    return List.generate(maps.length, (index) {
      return TransportCardData(
        type: maps[index][columnType],
        cardNumber: maps[index][columnCardNumber],
        alias: maps[index][columnAlias],
        image: maps[index][columnImage] ?? 'assets/card_default.png',
        icon: maps[index][columnIcon],
      );
    });
  }

  Future<int> update(TransportCardData card) async {
    Database db = await instance.database;
    return await db.update(
      table,
      {
        columnAlias: card.alias,
        columnImage: card.image,
        columnIcon: card.icon,
      },
      where: '$columnCardNumber = ?',
      whereArgs: [card.cardNumber],
    );
  }

  Future<int> delete(String cardNumber) async {
    Database db = await instance.database;
    return await db.delete(table, where: '$columnCardNumber = ?', whereArgs: [cardNumber]);
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: TransportCardListScreen(),
      ),
    );
  }
}

class TransportCardListScreen extends StatefulWidget {
  TransportCardListScreen({Key? key}) : super(key: key);

  @override
  State<TransportCardListScreen> createState() => _TransportCardListScreenState();
}

class _TransportCardListScreenState extends State<TransportCardListScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<TransportCardData> transportCards = [];

  @override
  void initState() {
    super.initState();
    _refreshCards();
  }

  Future<void> _refreshCards() async {
    final cards = await dbHelper.getAllCards();
    setState(() {
      transportCards = cards;
    });
  }

  void _addTransportCard(TransportCardData card) {
    setState(() {
      transportCards.add(card);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Transport-ID'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: transportCards.length,
          itemBuilder: (context, index) {
            return TransportCardWidget(
              cardData: transportCards[index],
              onAliasChanged: (newAlias) => _updateCardAlias(transportCards[index], newAlias),
              onImageChanged: (newImage) => _updateCardImage(transportCards[index], newImage),
              onIconChanged: (newIcon) => _updateCardIcon(transportCards[index], newIcon),
              onDelete: () => _deleteCard(transportCards[index].cardNumber),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          _showNfcDialog(context);
        },
        tooltip: 'Increment',
        child: const Icon(Icons.nfc),
      ),
    );
  }

  Future<void> _showNfcDialog(BuildContext context) async {
    try {
      var availability = await FlutterNfcKit.nfcAvailability;
      if (!mounted) return;
      if (availability != NFCAvailability.available) {
        _showNfcNotAvailableDialog(context);
        return;
      }
       if (!mounted) return;


      var tag = await FlutterNfcKit.poll();
      _showNfcTagDetectedDialog(context, tag);
    } catch (e) {      
        return;

         _showNfcErrorDialog(context);
    }
  }

  void _showNfcNotAvailableDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('NFC no disponible'),
          content: const Text('El NFC no está disponible en este dispositivo.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cerrar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showNfcTagDetectedDialog(BuildContext context, NFCTag tag) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('NFC Tag Detected'),
          content: Text('ID: ${tag.id}'),
          actions: <Widget>[
            TextButton(
              child: const Text('Guardar'),
              onPressed: () {
                _saveCardToDatabase(tag);
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _saveCardToDatabase(NFCTag tag) async {
    if (tag.id.isEmpty) {
      if(mounted) ScaffoldMessenger.of(context as BuildContext).showSnackBar(const SnackBar(content: Text('El número de tarjeta no puede estar vacío')));
      return;
    }

    final existingCards = await dbHelper.getAllCards();
    if (existingCards.any((card) => card.cardNumber == tag.id)) {
        if(mounted) {
           ScaffoldMessenger.of(context as BuildContext).showSnackBar(const SnackBar(content: Text('Ya existe una tarjeta con este número')));
        }
      return;
    }

    TransportCardData newCard = TransportCardData(
      type: "NFC",
      cardNumber: tag.id,
      alias: "New Card NFC",
      image: "assets/card_default.png",
      icon: null,
    );
    await dbHelper.insert(newCard);
    _refreshCards();
    if (mounted) {
         ScaffoldMessenger.of(context as BuildContext).showSnackBar(const SnackBar(content: Text('Tarjeta guardada correctamente')));
    }
  }

  void _showNfcErrorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error NFC'),
          content: const Text('Error al leer la etiqueta NFC'),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _updateCardAlias(TransportCardData card, String newAlias) async {
    TransportCardData updatedCard = card.copyWith(alias: newAlias);
    await dbHelper.update(updatedCard);
    _refreshCards();
     if(mounted){
       ScaffoldMessenger.of(context as BuildContext).showSnackBar(const SnackBar(content: Text('Alias actualizado correctamente')));
     }
  }

  void _updateCardImage(TransportCardData card, String newImage) async {
    TransportCardData updatedCard = card.copyWith(image: newImage);
    await dbHelper.update(updatedCard);
    _refreshCards();
  }

  void _updateCardIcon(TransportCardData card, String newIcon) async {
    TransportCardData updatedCard = card.copyWith(icon: newIcon);
    await dbHelper.update(updatedCard);
    _refreshCards();
  }

  void _deleteCard(String cardNumber) async {
    await dbHelper.delete(cardNumber);
    _refreshCards();
  }
}

class TransportCardWidget extends StatelessWidget {
  final TransportCardData cardData;
  final Function(String) onAliasChanged;
  final VoidCallback onDelete;
  final Function(String) onImageChanged;
  final Function(String) onIconChanged;

  const TransportCardWidget({super.key, required this.cardData, required this.onAliasChanged, required this.onDelete, required this.onImageChanged, required this.onIconChanged});

  IconData getIcon(String? iconName) {
    if (iconName == null || iconName.isEmpty) return Icons.credit_card;
    switch (iconName) {
      case 'Icons.train':
        return Icons.train;
      case 'Icons.bus_alert':
        return Icons.bus_alert;
      case 'Icons.subway':
        return Icons.subway;
      case 'Icons.tram':
        return Icons.tram;
      default:
        return Icons.credit_card;
    }
  }

  void _showEditAliasDialog(BuildContext context) {
    TextEditingController aliasController = TextEditingController(text: cardData.alias);
    String? selectedIcon = cardData.icon;
    XFile? _selectedImage;
    final imagePicker = ImagePicker();

    void _pickImage() async {
      _selectedImage = await imagePicker.pickImage(source: ImageSource.gallery);
    }

    final List<String> iconOptions = [
      'Icons.train',
      'Icons.bus_alert',
      'Icons.subway',
      'Icons.tram',
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Alias'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: aliasController,
                decoration: InputDecoration(hintText: 'Enter new alias'),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedIcon,
                decoration: InputDecoration(labelText: 'Select Icon'),
                items: iconOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Icon(getIcon(value)),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  selectedIcon = newValue;
                },
              ),
            ],
          ),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.image),
              onPressed: () {
                _pickImage();
              },
            ),
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Save'),
              onPressed: () {
                if (_selectedImage != null) {
                  onImageChanged(_selectedImage!.path);
                }
                onIconChanged(selectedIcon ?? "");
                onAliasChanged(aliasController.text);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Card'),
          content: Text('Are you sure you want to delete this card?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () {
                onDelete();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tarjeta eliminada correctamente')));
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _showEditAliasDialog(context);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Image.asset(
                      cardData.image,
                      height: 50,
                      width: 50,
                      errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                        return Image.asset('assets/card_default.png', height: 50, width: 50);
                      },
                    ),
                    Icon(getIcon(cardData.icon)),
                    SizedBox(width: 16),
                    Text(
                      cardData.alias,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () {
                    _showDeleteConfirmationDialog(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

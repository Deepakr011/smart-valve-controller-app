import 'package:mongo_dart/mongo_dart.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class MongoDBService {
  static Db? db; // Nullable Db type since it will be assigned asynchronously
  static DbCollection? userCollection;
  static DbCollection? serviceProviderCollection;

  static Future<void> connect() async {
    db = await Db.create(
        'mongodb+srv://deepak:Deepakr123@cluster0.vh0c9g2.mongodb.net/?retryWrites=true&w=majority');
    await db!.open();
    userCollection = db!.collection('users'); // User collection
    serviceProviderCollection =
        db!.collection('service_providers'); // Service provider collection
  }

  static String generateUniqueId(String email) {
    return sha256.convert(utf8.encode(email)).toString();
  }

  static Future<bool> registerUser(String email, String password) async {
    String hashedPassword = sha256.convert(utf8.encode(password)).toString();
    String uniqueId = generateUniqueId(email);

    var user = await userCollection?.findOne({'email': email});

    if (user != null) {
      return false; // User already exists
    }

    await userCollection?.insertOne({
      'email': email,
      'password': hashedPassword,
      'unique_id': uniqueId,
    });

    return true;
  }

  static Future<Map<String, dynamic>?> loginUser(
      String email, String password) async {
    String hashedPassword = sha256.convert(utf8.encode(password)).toString();
    var user = await userCollection?.findOne({
      'email': email,
      'password': hashedPassword,
    });

    return user;
  }

  static Future<Map<String, dynamic>?> loginServiceProvider(
      String email, String password) async {
    String hashedPassword = sha256.convert(utf8.encode(password)).toString();
    var serviceProvider = await serviceProviderCollection?.findOne({
      'email': email,
      'password': hashedPassword,
    });

    return serviceProvider;
  }
}


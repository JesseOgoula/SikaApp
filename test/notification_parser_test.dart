import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/features/notification_sync/data/parsers/notification_parser.dart';
import 'package:sika_app/features/notification_sync/data/services/pending_transaction_queue.dart';
import 'package:sika_app/features/notification_sync/domain/models/parsed_transaction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, String> mockSecureStorage = {};

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        final args = methodCall.arguments as Map?;
        switch (methodCall.method) {
          case 'read':
            final key = args?['key'] as String?;
            return mockSecureStorage[key];
          case 'write':
            final key = args?['key'] as String?;
            final value = args?['value'] as String?;
            if (key != null && value != null) {
              mockSecureStorage[key] = value;
            }
            return true;
          case 'delete':
            final key = args?['key'] as String?;
            if (key != null) {
              mockSecureStorage.remove(key);
            }
            return true;
          case 'clear':
            mockSecureStorage.clear();
            return true;
          case 'readAll':
            return mockSecureStorage;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    mockSecureStorage.clear();
  });

  group('NotificationParser & Airtel Money SMS Patterns', () {
    test('should parse standard Airtel Money Payment SMS and extract TID', () {
      const sms = 'AirtelMoney Paiement de 2000 F MOBILEDAN pour ref 07139094358 a ete effectue avec succes. Cout: 100 FCFA. Solde 1416.71F. TID: MP260526.0845.C10293.';
      final parsed = NotificationParser.parseMessage(
        sender: 'AirtelMoney',
        body: sms,
        source: ParsedSource.sms,
      );

      expect(parsed, isNotNull);
      expect(parsed!.operatorKey, equals('AIRTEL_MONEY'));
      expect(parsed.amount, equals(2000));
      expect(parsed.type, equals('expense'));
      expect(parsed.externalId, equals('MP260526.0845.C10293'));
      expect(parsed.description, contains('MOBILEDAN'));
    });

    test('should parse alternative Airtel Money Payment SMS and extract Trans ID', () {
      const sms = 'Vous avez PAYE 2000 FCFA a MOBILEDAN en reference a 07139094358 code:6497 0502 1399 7701 2104 Tarif: BT Social 2 kW   Total Unites : (kWh) : 21.7   Montant: total : 2000 F CFA   Consommation: 1835 F CFA   TVA: 92 F CFA   CSE: 0 F CFA   Redevance mensuelle : 0 F CFA   CSS : 9 F CFA   COM : 64 F CFA. Trans ID: MP260526.0845.C10293 Votre solde est 1416.71 FCFA';
      final parsed = NotificationParser.parseMessage(
        sender: 'AirtelMoney',
        body: sms,
        source: ParsedSource.sms,
      );

      expect(parsed, isNotNull);
      expect(parsed!.operatorKey, equals('AIRTEL_MONEY'));
      expect(parsed.amount, equals(2000));
      expect(parsed.type, equals('expense'));
      expect(parsed.externalId, equals('MP260526.0845.C10293'));
      expect(parsed.description, contains('MOBILEDAN'));
    });

    test('should parse Airtel Money Receipt SMS and extract TID', () {
      const sms = '2000FCFA recu du A81411. Solde actuel 3416.71FCFA. TID:CI260603.1947.C49152. Transferez jusqu a 1 Million en Afrique & Europe avec GIMACPAY *150# puis 9';
      final parsed = NotificationParser.parseMessage(
        sender: 'AirtelMoney',
        body: sms,
        source: ParsedSource.sms,
      );

      expect(parsed, isNotNull);
      expect(parsed!.operatorKey, equals('AIRTEL_MONEY'));
      expect(parsed.amount, equals(2000));
      expect(parsed.type, equals('income'));
      expect(parsed.externalId, equals('CI260603.1947.C49152'));
      expect(parsed.description, contains('A81411'));
    });

    test('should parse Airtel Money Airtime Purchase SMS and extract TID', () {
      const sms = 'Achat de CREDIT DE COMMUNICATION de 300 F effectue avec succes. Solde: 215016.71 F TID:RC260604.1913.D70331';
      final parsed = NotificationParser.parseMessage(
        sender: 'AirtelMoney',
        body: sms,
        source: ParsedSource.sms,
      );

      expect(parsed, isNotNull);
      expect(parsed!.operatorKey, equals('AIRTEL_MONEY'));
      expect(parsed.amount, equals(300));
      expect(parsed.type, equals('expense'));
      expect(parsed.externalId, equals('RC260604.1913.D70331'));
    });

    test('should parse Airtel Money Withdrawal SMS and extract TID', () {
      const sms = 'RETRAIT de 200000 FCFA  reussi vers AMBPOG27. Solde 15016.71 F. TID: WR260620.1824.A12345';
      final parsed = NotificationParser.parseMessage(
        sender: 'AirtelMoney',
        body: sms,
        source: ParsedSource.sms,
      );

      expect(parsed, isNotNull);
      expect(parsed!.operatorKey, equals('AIRTEL_MONEY'));
      expect(parsed.amount, equals(200000));
      expect(parsed.type, equals('expense'));
      expect(parsed.externalId, equals('WR260620.1824.A12345'));
    });
   group('PendingTransactionQueue Database Deduplication', () {
    late AppDatabase database;
    late PendingTransactionQueue queue;

    setUp(() {
      database = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      queue = PendingTransactionQueue();
      queue.database = database;
    });

    tearDown(() async {
      await database.close();
      await queue.clear();
    });

    test('should push transaction when it does not exist in the database', () async {
      final tx = ParsedTransaction(
        id: 'test-tx-1',
        source: ParsedSource.sms,
        operatorKey: 'AIRTEL_MONEY',
        operatorLabel: 'Airtel Money',
        operatorColor: const Color(0xFF000000),
        accountType: 'mobile_money',
        patternLabel: 'Paiement',
        type: 'expense',
        amount: 2000,
        description: 'MOBILEDAN',
        suggestedCategory: 'cat-autres',
        date: '2026-06-23',
        externalId: 'TID12345',
        rawMessage: 'test',
        parsedAt: DateTime.now().toIso8601String(),
        receivedAt: DateTime.now().toIso8601String(),
      );

      final result = await queue.push(tx);
      expect(result, isNotNull);
      expect(result!.id, equals(tx.id));

      final pending = await queue.getAll();
      expect(pending, hasLength(1));
    });

    test('should drop transaction (return null) when a transaction with the same TID exists in the database', () async {
      // 1. Insert a transaction with externalId = 'TID12345' into the database
      final companion = TransactionsTableCompanion(
        id: const Value('db-tx-1'),
        amount: const Value(2000.0),
        type: const Value('expense'),
        merchantName: const Value('MOBILEDAN'),
        categoryId: const Value('cat-autres'),
        date: Value(DateTime.now()),
        externalId: const Value('TID12345'),
        syncStatus: const Value(1),
      );
      await database.into(database.transactionsTable).insert(companion);

      // Verify it exists
      final exists = await database.transactionExists('TID12345');
      expect(exists, isTrue);

      // 2. Try to push a parsed transaction with externalId = 'TID12345'
      final tx = ParsedTransaction(
        id: 'test-tx-2',
        source: ParsedSource.sms,
        operatorKey: 'AIRTEL_MONEY',
        operatorLabel: 'Airtel Money',
        operatorColor: const Color(0xFF000000),
        accountType: 'mobile_money',
        patternLabel: 'Paiement',
        type: 'expense',
        amount: 2000,
        description: 'MOBILEDAN',
        suggestedCategory: 'cat-autres',
        date: '2026-06-23',
        externalId: 'TID12345',
        rawMessage: 'test',
        parsedAt: DateTime.now().toIso8601String(),
        receivedAt: DateTime.now().toIso8601String(),
      );

      final result = await queue.push(tx);
      expect(result, isNull); // Transaction was dropped

      final pending = await queue.getAll();
      expect(pending, isEmpty); // Not added to queue
    });
  });
 });
}

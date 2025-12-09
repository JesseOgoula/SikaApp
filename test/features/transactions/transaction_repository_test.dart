import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/features/sms_parser/sms_parser.dart';
import 'package:sika_app/features/transactions/data/repositories/transaction_repository_impl.dart';

void main() {
  late AppDatabase database;
  late TransactionRepositoryImpl repository;

  setUp(() {
    // Utilise une base de données en mémoire pour les tests
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = TransactionRepositoryImpl(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('TransactionRepositoryImpl', () {
    test('should add parsed transaction successfully', () async {
      // Arrange
      final parsed = ParsedTransaction(
        amount: 2500.0,
        merchantName: 'PHARMACIE DU CENTRE',
        transactionId: 'PP123456',
        date: DateTime(2024, 1, 15, 10, 30),
        type: TransactionType.expense,
        operator: MobileOperator.airtelMoney,
        rawSmsContent: 'Paiement effectué de 2500 FCFA...',
        smsSender: 'AirtelMoney',
      );

      // Act
      final result = await repository.addParsedTransaction(parsed);

      // Assert
      expect(result, isTrue);

      final transactions = await repository.watchAllTransactions().first;
      expect(transactions.length, equals(1));
      expect(transactions.first.amount, equals(2500.0));
      expect(transactions.first.merchantName, equals('PHARMACIE DU CENTRE'));
      expect(transactions.first.externalId, equals('PP123456'));
      expect(transactions.first.type, equals('expense'));
      expect(transactions.first.smsSender, equals('AIRTEL_MONEY'));
      expect(transactions.first.syncStatus, equals(0)); // Non synchronisé
      expect(transactions.first.isAiCategorized, isFalse);
    });

    test('should prevent duplicate transactions via external_id', () async {
      // Arrange
      final parsed1 = ParsedTransaction(
        amount: 5000.0,
        merchantName: 'SUPERMARCHE',
        transactionId: 'PP789012',
        date: DateTime(2024, 1, 15),
        type: TransactionType.expense,
        operator: MobileOperator.airtelMoney,
        rawSmsContent: 'SMS 1',
        smsSender: 'AirtelMoney',
      );

      final parsed2 = ParsedTransaction(
        amount: 5000.0,
        merchantName: 'SUPERMARCHE',
        transactionId: 'PP789012', // Même external_id
        date: DateTime(2024, 1, 15),
        type: TransactionType.expense,
        operator: MobileOperator.airtelMoney,
        rawSmsContent: 'SMS 2 (doublon)',
        smsSender: 'AirtelMoney',
      );

      // Act
      final result1 = await repository.addParsedTransaction(parsed1);
      final result2 = await repository.addParsedTransaction(parsed2);

      // Assert
      expect(result1, isTrue); // Premier ajout réussit
      expect(result2, isFalse); // Doublon rejeté

      final transactions = await repository.watchAllTransactions().first;
      expect(transactions.length, equals(1)); // Toujours 1 seule transaction
    });

    test('should check existence by external_id', () async {
      // Arrange
      final parsed = ParsedTransaction(
        amount: 1000.0,
        merchantName: 'TEST',
        transactionId: 'EXT123',
        date: DateTime.now(),
        type: TransactionType.expense,
        operator: MobileOperator.moovMoney,
        rawSmsContent: 'Test SMS',
        smsSender: 'Moov',
      );
      await repository.addParsedTransaction(parsed);

      // Act & Assert
      expect(await repository.existsByExternalId('EXT123'), isTrue);
      expect(await repository.existsByExternalId('UNKNOWN'), isFalse);
    });

    test('should update category correctly', () async {
      // Arrange
      final parsed = ParsedTransaction(
        amount: 3000.0,
        merchantName: 'RESTAURANT',
        transactionId: 'PP555',
        date: DateTime.now(),
        type: TransactionType.expense,
        operator: MobileOperator.airtelMoney,
        rawSmsContent: 'Test',
        smsSender: 'AM',
      );
      await repository.addParsedTransaction(parsed);

      final transactions = await repository.watchAllTransactions().first;
      final txId = transactions.first.id;

      // Act
      await repository.updateCategory(
        txId,
        'cat-alimentation',
        isAiCategorized: true,
      );

      // Assert
      final updated = await repository.getTransactionById(txId);
      expect(updated?.categoryId, equals('cat-alimentation'));
      expect(updated?.isAiCategorized, isTrue);
      expect(updated?.syncStatus, equals(0)); // Marqué pour re-sync
    });

    test('should delete transaction correctly', () async {
      // Arrange
      final parsed = ParsedTransaction(
        amount: 500.0,
        merchantName: 'TO DELETE',
        transactionId: 'DEL001',
        date: DateTime.now(),
        type: TransactionType.expense,
        operator: MobileOperator.uba,
        rawSmsContent: 'Delete me',
        smsSender: 'UBA',
      );
      await repository.addParsedTransaction(parsed);

      var transactions = await repository.watchAllTransactions().first;
      expect(transactions.length, equals(1));
      final txId = transactions.first.id;

      // Act
      await repository.deleteTransaction(txId);

      // Assert
      transactions = await repository.watchAllTransactions().first;
      expect(transactions.length, equals(0));
    });

    test('should mark transaction as synced', () async {
      // Arrange
      final parsed = ParsedTransaction(
        amount: 1500.0,
        merchantName: 'SYNC TEST',
        transactionId: 'SYNC001',
        date: DateTime.now(),
        type: TransactionType.income,
        operator: MobileOperator.airtelMoney,
        rawSmsContent: 'Sync test',
        smsSender: 'AM',
      );
      await repository.addParsedTransaction(parsed);

      final transactions = await repository.watchAllTransactions().first;
      final txId = transactions.first.id;
      expect(transactions.first.syncStatus, equals(0));

      // Act
      await repository.markAsSynced(txId);

      // Assert
      final updated = await repository.getTransactionById(txId);
      expect(updated?.syncStatus, equals(1));
    });

    test('should get pending sync transactions', () async {
      // Arrange - Ajoute 3 transactions
      for (var i = 0; i < 3; i++) {
        await repository.addParsedTransaction(
          ParsedTransaction(
            amount: 1000.0 * (i + 1),
            merchantName: 'TX$i',
            transactionId: 'PENDING$i',
            date: DateTime.now(),
            type: TransactionType.expense,
            operator: MobileOperator.airtelMoney,
            rawSmsContent: 'Test $i',
            smsSender: 'AM',
          ),
        );
      }

      // Marque 1 comme synchronisé
      final all = await repository.watchAllTransactions().first;
      await repository.markAsSynced(all.first.id);

      // Act
      final pending = await repository.getPendingSyncTransactions();

      // Assert
      expect(pending.length, equals(2));
    });

    test('should watch transactions by date range', () async {
      // Arrange
      final dates = [
        DateTime(2024, 1, 5),
        DateTime(2024, 1, 15),
        DateTime(2024, 1, 25),
        DateTime(2024, 2, 5),
      ];

      for (var i = 0; i < dates.length; i++) {
        await repository.addParsedTransaction(
          ParsedTransaction(
            amount: 1000.0,
            merchantName: 'TX$i',
            transactionId: 'DATE$i',
            date: dates[i],
            type: TransactionType.expense,
            operator: MobileOperator.airtelMoney,
            rawSmsContent: 'Test',
            smsSender: 'AM',
          ),
        );
      }

      // Act
      final januaryTx = await repository
          .watchTransactionsByDateRange(
            DateTime(2024, 1, 1),
            DateTime(2024, 1, 31),
          )
          .first;

      // Assert
      expect(januaryTx.length, equals(3)); // 5, 15, 25 janvier
    });

    test('should store raw SMS content for AI training', () async {
      // Arrange
      const rawSms =
          'Paiement effectué de 2500 FCFA à PHARMACIE DU CENTRE. ID Trans: PP123456. Solde: 15000 FCFA';

      final parsed = ParsedTransaction(
        amount: 2500.0,
        merchantName: 'PHARMACIE DU CENTRE',
        transactionId: 'PP123456',
        date: DateTime.now(),
        type: TransactionType.expense,
        operator: MobileOperator.airtelMoney,
        rawSmsContent: rawSms,
        smsSender: 'AirtelMoney',
      );

      // Act
      await repository.addParsedTransaction(parsed);

      // Assert
      final transactions = await repository.watchAllTransactions().first;
      expect(transactions.first.smsRawContent, equals(rawSms));
    });
  });
}

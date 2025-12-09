import 'package:flutter_test/flutter_test.dart';
import 'package:sika_app/features/sms_parser/sms_parser.dart';

void main() {
  late SmsParserService parser;

  setUp(() {
    parser = SmsParserService();
  });

  group('SmsParserService - VRAIS SMS AIRTEL GABON', () {
    test('should parse PAIEMENT EBILLING format', () {
      // VRAI SMS du terrain
      const sender = 'AirtelMoney';
      const body =
          'Paiement de 7143 F EBILLING pour ref 5573537922 DigitechPrepai a ete effectue avec succes. Cout: 71.43 FCFA. Solde 380.58F. TID: MP251208123456';

      final result = parser.parseSms(sender, body);

      expect(result, isNotNull);
      expect(result!.amount, equals(7143.0));
      expect(result.merchantName, contains('EBILLING'));
      expect(result.transactionId, equals('MP251208123456'));
      expect(result.type, equals(TransactionType.expense));
      expect(result.operator, equals(MobileOperator.airtelMoney));
    });

    test('should parse RECEPTION format court (Recu XXXFCFA du)', () {
      // VRAI SMS du terrain
      const sender = 'AirtelMoney';
      const body =
          'Recu 3000FCFA du A67355. Solde actuel 3380.58FCFA. TID:CI251208789012';

      final result = parser.parseSms(sender, body);

      expect(result, isNotNull);
      expect(result!.amount, equals(3000.0));
      expect(result.merchantName, equals('A67355'));
      expect(result.transactionId, equals('CI251208789012'));
      expect(result.type, equals(TransactionType.income));
      expect(result.operator, equals(MobileOperator.airtelMoney));
    });

    test('should parse RECEPTION avec espaces dans montant', () {
      const sender = 'AirtelMoney';
      const body =
          'Recu 10 000 FCFA du JEAN DUPONT. Solde actuel 15000FCFA. TID:CI251208111';

      final result = parser.parseSms(sender, body);

      expect(result, isNotNull);
      expect(result!.amount, equals(10000.0));
      expect(result.merchantName, equals('JEAN DUPONT'));
      expect(result.type, equals(TransactionType.income));
    });

    test('should parse PAIEMENT MARCHAND classique', () {
      const sender = 'AirtelMoney';
      const body =
          'Paiement de 2500 F a PHARMACIE DU CENTRE effectue avec succes. TID: MP251208222';

      final result = parser.parseSms(sender, body);

      expect(result, isNotNull);
      expect(result!.amount, equals(2500.0));
      expect(result.merchantName, equals('PHARMACIE DU CENTRE'));
      expect(result.type, equals(TransactionType.expense));
    });

    test('should parse TRANSFERT / ENVOI', () {
      const sender = 'AirtelMoney';
      const body =
          'Transfert de 5000F vers 077123456 effectue avec succes. Solde: 10000F. TID: MP251208333';

      final result = parser.parseSms(sender, body);

      expect(result, isNotNull);
      expect(result!.amount, equals(5000.0));
      expect(result.merchantName, equals('077123456'));
      expect(result.type, equals(TransactionType.transfer));
    });

    test('should parse RETRAIT', () {
      const sender = 'AirtelMoney';
      const body =
          'Retrait de 15000F effectue avec succes. Solde: 5000F. TID: RT251208444';

      final result = parser.parseSms(sender, body);

      expect(result, isNotNull);
      expect(result!.amount, equals(15000.0));
      expect(result.merchantName, equals('Retrait Airtel Money'));
      expect(result.type, equals(TransactionType.expense));
    });

    test('should parse DEPOT', () {
      const sender = 'AirtelMoney';
      const body =
          'Depot de 25000F effectue. Nouveau solde: 30000F. TID: DP251208555';

      final result = parser.parseSms(sender, body);

      expect(result, isNotNull);
      expect(result!.amount, equals(25000.0));
      expect(result.merchantName, equals('Dépôt Airtel Money'));
      expect(result.type, equals(TransactionType.income));
    });
  });

  group('SmsParserService - VRAIS SMS MOOV GABON', () {
    test('should parse TRANSFERT MOOV avec nom entre parenthèses', () {
      const sender = 'MoovMoney';
      const body =
          'Transfert reussi de 10 000 F a 06010203 (MAMAN). Ref:TRF123456';

      final result = parser.parseSms(sender, body);

      expect(result, isNotNull);
      expect(result!.amount, equals(10000.0));
      expect(result.merchantName, equals('MAMAN'));
      expect(result.transactionId, equals('TRF123456'));
      expect(result.type, equals(TransactionType.transfer));
      expect(result.operator, equals(MobileOperator.moovMoney));
    });

    test('should parse TRANSFERT MOOV sans nom (numéro seul)', () {
      const sender = 'Moov';
      const body = 'Transfert de 5000 F a 07123456. Ref:TRF789';

      final result = parser.parseSms(sender, body);

      expect(result, isNotNull);
      expect(result!.amount, equals(5000.0));
      expect(result.merchantName, equals('07123456'));
      expect(result.type, equals(TransactionType.transfer));
    });

    test('should parse PAIEMENT MOOV', () {
      const sender = 'MoovMoney';
      const body =
          'Paiement de 3500 F a SUPERMARCHE MBOLO effectue. Ref:PAY789012';

      final result = parser.parseSms(sender, body);

      expect(result, isNotNull);
      expect(result!.amount, equals(3500.0));
      expect(result.merchantName, equals('SUPERMARCHE MBOLO'));
      expect(result.type, equals(TransactionType.expense));
    });

    test('should parse RECEPTION MOOV', () {
      const sender = 'MoovMoney';
      const body = 'Vous avez recu 8000 F de 06987654. Ref:RCV123456';

      final result = parser.parseSms(sender, body);

      expect(result, isNotNull);
      expect(result!.amount, equals(8000.0));
      expect(result.merchantName, equals('06987654'));
      expect(result.type, equals(TransactionType.income));
    });
  });

  group('SmsParserService - VRAIS SMS UBA GABON (UBAGAB)', () {
    test('should detect UBAGAB as UBA operator', () {
      const sender = 'UBAGAB';
      const body = 'Carte 1234... Debit de 50000 FCFA effectue. Ref: UBA123456';

      final result = parser.parseSms(sender, body);

      expect(result, isNotNull);
      expect(result!.operator, equals(MobileOperator.uba));
    });

    test('should parse UBA DEBIT', () {
      const sender = 'UBAGAB';
      const body = 'Carte 1234... Debit de 50000 FCFA effectue. Ref: UBA123456';

      final result = parser.parseSms(sender, body);

      expect(result, isNotNull);
      expect(result!.amount, equals(50000.0));
      expect(result.type, equals(TransactionType.expense));
      expect(result.operator, equals(MobileOperator.uba));
    });

    test('should parse UBA CREDIT', () {
      const sender = 'UBAGAB';
      const body = 'Credit de 150000 FCFA sur votre compte. Ref: UBA789012';

      final result = parser.parseSms(sender, body);

      expect(result, isNotNull);
      expect(result!.amount, equals(150000.0));
      expect(result.type, equals(TransactionType.income));
    });

    test('should parse UBA with keywords detection', () {
      const sender = 'UBAGAB';
      const body = 'Achat par carte de 25000 FCFA chez CARREFOUR. Ref: UBA555';

      final result = parser.parseSms(sender, body);

      expect(result, isNotNull);
      expect(result!.amount, equals(25000.0));
      expect(result.type, equals(TransactionType.expense));
    });
  });

  group('SmsParserService - Edge Cases & Validation', () {
    test('should return null for non-financial SMS', () {
      const sender = 'Promo';
      const body = 'Profitez de notre offre speciale! Appelez le 123';

      final result = parser.parseSms(sender, body);

      expect(result, isNull);
    });

    test('should return null for malformed SMS', () {
      const sender = 'AirtelMoney';
      const body = 'Votre solde est de 5000 FCFA';

      final result = parser.parseSms(sender, body);

      expect(result, isNull);
    });

    test('should detect financial SMS correctly', () {
      expect(parser.isFinancialSms('AirtelMoney', 'Any text'), isTrue);
      expect(parser.isFinancialSms('UBAGAB', 'Any text'), isTrue);
      expect(parser.isFinancialSms('Unknown', 'Paiement de 1000 FCFA'), isTrue);
      expect(parser.isFinancialSms('Promo', 'Win a prize!'), isFalse);
    });

    test('should handle amount with no space before F', () {
      const sender = 'AirtelMoney';
      const body = 'Recu 5000F du PAPA. Solde actuel 10000F. TID:CI999';

      final result = parser.parseSms(sender, body);

      expect(result, isNotNull);
      expect(result!.amount, equals(5000.0));
    });

    test('should preserve raw SMS content', () {
      const sender = 'AirtelMoney';
      const body =
          'Paiement de 1000 F EBILLING pour test a ete effectue. TID: MP000';

      final result = parser.parseSms(sender, body);

      expect(result, isNotNull);
      expect(result!.rawSmsContent, equals(body));
      expect(result.smsSender, equals(sender));
    });

    test('should extract TID correctly', () {
      const sender = 'AirtelMoney';
      const body =
          'Paiement de 500 F TEST a ete effectue. Solde 1000F. TID: MYTEST123ABC';

      final result = parser.parseSms(sender, body);

      expect(result, isNotNull);
      expect(result!.transactionId, equals('MYTEST123ABC'));
    });
  });
}

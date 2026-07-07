void main() {
  final s1 = 'Achat de CREDIT DE COMMUNICATION de 200 F effectue avec succes. Solde: 69042.71 F TID:RC260706.1948.D77290';
  final r1 = RegExp(r'achat\s+(?:de\s+)?cr[eé]dit\s+(?:de\s+communication\s+)?(?:de\s+)?(\d[\d\s]*)\s*(?:FCFA|XAF|F)', caseSensitive: false);
  final m1 = r1.firstMatch(s1);
  print('M1 amount: ${m1?.group(1)}');

  final s2 = 'Paiement de 1000 F  BUNDLE pour ref AB89|Data|ESB|DAILY|SELF|077617569 a ete effectue avec succes. Cout: 0 FCFA. Solde 120742.71F. TID: MP260706.1337.D74838.';
  final r2 = RegExp(r'paiement\s+de\s+(\d[\d\s]*)\s*(?:FCFA|XAF|F)\s+BUNDLE\s+pour\s+ref\s+(.+?)(?:\s+(?:a\s+ete|effectue)|le\s+|\s*\.\s*|Solde|$)', caseSensitive: false);
  final m2 = r2.firstMatch(s2);
  print('M2 amount: ${m2?.group(1)} ref: ${m2?.group(2)}');
}

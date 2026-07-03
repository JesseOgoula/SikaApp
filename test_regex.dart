void main() {
  var str = 'Paiement de 500 F  BUNDLE pour ref MM05|Voice|ESB|Daily|SELF|077617569 a ete effectue avec succes. Cout: 0 FCFA. Solde 127392.71F. TID: MP260703.1157.D50899.';
  
  var reg = RegExp(
    r'paiement\s+de\s+(\d[\d\s]*)\s*(?:FCFA|XAF|F)\s+(.+?)\s+pour\s+ref\s+(.+?)(?:\s+(?:a\s+ete|effectue)|le\s+|\s*\.\s*|Solde|$)',
    caseSensitive: false,
  );
  
  var match = reg.firstMatch(str);
  if (match != null) {
    print('MATCHED!');
    print('Amount: ${match.group(1)}');
    print('Merchant: ${match.group(2)}');
    print('Ref: ${match.group(3)}');
  } else {
    print('NO MATCH');
  }
}

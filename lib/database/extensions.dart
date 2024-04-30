extension SafeString on String {
  String get safeTk => endsWith('"') && startsWith("'") ? this : '"$this"';
  String get safe => endsWith("'") && startsWith("'") ? this : "'$this'";
}

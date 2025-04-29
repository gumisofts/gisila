enum PostgresTypeMapping {
  boolean('bool'),
  smallInt('int'),
  int('int'),
  bigInt('int'),
  serial('int'),
  bigSerial('int'),
  decimal('double'),
  doublePrecision('double'),
  real('double'),
  char('String'),
  varchar('String'),
  text('String'),
  date('DateTime'),
  datetz('DateTime'),
  timestamp('DateTime'),
  timestamptz('DateTime'),
  time('Time'),
  timetz('Time'),

  interval('Duration'),
  uuid('String'),
  inet('String'),
  cidr('String'),
  macaddr('String'),
  json('Map<String,dynamic>'),
  jsonb('Map<String,dynamic>'),
  array('List<dynamic>'),
  bytea('Uint8List'),
  range('Range'),
  enumm('Enum'),

  point('Point'),
  line('Line'),
  box('Box'),
  circle('Circle'),
  lseg('Lseg');

  final String dartType;
  const PostgresTypeMapping(this.dartType);
}

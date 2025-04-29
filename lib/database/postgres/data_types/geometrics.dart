// File: /home/murad/gisila/lib/database/postgres/data_types/geometrics.dart

class Point {
  final double x;
  final double y;

  Point(this.x, this.y);

  @override
  String toString() => '($x, $y)';

  static Point fromString(String value) {
    final match = RegExp(r'\(([^,]+),([^)]+)\)').firstMatch(value);
    if (match == null) {
      throw FormatException('Invalid Point format');
    }
    return Point(double.parse(match.group(1)!), double.parse(match.group(2)!));
  }
}

class Line {
  final List<Point> points;

  Line(this.points);

  @override
  String toString() => '{${points.map((p) => p.toString()).join(', ')}}';

  static Line fromString(String value) {
    final match = RegExp(r'\{(.+)\}').firstMatch(value);
    if (match == null) {
      throw FormatException('Invalid Line format');
    }
    final points = match
        .group(1)!
        .split('),(')
        .map((p) => Point.fromString('(${p.replaceAll(RegExp(r'[{}]'), '')})'))
        .toList();
    return Line(points);
  }
}

class Box {
  final Point topLeft;
  final Point bottomRight;

  Box(this.topLeft, this.bottomRight);

  @override
  String toString() => '(${topLeft.toString()}, ${bottomRight.toString()})';

  static Box fromString(String value) {
    final match = RegExp(r'\((.+),(.+)\)').firstMatch(value);
    if (match == null) {
      throw FormatException('Invalid Box format');
    }
    return Box(
      Point.fromString(match.group(1)!),
      Point.fromString(match.group(2)!),
    );
  }
}

class Circle {
  final Point center;
  final double radius;

  Circle(this.center, this.radius);

  @override
  String toString() => '<${center.toString()}, $radius>';

  static Circle fromString(String value) {
    final match = RegExp(r'<\(([^,]+),([^)]+)\), ([^>]+)>').firstMatch(value);
    if (match == null) {
      throw FormatException('Invalid Circle format');
    }
    return Circle(
        Point(double.parse(match.group(1)!), double.parse(match.group(2)!)),
        double.parse(match.group(3)!));
  }
}

class Lseg {
  final Point start;
  final Point end;

  Lseg(this.start, this.end);

  @override
  String toString() => '[$start, $end]';

  static Lseg fromString(String value) {
    final match = RegExp(r'\[(.+),(.+)\]').firstMatch(value);
    if (match == null) {
      throw FormatException('Invalid Lseg format');
    }
    return Lseg(
      Point.fromString(match.group(1)!.trim()),
      Point.fromString(match.group(2)!.trim()),
    );
  }
}

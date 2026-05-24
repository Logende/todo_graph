import 'package:uuid/uuid.dart';

/// Generates unique ids for new nodes and edges.
///
/// Injected so production code uses real UUID v4 and tests can use a
/// deterministic sequential generator.
abstract class IdGenerator {
  String next();
}

/// Production implementation backed by UUID v4.
class UuidV4IdGenerator implements IdGenerator {
  UuidV4IdGenerator([Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  String next() => _uuid.v4();
}

/// Test helper that yields `prefix-1`, `prefix-2`, ... in order.
class SequentialIdGenerator implements IdGenerator {
  SequentialIdGenerator([this.prefix = 'id']);

  final String prefix;
  int _counter = 0;

  @override
  String next() {
    _counter += 1;
    return '$prefix-$_counter';
  }
}

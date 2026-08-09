enum TodoGranularity { day, week, month, year }

extension TodoGranularityX on TodoGranularity {
  String get storageValue => name;

  String get label => switch (this) {
    TodoGranularity.day => '今天',
    TodoGranularity.week => '本周',
    TodoGranularity.month => '本月',
    TodoGranularity.year => '今年',
  };

  static TodoGranularity fromStorage(String value) =>
      TodoGranularity.values.firstWhere(
        (granularity) => granularity.storageValue == value,
        orElse: () => TodoGranularity.day,
      );
}

class Todo {
  const Todo({
    required this.id,
    required this.title,
    required this.granularity,
    required this.createdAt,
  });

  final String id;
  final String title;
  final TodoGranularity granularity;
  final DateTime createdAt;

  Todo copyWith({String? title, TodoGranularity? granularity}) => Todo(
    id: id,
    title: title ?? this.title,
    granularity: granularity ?? this.granularity,
    createdAt: createdAt,
  );

  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
    id: json['id'] as String,
    title: json['title'] as String,
    granularity: TodoGranularityX.fromStorage(json['granularity'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'granularity': granularity.storageValue,
    'createdAt': createdAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is Todo &&
      other.id == id &&
      other.title == title &&
      other.granularity == granularity &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, title, granularity, createdAt);
}

Todo createTodo({
  required String title,
  required TodoGranularity granularity,
  DateTime? now,
  String? id,
}) {
  final trimmedTitle = title.trim();
  if (trimmedTitle.isEmpty) {
    throw const FormatException('任务内容不能为空');
  }

  final timestamp = now ?? DateTime.now();
  return Todo(
    id: id ?? '${timestamp.microsecondsSinceEpoch}-${timestamp.hashCode}',
    title: trimmedTitle,
    granularity: granularity,
    createdAt: timestamp,
  );
}

List<Todo> filterTodos(List<Todo> todos, TodoGranularity granularity) =>
    todos.where((todo) => todo.granularity == granularity).toList();

List<Todo> completeTodo(List<Todo> todos, String id) =>
    todos.where((todo) => todo.id != id).toList();

List<Todo> updateTodoGranularity(
  List<Todo> todos,
  String id,
  TodoGranularity granularity,
) => todos
    .map(
      (todo) => todo.id == id ? todo.copyWith(granularity: granularity) : todo,
    )
    .toList();

List<Todo> renameTodo(List<Todo> todos, String id, String title) {
  final trimmedTitle = title.trim();
  if (trimmedTitle.isEmpty) {
    throw const FormatException('任务内容不能为空');
  }

  return todos
      .map((todo) => todo.id == id ? todo.copyWith(title: trimmedTitle) : todo)
      .toList();
}

List<Todo> reorderTodos(
  List<Todo> todos,
  TodoGranularity granularity,
  int fromIndex,
  int toIndex,
) {
  final matching = filterTodos(todos, granularity);
  if (matching.isEmpty) return todos;

  final from = fromIndex.clamp(0, matching.length - 1);
  final to = toIndex.clamp(0, matching.length - 1);
  final moved = matching.removeAt(from);
  matching.insert(to, moved);

  var matchingIndex = 0;
  return todos
      .map(
        (todo) =>
            todo.granularity == granularity ? matching[matchingIndex++] : todo,
      )
      .toList();
}

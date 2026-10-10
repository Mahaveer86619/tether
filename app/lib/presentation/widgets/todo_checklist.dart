import 'package:flutter/material.dart';

import '../../domain/entities/entities.dart';
import '../theme/theme.dart';

class TodoChecklist extends StatelessWidget {
  const TodoChecklist({super.key, required this.todos});

  final List<TodoItem> todos;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final t in todos)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: switch (t.status) {
                    TodoStatus.completed => Icon(Icons.check_circle_rounded, size: 16, color: c.success),
                    TodoStatus.inProgress => SizedBox(
                        width: 16,
                        height: 16,
                        child: Padding(padding: const EdgeInsets.all(2), child: CircularProgressIndicator(strokeWidth: 1.8, color: c.accent)),
                      ),
                    TodoStatus.pending => Icon(Icons.radio_button_unchecked_rounded, size: 16, color: c.faint),
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: t.status == TodoStatus.completed ? c.faint : c.text,
                      decoration: t.status == TodoStatus.completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

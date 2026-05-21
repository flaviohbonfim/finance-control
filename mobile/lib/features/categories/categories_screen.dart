import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../../core/api/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_card.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _hexColor(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return AppTheme.primaryColor;
  }
}

final _catTypeFilter = StateProvider<String?>((ref) => null);

// ── Screen ────────────────────────────────────────────────────────────────────

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_catTypeFilter);
    final catsAsync = ref.watch(categoriesProvider(filter));

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 10),
            child: Row(
              children: [
                const Text('Categorias',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Nova categoria',
                  onPressed: () => _openForm(context, ref, null),
                ),
              ],
            ),
          ),
          _TypeFilter(
            selected: filter,
            onChanged: (t) => ref.read(_catTypeFilter.notifier).state = t,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: catsAsync.when(
              data: (cats) => RefreshIndicator(
                onRefresh: () => ref.refresh(categoriesProvider(filter).future),
                child: _buildList(context, ref, cats),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<Category> cats) {
    if (cats.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.category_outlined, size: 52, color: AppTheme.textMuted),
                  const SizedBox(height: 12),
                  const Text('Nenhuma categoria',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 15)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Criar categoria'),
                    onPressed: () => _openForm(context, ref, null),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      itemCount: cats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _CategoryTile(
        category: cats[i],
        onEdit: () => _openForm(context, ref, cats[i]),
        onDelete: () => _confirmDelete(context, ref, cats[i]),
      ),
    );
  }

  void _openForm(BuildContext context, WidgetRef ref, Category? cat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryFormSheet(
        category: cat,
        onSaved: () => ref.invalidate(categoriesProvider),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Category cat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appSurface,
        title: const Text('Excluir categoria'),
        content: Text('Deseja excluir "${cat.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await api.delete('/categories/${cat.id}');
                ref.invalidate(categoriesProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro ao excluir: $e')));
                }
              }
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

// ── Type filter pills ─────────────────────────────────────────────────────────

class _TypeFilter extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _TypeFilter({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const pills = [
      (label: 'Tudo', value: null),
      (label: 'Despesa', value: 'expense'),
      (label: 'Receita', value: 'income'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: pills
            .map((p) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(p.value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected == p.value
                            ? context.appPrimary
                            : context.appSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected == p.value
                              ? context.appPrimary
                              : context.appBorder,
                        ),
                      ),
                      child: Text(
                        p.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selected == p.value
                              ? Colors.white
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ── Category tile ─────────────────────────────────────────────────────────────

class _CategoryTile extends StatelessWidget {
  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryTile(
      {required this.category, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = _hexColor(category.color);
    final isIncome = category.type == 'income';

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: color.withAlpha(30), shape: BoxShape.circle),
            child: Center(
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                _Badge(
                  label: isIncome ? 'Receita' : 'Despesa',
                  color: isIncome ? AppTheme.green : AppTheme.red,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: context.appSurface,
            icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.textMuted),
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Editar')),
              PopupMenuItem(
                value: 'delete',
                child: Text('Excluir', style: TextStyle(color: AppTheme.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style:
              TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ── Category form sheet ───────────────────────────────────────────────────────

class _CategoryFormSheet extends ConsumerStatefulWidget {
  final Category? category;
  final VoidCallback onSaved;

  const _CategoryFormSheet({required this.category, required this.onSaved});

  @override
  ConsumerState<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<_CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.category?.name ?? '');
  late final _colorCtrl =
      TextEditingController(text: widget.category?.color ?? '#6366f1');
  late String _type = widget.category?.type ?? 'expense';
  bool _saving = false;

  bool get _isEdit => widget.category != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final body = {
      'name': _nameCtrl.text.trim(),
      'color': _colorCtrl.text.trim(),
      if (!_isEdit) 'type': _type,
    };

    try {
      if (_isEdit) {
        await api.put('/categories/${widget.category!.id}', data: body);
      } else {
        await api.post('/categories', data: body);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      margin: EdgeInsets.only(bottom: inset),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: context.appBorder,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(_isEdit ? 'Editar categoria' : 'Nova categoria',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nome'),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
            ),
            const SizedBox(height: 12),
            if (!_isEdit) ...[
              const Text('Tipo',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _TypeToggleBtn(
                    label: 'Despesa',
                    selected: _type == 'expense',
                    color: AppTheme.red,
                    onTap: () => setState(() => _type = 'expense'),
                  ),
                  const SizedBox(width: 10),
                  _TypeToggleBtn(
                    label: 'Receita',
                    selected: _type == 'income',
                    color: AppTheme.green,
                    onTap: () => setState(() => _type = 'income'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _colorCtrl,
              decoration: InputDecoration(
                labelText: 'Cor (hex)',
                hintText: '#6366f1',
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: StatefulBuilder(
                    builder: (_, setState) => Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _hexColor(_colorCtrl.text),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Informe a cor';
                final hex = v.trim().replaceAll('#', '');
                if (hex.length != 6) return 'Use formato #RRGGBB';
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(_isEdit ? 'Salvar alterações' : 'Criar categoria'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeToggleBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeToggleBtn(
      {required this.label,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withAlpha(30) : context.appBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : context.appBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? color : AppTheme.textSecondary)),
          ),
        ),
      ),
    );
  }
}

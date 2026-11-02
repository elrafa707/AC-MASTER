import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../data/equipos_repository.dart';
import '../../models/equipo.dart';
import 'ficha_equipo_screen.dart';

/// Búsqueda de la ficha de un equipo por su número de serie, para técnicos y administradores (RF-08).
class BuscarSerieScreen extends ConsumerStatefulWidget {
  const BuscarSerieScreen({super.key});

  @override
  ConsumerState<BuscarSerieScreen> createState() => _BuscarSerieScreenState();
}

class _BuscarSerieScreenState extends ConsumerState<BuscarSerieScreen> {
  final _serie = TextEditingController();
  FichaEquipo? _ficha;
  String? _error;
  bool _buscando = false;

  @override
  void dispose() {
    _serie.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final serie = _serie.text.trim().toUpperCase();
    if (serie.length < 4) {
      setState(() => _error = 'Escribe al menos 4 caracteres');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _buscando = true;
      _error = null;
    });
    try {
      final ficha = await ref.read(equiposRepositoryProvider).fichaPorSerie(serie);
      if (mounted) setState(() => _ficha = ficha);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _ficha = null;
          _error = e.mensaje;
        });
      }
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar equipo')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: TextField(
              key: const Key('campo-buscar-serie'),
              controller: _serie,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.search,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]'))],
              onSubmitted: (_) => _buscar(),
              decoration: InputDecoration(
                labelText: 'Número de serie',
                errorText: _error,
                prefixIcon: const Icon(Icons.qr_code_2_rounded),
                suffixIcon: _buscando
                    ? const Padding(padding: EdgeInsets.all(14), child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                    : IconButton(tooltip: 'Buscar', onPressed: _buscar, icon: const Icon(Icons.search_rounded)),
              ),
            ),
          ),
          Expanded(
            child: _ficha == null
                ? const SizedBox.shrink()
                : ContenidoFicha(key: ValueKey(_ficha!.equipo.id), ficha: _ficha!),
          ),
        ],
      ),
    );
  }
}

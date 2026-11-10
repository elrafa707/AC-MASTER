import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/admin_repository.dart';
import '../../models/admin.dart';
import '../../shared/widgets/dialogos.dart';
import '../../shared/widgets/estado_carga.dart';

final clientesProvider = FutureProvider.family<List<ClienteCuenta>, String>(
  (ref, texto) => ref.watch(adminRepositoryProvider).clientes(texto: texto),
);

/// Clientes registrados; el administrador puede desactivar una cuenta.
class ClientesScreen extends ConsumerStatefulWidget {
  const ClientesScreen({super.key});

  @override
  ConsumerState<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends ConsumerState<ClientesScreen> {
  String _texto = '';

  @override
  Widget build(BuildContext context) {
    final clientes = ref.watch(clientesProvider(_texto));
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: TextField(
              textInputAction: TextInputAction.search,
              onSubmitted: (t) => setState(() => _texto = t.trim()),
              decoration: const InputDecoration(hintText: 'Buscar por nombre o correo', prefixIcon: Icon(Icons.search_rounded)),
            ),
          ),
          Expanded(
            child: switch (clientes) {
              AsyncData(:final value) when value.isEmpty => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Vacio(icono: Icons.people_outline_rounded, titulo: 'Sin resultados', mensaje: 'Prueba con otra búsqueda.'),
                ),
              AsyncData(:final value) => ListView.separated(
                  itemCount: value.length,
                  separatorBuilder: (_, _) => const Divider(indent: 20, endIndent: 20),
                  itemBuilder: (context, i) {
                    final c = value[i];
                    return SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                      title: Text(c.nombre, style: tema.textTheme.titleMedium?.copyWith(fontSize: 14)),
                      subtitle: Text('${c.correo}\n${cantidad(c.equipos, 'equipo', 'equipos')} · ${cantidad(c.solicitudes, 'solicitud', 'solicitudes')}', style: tema.textTheme.bodySmall),
                      isThreeLine: true,
                      value: c.activo,
                      onChanged: (activo) async {
                        if (!activo) {
                          final ok = await confirmar(
                            context,
                            titulo: '¿Desactivar a ${c.nombre}?',
                            mensaje: 'No podrá iniciar sesión hasta que reactives su cuenta.',
                            textoConfirmar: 'Desactivar',
                          );
                          if (!ok || !context.mounted) return;
                        }
                        final exito = await ejecutarConAviso(
                          context,
                          () => ref.read(adminRepositoryProvider).cambiarEstadoCliente(c.id, activo: activo),
                        );
                        if (exito) ref.invalidate(clientesProvider);
                      },
                    );
                  },
                ),
              AsyncError(:final error) => ErrorConReintento(error: error, alReintentar: () => ref.invalidate(clientesProvider(_texto))),
              _ => const Cargando(),
            },
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:exploding_kittens/core/constants/app_constants.dart';

import 'package:exploding_kittens/features/lobby/domain/models/discovered_room.dart';

// Descubre salas en la red local escuchando los beacons UDP que manda
// MdnsAdvertiser.
//
// Uso:
//   final discoverer = MdnsDiscoverer();
//   discoverer.rooms.listen((rooms) => setState(() => _rooms = rooms));
//   await discoverer.start();
//   // ... mostrar la UI
//   await discoverer.stop();
//
// TODO(improvement): también consultar registros PTR de mDNS para
// AppConstants.mdnsServiceType usando el paquete `multicast_dns` una vez que
// el anuncio mDNS real esté implementado (ver MdnsAdvertiser). Combinar
// ambas fuentes con rx_dart merge o un StreamGroup simple para que
// funcione cualquiera de los dos mecanismos.
class MdnsDiscoverer {
  MdnsDiscoverer({
    Duration staleAfter = const Duration(seconds: 10),
    Duration pruneInterval = const Duration(seconds: 2),
  })  : _staleAfter = staleAfter,
        _pruneInterval = pruneInterval;

  final Duration _staleAfter;
  final Duration _pruneInterval;
  final _roomsController = StreamController<List<DiscoveredRoom>>.broadcast();
  final _rooms = <String, DiscoveredRoom>{}; // roomId → sala
  final _lastSeen = <String, DateTime>{}; // roomId → último beacon recibido
  RawDatagramSocket? _socket;
  Timer? _pruneTimer;

  // Emite la lista actual cada vez que llega un beacon nuevo o se poda una sala.
  Stream<List<DiscoveredRoom>> get rooms => _roomsController.stream;

  // Se conecta a discoveryPort y empieza a recolectar beacons. [port] es
  // sobreescribible para que los tests usen su propio puerto y no choquen
  // con otros archivos de test que usan este mismo puerto fijo de producción.
  Future<void> start({int port = AppConstants.discoveryPort}) async {
    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      port,
      reuseAddress: true,
    );

    _socket!.listen(
      (event) {
        if (event != RawSocketEvent.read) return;
        final datagram = _socket!.receive();
        if (datagram != null) _handleDatagram(datagram);
      },
      onError: (_) {},
      cancelOnError: false,
    );

    // El host deja de mandar beacons al cerrar, pero nunca avisa que se
    // fue, así que sin esto una sala cerrada quedaba listada hasta
    // reiniciar la app. Cualquier beacon con más de `_staleAfter` de
    // antigüedad (~3 beacons perdidos con el intervalo por defecto de 3s
    // del advertiser) se descarta.
    _pruneTimer = Timer.periodic(_pruneInterval, (_) => _pruneStale());
  }

  void _handleDatagram(Datagram datagram) {
    try {
      final json =
          jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
      if (json['type'] != 'room_beacon') return;

      // Confía en el hostAddress del beacon; usa datagram.address como
      // respaldo si la IP autoreportada falta o está mal formada.
      // TODO(improvement): validar hostAddress contra datagram.address para
      // detectar beacons falsificados (caso límite en redes compartidas/VPN).
      final room = DiscoveredRoom.fromJson(json);
      _rooms[room.roomId] = room;
      _lastSeen[room.roomId] = DateTime.now();

      _emit();
    } catch (_) {
      // Ignora datagramas mal formados o que no son un beacon.
    }
  }

  void _pruneStale() {
    final cutoff = DateTime.now().subtract(_staleAfter);
    final staleIds = _lastSeen.entries
        .where((e) => e.value.isBefore(cutoff))
        .map((e) => e.key)
        .toList();
    if (staleIds.isEmpty) return;

    for (final id in staleIds) {
      _rooms.remove(id);
      _lastSeen.remove(id);
    }
    _emit();
  }

  void _emit() {
    if (!_roomsController.isClosed) {
      _roomsController.add(List.unmodifiable(_rooms.values));
    }
  }

  Future<void> stop() async {
    _pruneTimer?.cancel();
    _pruneTimer = null;
    _socket?.close();
    _socket = null;
    _rooms.clear();
    _lastSeen.clear();
    await _roomsController.close();
  }
}
